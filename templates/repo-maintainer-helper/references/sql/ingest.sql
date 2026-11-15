-- Ingest the files fetch.mjs wrote for one repository: issues, PRs, labels and the title index.
-- Input: repo, run_id (or null outside a run), backlog_days (default 14).
-- On the first read of a kind, items not updated within backlog_days are recorded as already
-- seen, so the first run does not triage the whole backlog. Returns one row per kind with
-- read_count, new_items, queued and limit_reached.
-- Run from the workspace root, right after `node references/fetch.mjs <repo>`:
--   sqlite3 -bail -json <db_path> ".read references/sql/ingest.sql"
-- Input: write db-input.json with the write tool first, with "step": "ingest".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'ingest'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- The repository must be registered (add-repo.sql). Its name is checked there, so the
-- inbox path built from it stays inside inbox/.
CREATE TEMP TABLE r (repo TEXT NOT NULL, dir TEXT NOT NULL, backlog INTEGER NOT NULL CHECK (backlog BETWEEN 1 AND 365));
INSERT INTO temp.r
SELECT p.repo, 'inbox/' || replace(p.repo, '/', '__') || '/',
       coalesce(json_extract(i.j, '$.backlog_days'), 14)
FROM repos AS p, temp.input AS i WHERE p.repo = json_extract(i.j, '$.repo');
CREATE TEMP TABLE repo_guard (n INTEGER CONSTRAINT repo_not_registered CHECK (n = 1));
INSERT INTO temp.repo_guard SELECT count(*) FROM temp.r;

-- The fetch summary must name this repository and carry a real time.
CREATE TEMP TABLE f (
  repo TEXT,
  fetched_at TEXT CHECK (fetched_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'),
  issue_limit INTEGER,
  pr_limit INTEGER
);
INSERT INTO temp.f
SELECT json_extract(s, '$.repo'), json_extract(s, '$.fetched_at'),
       json_extract(s, '$.limits.issues'), json_extract(s, '$.limits.prs')
FROM (SELECT CAST(readfile((SELECT dir FROM temp.r) || 'fetch.json') AS TEXT) AS s);
CREATE TEMP TABLE fetch_guard (ok INTEGER CONSTRAINT fetch_missing_or_for_another_repo CHECK (ok = 1));
INSERT INTO temp.fetch_guard
SELECT coalesce(count(*) = 1 AND min(f.repo = r.repo) AND min(f.fetched_at IS NOT NULL)
                AND min(f.issue_limit > 0) AND min(f.pr_limit > 0), 0)
FROM temp.f AS f, temp.r AS r;

CREATE TEMP TABLE src (kind TEXT NOT NULL, doc TEXT NOT NULL CHECK (json_valid(doc) AND json_type(doc) = 'array'));
INSERT INTO temp.src SELECT 'issue', CAST(readfile(dir || 'issues.json') AS TEXT) FROM temp.r;
INSERT INTO temp.src SELECT 'pr', CAST(readfile(dir || 'prs.json') AS TEXT) FROM temp.r;

-- Every row is checked here, at the trust boundary. A bad row stops the whole step.
CREATE TEMP TABLE b (
  kind TEXT NOT NULL,
  number INTEGER NOT NULL CHECK (typeof(number) = 'integer' AND number > 0),
  -- The JSON type, checked before column affinity can turn a string like "12" into 12.
  number_type TEXT NOT NULL CHECK (number_type = 'integer'),
  title TEXT NOT NULL CHECK (length(title) <= 1000),
  author TEXT NOT NULL,
  is_bot INTEGER NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('OPEN', 'CLOSED', 'MERGED')),
  draft INTEGER NOT NULL,
  labels TEXT NOT NULL,
  body TEXT NOT NULL,
  url TEXT NOT NULL,
  created TEXT NOT NULL,
  updated TEXT NOT NULL CHECK (updated GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'),
  UNIQUE (number)
);
INSERT INTO temp.b
SELECT s.kind,
       json_extract(e.value, '$.number'),
       coalesce(json_type(e.value, '$.number'), 'missing'),
       coalesce(json_extract(e.value, '$.title'), ''),
       coalesce(json_extract(e.value, '$.author.login'), ''),
       CASE WHEN json_extract(e.value, '$.author.is_bot') THEN 1 ELSE 0 END,
       json_extract(e.value, '$.state'),
       CASE WHEN json_extract(e.value, '$.isDraft') THEN 1 ELSE 0 END,
       coalesce((SELECT json_group_array(json_extract(l.value, '$.name'))
                 FROM json_each(e.value, '$.labels') AS l), '[]'),
       substr(coalesce(json_extract(e.value, '$.body'), ''), 1, 20000),
       coalesce(json_extract(e.value, '$.url'), ''),
       coalesce(json_extract(e.value, '$.createdAt'), ''),
       json_extract(e.value, '$.updatedAt')
FROM temp.src AS s, json_each(s.doc) AS e;

CREATE TEMP TABLE before (kind TEXT NOT NULL, newest TEXT NOT NULL, cutoff TEXT NOT NULL);
INSERT INTO temp.before
SELECT 'issue', p.newest_issue, strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '-' || r.backlog || ' days')
FROM repos AS p JOIN temp.r AS r ON r.repo = p.repo;
INSERT INTO temp.before
SELECT 'pr', p.newest_pr, strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '-' || r.backlog || ' days')
FROM repos AS p JOIN temp.r AS r ON r.repo = p.repo;

CREATE TEMP TABLE stats (kind TEXT PRIMARY KEY, read_count INTEGER, new_items INTEGER, limit_reached INTEGER);
INSERT INTO temp.stats
SELECT k.kind,
       (SELECT count(*) FROM temp.b WHERE kind = k.kind),
       (SELECT count(*) FROM temp.b AS x
         WHERE x.kind = k.kind
           AND NOT EXISTS (SELECT 1 FROM items AS i, temp.r AS r WHERE i.repo = r.repo AND i.number = x.number)),
       CASE WHEN (SELECT count(*) FROM temp.b WHERE kind = k.kind)
                 >= (SELECT CASE k.kind WHEN 'issue' THEN issue_limit ELSE pr_limit END FROM temp.f)
             AND k.newest <> ''
             AND (SELECT min(updated) FROM temp.b WHERE kind = k.kind) > k.newest
            THEN 1 ELSE 0 END
FROM temp.before AS k;

BEGIN;

INSERT INTO items (repo, kind, number, title, author, author_is_bot, state, is_draft, labels, body, url,
                   created_at, updated_at, first_seen, last_seen, triaged_updated_at)
SELECT r.repo, x.kind, x.number, x.title, x.author, x.is_bot, x.state, x.draft, x.labels, x.body, x.url,
       x.created, x.updated, strftime('%Y-%m-%dT%H:%M:%SZ', 'now'), f.fetched_at,
       -- First read of this kind: older items and closed items count as already seen.
       CASE WHEN k.newest = '' AND (x.updated < k.cutoff OR x.state <> 'OPEN') THEN x.updated ELSE '' END
FROM temp.b AS x, temp.r AS r, temp.f AS f JOIN temp.before AS k ON k.kind = x.kind
WHERE true
ON CONFLICT (repo, number) DO UPDATE SET
  title = excluded.title,
  author = excluded.author,
  author_is_bot = excluded.author_is_bot,
  state = excluded.state,
  is_draft = excluded.is_draft,
  labels = excluded.labels,
  body = excluded.body,
  url = excluded.url,
  updated_at = excluded.updated_at,
  last_seen = excluded.last_seen;

UPDATE repos SET
  newest_issue = max(newest_issue, coalesce((SELECT max(updated) FROM temp.b WHERE kind = 'issue'), '')),
  newest_pr = max(newest_pr, coalesce((SELECT max(updated) FROM temp.b WHERE kind = 'pr'), ''))
WHERE repo = (SELECT repo FROM temp.r);

-- The label list is replaced as a whole.
CREATE TEMP TABLE lb (name TEXT NOT NULL CONSTRAINT lb CHECK (length(name) BETWEEN 1 AND 100));
INSERT INTO temp.lb
SELECT json_extract(e.value, '$.name')
FROM json_each(CAST(readfile((SELECT dir FROM temp.r) || 'labels.json') AS TEXT)) AS e;
DELETE FROM labels WHERE repo = (SELECT repo FROM temp.r);
INSERT OR IGNORE INTO labels (repo, name) SELECT r.repo, lb.name FROM temp.lb AS lb, temp.r AS r;

-- Title index: issue titles from the long index read, then every item just read.
CREATE TEMP TABLE ix (number INTEGER NOT NULL CONSTRAINT index_number_not_integer CHECK (typeof(number) = 'integer' AND number > 0), title TEXT NOT NULL, state TEXT NOT NULL);
INSERT INTO temp.ix
SELECT json_extract(e.value, '$.number'), coalesce(json_extract(e.value, '$.title'), ''), coalesce(json_extract(e.value, '$.state'), '')
FROM json_each(CAST(readfile((SELECT dir FROM temp.r) || 'index.json') AS TEXT)) AS e;
DELETE FROM title_index
WHERE repo = (SELECT repo FROM temp.r)
  AND (number IN (SELECT number FROM temp.ix) OR number IN (SELECT number FROM temp.b));
INSERT INTO title_index (title, repo, number, kind, state)
SELECT ix.title, r.repo, ix.number, 'issue', ix.state FROM temp.ix AS ix, temp.r AS r
WHERE ix.number NOT IN (SELECT number FROM temp.b);
INSERT INTO title_index (title, repo, number, kind, state)
SELECT x.title, r.repo, x.number, x.kind, x.state FROM temp.b AS x, temp.r AS r;

INSERT INTO reads (run_id, repo, kind, fetched_at, read_count, new_items, queued, limit_reached, ingested_at)
SELECT json_extract(i.j, '$.run_id'), r.repo, s.kind, f.fetched_at, s.read_count, s.new_items,
       (SELECT count(*) FROM items AS it
         WHERE it.repo = r.repo AND it.kind = s.kind AND it.state = 'OPEN' AND it.updated_at > it.triaged_updated_at),
       s.limit_reached, strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
FROM temp.stats AS s, temp.r AS r, temp.f AS f, temp.input AS i;

COMMIT;

SELECT repo, kind, read_count, new_items, queued, limit_reached, fetched_at
FROM reads WHERE id > (SELECT coalesce(max(id), 0) - 2 FROM reads) AND repo = (SELECT repo FROM temp.r)
ORDER BY kind;

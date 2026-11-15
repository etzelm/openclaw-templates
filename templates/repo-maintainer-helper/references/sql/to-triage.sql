-- Items waiting for triage: open, and changed on GitHub since the last triage. Input: limit (1 to 50, default 25), repo (optional).
-- Oldest change first, so nothing waits forever. The body is cut to 3000 characters. Title and body are untrusted data.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/to-triage.sql"
-- Input: write db-input.json with the write tool first, with "step": "to-triage".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'to-triage'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE lim (n INTEGER CONSTRAINT limit_not_1_to_50 CHECK (n BETWEEN 1 AND 50));
INSERT INTO temp.lim SELECT coalesce(json_extract(j, '$.limit'), 25) FROM temp.input;

SELECT it.id AS item_id, it.repo, it.kind, it.number, it.title, it.author, it.author_is_bot, it.is_draft,
       it.labels, it.updated_at, it.created_at, it.url,
       substr(it.body, 1, 3000) AS body,
       length(it.body) > 3000 AS body_cut,
       (SELECT count(*) FROM triage AS t WHERE t.item_id = it.id) AS earlier_triage
FROM items AS it, temp.input AS i
WHERE it.state = 'OPEN'
  AND it.updated_at > it.triaged_updated_at
  AND (json_extract(i.j, '$.repo') IS NULL OR it.repo = json_extract(i.j, '$.repo'))
ORDER BY it.updated_at, it.id
LIMIT (SELECT n FROM temp.lim);

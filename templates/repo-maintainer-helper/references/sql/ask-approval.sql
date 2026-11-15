-- Ask the owner for one write to GitHub. Input: item_id, action (add-labels, comment, close), labels (add-labels: 1 to 5 names from the repo's list),
-- close_reason (close on an issue: completed or not planned; leave it out for a PR).
-- This step builds the exact command. Never write a gh write command yourself: show the owner the exact_step it returns, word for word.
-- comment: write the reply to the body_file it names first (drafts/<owner>__<repo>-<number>.md), then ask. The reply text never goes on a command line.
-- Refuses unless the item is open and was fetched in the last 15 minutes, so the owner sees it as it is now.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/ask-approval.sql"
-- Input: write db-input.json with the write tool first, with "step": "ask-approval".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'ask-approval'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE it AS
SELECT i.*, 'drafts/' || replace(i.repo, '/', '__') || '-' || i.number || '.md' AS draft_path,
       CASE i.kind WHEN 'issue' THEN 'issue' ELSE 'pr' END AS cli
FROM items AS i WHERE i.id = (SELECT json_extract(j, '$.item_id') FROM temp.input);
CREATE TEMP TABLE g1 (ok INTEGER CONSTRAINT item_unknown_or_not_open CHECK (ok = 1));
INSERT INTO temp.g1 SELECT count(*) = 1 AND min(state = 'OPEN') FROM temp.it;
CREATE TEMP TABLE g2 (ok INTEGER CONSTRAINT fetch_again_first CHECK (ok = 1));
INSERT INTO temp.g2 SELECT min(last_seen >= strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '-15 minutes')) FROM temp.it;

CREATE TEMP TABLE act (a TEXT CONSTRAINT unknown_action CHECK (a IN ('add-labels', 'comment', 'close')));
INSERT INTO temp.act SELECT json_extract(j, '$.action') FROM temp.input;

-- Labels: 1 to 5, each in the repo's label list, not on the item yet, and safe inside single quotes.
CREATE TEMP TABLE lb (k INTEGER NOT NULL, name TEXT NOT NULL CONSTRAINT label_name_unsafe CHECK (
  length(name) BETWEEN 1 AND 100
  AND name NOT GLOB '*['',]*'
  AND name NOT GLOB ('*[' || char(9, 10, 13) || ']*')
));
INSERT INTO temp.lb SELECT e.key, e.value FROM temp.input AS i, json_each(i.j, '$.labels') AS e
WHERE (SELECT a FROM temp.act) = 'add-labels';
CREATE TEMP TABLE labels_guard (ok INTEGER CONSTRAINT labels_not_usable CHECK (ok = 1));
INSERT INTO temp.labels_guard
SELECT CASE WHEN (SELECT a FROM temp.act) <> 'add-labels' THEN
              coalesce(json_array_length(json_extract(j, '$.labels')), 0) = 0
            ELSE (SELECT count(*) BETWEEN 1 AND 5 FROM temp.lb)
             AND (SELECT count(DISTINCT name) = count(*) FROM temp.lb)
             AND NOT EXISTS (SELECT 1 FROM temp.lb AS l, temp.it AS t
                             WHERE NOT EXISTS (SELECT 1 FROM labels AS r WHERE r.repo = t.repo AND r.name = l.name)
                                OR EXISTS (SELECT 1 FROM json_each(t.labels) AS have WHERE have.value = l.name))
       END
FROM temp.input;

-- Close reason: required for an issue, not allowed for a PR or another action.
CREATE TEMP TABLE reason_guard (ok INTEGER CONSTRAINT close_reason_not_allowed CHECK (ok = 1));
INSERT INTO temp.reason_guard
SELECT CASE WHEN (SELECT a FROM temp.act) = 'close' AND (SELECT kind FROM temp.it) = 'issue'
            THEN coalesce(json_extract(j, '$.close_reason'), '') IN ('completed', 'not planned')
            ELSE coalesce(json_extract(j, '$.close_reason'), '') = '' END
FROM temp.input;

-- Comment: the draft file exists, is UTF-8 text, and is 1 to 6000 bytes.
CREATE TEMP TABLE body (b BLOB);
INSERT INTO temp.body SELECT readfile(draft_path) FROM temp.it WHERE (SELECT a FROM temp.act) = 'comment';
CREATE TEMP TABLE body_guard (ok INTEGER CONSTRAINT draft_missing_empty_or_too_long CHECK (ok = 1));
INSERT INTO temp.body_guard
SELECT CASE WHEN (SELECT a FROM temp.act) <> 'comment' THEN 1
            ELSE coalesce((SELECT length(b) BETWEEN 1 AND 6000 AND length(trim(CAST(b AS TEXT))) > 0 FROM temp.body), 0) END;

INSERT INTO approvals (item_id, action, labels, close_reason, body_file, body_sha3, exact_step, seen_state, seen_updated_at, asked_at)
SELECT t.id, a.a,
       CASE a.a WHEN 'add-labels' THEN (SELECT json_group_array(name) FROM (SELECT name FROM temp.lb ORDER BY k)) ELSE '[]' END,
       coalesce(json_extract(i.j, '$.close_reason'), ''),
       CASE a.a WHEN 'comment' THEN t.draft_path ELSE '' END,
       CASE a.a WHEN 'comment' THEN (SELECT hex(sha3(b, 256)) FROM temp.body) ELSE '' END,
       'gh ' || t.cli || ' ' ||
       CASE a.a
         WHEN 'add-labels' THEN 'edit ' || t.number || ' --repo ' || t.repo ||
              (SELECT group_concat(' --add-label ''' || name || '''', '') FROM (SELECT name FROM temp.lb ORDER BY k))
         WHEN 'comment' THEN 'comment ' || t.number || ' --repo ' || t.repo || ' --body-file ' || t.draft_path
         WHEN 'close' THEN 'close ' || t.number || ' --repo ' || t.repo ||
              CASE WHEN t.kind = 'issue' THEN ' --reason ''' || json_extract(i.j, '$.close_reason') || '''' ELSE '' END
       END,
       t.state, t.updated_at, strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
FROM temp.it AS t, temp.act AS a, temp.input AS i
RETURNING id AS approval_id, action, exact_step, body_file, seen_updated_at;

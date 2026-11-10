-- Run right before the outward step. Fails unless the approval is granted, unused, and bound to the current head. Input: approval_id, action, head_sha (current), now.
-- Run from the workspace root:
--   sqlite3 -bail -json contributions.db ".read references/sql/use-approval.sql"
-- Input: write db-input.json with the write tool first, with "step": "use-approval".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'use-approval'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE use_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.use_guard SELECT count(*) FROM approvals AS a, temp.input AS i
WHERE a.id = json_extract(i.j, '$.approval_id')
  AND a.action = json_extract(i.j, '$.action')
  AND a.decision = 'granted'
  AND a.used_at IS NULL
  AND (a.head_sha = '' OR a.head_sha = coalesce(json_extract(i.j, '$.head_sha'), ''));

UPDATE approvals SET used_at = (SELECT json_extract(j, '$.now') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input)
RETURNING id AS approval_id, action, exact_step, used_at;

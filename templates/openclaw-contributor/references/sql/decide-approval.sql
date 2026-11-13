-- Record the owner's answer to one approval request. Input: approval_id, decision (granted or denied), owner_words (the owner's reply, quoted), now.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/decide-approval.sql"
-- Input: write db-input.json with the write tool first, with "step": "decide-approval".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'decide-approval'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE pending_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.pending_guard SELECT count(*) FROM approvals
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input) AND decision = 'pending';

UPDATE approvals SET
  decision = (SELECT json_extract(j, '$.decision') FROM temp.input),
  owner_words = (SELECT coalesce(json_extract(j, '$.owner_words'), '') FROM temp.input),
  decided_at = (SELECT json_extract(j, '$.now') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input)
RETURNING id AS approval_id, action, decision;

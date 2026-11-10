-- Record what happened after an approved step: the verified result, such as the pushed SHA or the PR url. Input: approval_id, outcome.
-- Run from the workspace root:
--   sqlite3 -bail -json contributions.db ".read references/sql/approval-outcome.sql"
-- Input: write db-input.json with the write tool first, with "step": "approval-outcome".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'approval-outcome'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

UPDATE approvals SET outcome = (SELECT json_extract(j, '$.outcome') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input) AND used_at IS NOT NULL
RETURNING id AS approval_id, action, outcome;

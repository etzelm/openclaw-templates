-- Record the verified result of an outward step: the pushed SHA, the PR url, or "not run: <error line>" when the command never ran. Input: approval_id, outcome.
-- Works for a used approval, and for a recorded-outside one (the owner did the step; you checked the result read only).
-- Run from the workspace root:
--   sqlite3 -bail -json "<db_path>" ".parameter set @db_input db-input/<slug>.json" ".read references/sql/approval-outcome.sql"
-- Input: write db-input/<slug>.json (the task's own file) with the write tool first, with "step": "approval-outcome".
-- Issue, PR and page text goes only into that file, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile(coalesce(@db_input, 'db-input.json')) AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'approval-outcome'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE outcome_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.outcome_guard SELECT count(*) FROM approvals
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input)
  AND (used_at IS NOT NULL OR decision = 'recorded-outside')
  AND length(trim(coalesce((SELECT json_extract(j, '$.outcome') FROM temp.input), ''))) > 0;

UPDATE approvals SET outcome = (SELECT json_extract(j, '$.outcome') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input)
RETURNING id AS approval_id, action, outcome;

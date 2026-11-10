-- Write ahead before asking the owner for one outward step. Input: candidate_id, contribution_id (or null), action, exact_step, head_sha, now. Returns the approval id to name in the request.
-- Run from the workspace root:
--   sqlite3 -bail -json contributions.db ".read references/sql/ask-approval.sql"
-- Input: write db-input.json with the write tool first, with "step": "ask-approval".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'ask-approval'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at)
SELECT json_extract(j, '$.candidate_id'), json_extract(j, '$.contribution_id'),
       json_extract(j, '$.action'), json_extract(j, '$.exact_step'),
       coalesce(json_extract(j, '$.head_sha'), ''), json_extract(j, '$.now')
FROM temp.input
RETURNING id AS approval_id, action, head_sha, decision;

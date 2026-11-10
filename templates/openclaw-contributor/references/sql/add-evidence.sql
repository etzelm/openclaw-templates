-- Record one proof item. Input: contribution_id, kind, command, exit_code, result, commit_sha, log_path, note, now.
-- Run from the workspace root:
--   sqlite3 -bail -json contributions.db ".read references/sql/add-evidence.sql"
-- Input: write db-input.json with the write tool first, with "step": "add-evidence".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'add-evidence'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

INSERT INTO evidence (contribution_id, kind, command, exit_code, result, commit_sha, log_path, note, recorded_at)
SELECT json_extract(j, '$.contribution_id'), json_extract(j, '$.kind'),
       coalesce(json_extract(j, '$.command'), ''), json_extract(j, '$.exit_code'),
       json_extract(j, '$.result'), coalesce(json_extract(j, '$.commit_sha'), ''),
       coalesce(json_extract(j, '$.log_path'), ''), coalesce(json_extract(j, '$.note'), ''),
       json_extract(j, '$.now')
FROM temp.input
RETURNING id AS evidence_id, kind, result, commit_sha;

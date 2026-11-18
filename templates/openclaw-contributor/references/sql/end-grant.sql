-- End an open standing grant: the target was reached, a stop condition hit, or the owner revoked it. Input: grant_id, end_reason, now.
-- After this, no approval can be granted or used under it.
-- Run from the workspace root:
--   sqlite3 -bail -json "<db_path>" ".parameter set @db_input db-input/<slug>.json" ".read references/sql/end-grant.sql"
-- Input: write db-input/<slug>.json (the task's own file) with the write tool first, with "step": "end-grant".
-- Issue, PR and page text goes only into that file, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile(coalesce(@db_input, 'db-input.json')) AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'end-grant'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE open_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.open_guard SELECT count(*) FROM grants
WHERE id = (SELECT json_extract(j, '$.grant_id') FROM temp.input) AND ended_at IS NULL
  AND length(trim(coalesce((SELECT json_extract(j, '$.end_reason') FROM temp.input), ''))) > 0;

UPDATE grants SET
  ended_at = (SELECT json_extract(j, '$.now') FROM temp.input),
  end_reason = (SELECT json_extract(j, '$.end_reason') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.grant_id') FROM temp.input)
RETURNING id AS grant_id, ended_at, end_reason;

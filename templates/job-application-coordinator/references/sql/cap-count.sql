-- Daily cap count. Input: day (today in the owner's time_zone, YYYY-MM-DD).
-- Run from the workspace root:
--   sqlite3 -bail -json applications.db ".read references/sql/cap-count.sql"
-- Input: write db-input.json with the write tool first, with "step": "cap-count".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'cap-count'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

SELECT count(*) AS cap_count
FROM applications
WHERE day = (SELECT json_extract(j, '$.day') FROM temp.input)
  AND status IN ('applied', 'ready-for-owner-review', 'held', 'dry-run');

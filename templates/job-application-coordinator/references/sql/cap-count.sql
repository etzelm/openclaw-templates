-- Daily cap count. Input: day (today in the owner's time_zone, YYYY-MM-DD).
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/cap-count.sql"
-- Input: write db-input.json with the write tool first, with "step": "cap-count".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'cap-count'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- The day must be a real YYYY-MM-DD date; anything else stops the step instead of counting 0.
CREATE TEMP TABLE day_guard (d TEXT NOT NULL CHECK (d GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'));
INSERT INTO temp.day_guard SELECT json_extract(j, '$.day') FROM temp.input;

-- Count each application once if, on that day, it entered or was retried in a counted
-- status. Later status changes (interviewing, closed) and retries on a later day never
-- lower the count for an earlier day.
SELECT count(DISTINCT application_id) AS cap_count
FROM status_events
WHERE day = (SELECT json_extract(j, '$.day') FROM temp.input)
  AND to_status IN ('applied', 'ready-for-owner-review', 'held', 'dry-run');

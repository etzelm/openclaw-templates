-- Write ahead: insert or update the application row. Run it before any owner message and before any Submit click. Input: posting_id, status, note, resume_file, now, day, new_attempt (0 or 1), auto_retry (0 or 1). A status_events row is added by trigger.
-- Run from the workspace root:
--   sqlite3 -bail -json applications.db ".read references/sql/save-application.sql"
-- Input: write db-input.json with the write tool first, with "step": "save-application".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'save-application'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

INSERT INTO applications (posting_id, status, attempts, auto_retries, resume_file, day, created_at, updated_at, note)
SELECT
  json_extract(j, '$.posting_id'),
  json_extract(j, '$.status'),
  coalesce(json_extract(j, '$.new_attempt'), 0),
  coalesce(json_extract(j, '$.auto_retry'), 0),
  coalesce(json_extract(j, '$.resume_file'), ''),
  json_extract(j, '$.day'),
  json_extract(j, '$.now'),
  json_extract(j, '$.now'),
  coalesce(json_extract(j, '$.note'), '')
FROM temp.input WHERE true
ON CONFLICT (posting_id) DO UPDATE SET
  status = excluded.status,
  attempts = attempts + excluded.attempts,
  auto_retries = auto_retries + excluded.auto_retries,
  resume_file = CASE WHEN excluded.resume_file = '' THEN resume_file ELSE excluded.resume_file END,
  day = excluded.day,
  updated_at = excluded.updated_at,
  note = excluded.note
RETURNING id AS application_id, status, attempts, auto_retries, day, note;

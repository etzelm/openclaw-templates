-- Change one application's status, for example to applied after the success page, or for the owner. Input: application_id, status, note, now. A status_events row is added by trigger.
-- Run from the workspace root:
--   sqlite3 -bail -json applications.db ".read references/sql/set-status.sql"
-- Input: write db-input.json with the write tool first, with "step": "set-status".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'set-status'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

UPDATE applications SET
  status = (SELECT json_extract(j, '$.status') FROM temp.input),
  note = (SELECT coalesce(json_extract(j, '$.note'), '') FROM temp.input),
  updated_at = (SELECT json_extract(j, '$.now') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.application_id') FROM temp.input)
RETURNING id AS application_id, status, note;

-- End of run: close the runs row. Input: run_id, ended_at, end_reason, counts (an object).
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/run-end.sql"
-- Input: write db-input.json with the write tool first, with "step": "run-end".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 2));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'run-end'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

UPDATE runs SET
  ended_at = (SELECT json_extract(j, '$.ended_at') FROM temp.input),
  end_reason = (SELECT json_extract(j, '$.end_reason') FROM temp.input),
  counts = (SELECT coalesce(json(json_extract(j, '$.counts')), '{}') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.run_id') FROM temp.input)
RETURNING id AS run_id, ended_at, end_reason, counts;

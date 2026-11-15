-- Start of run: add a runs row. Input: mode (dry-run, confirm or autopilot). Times come from the database clock (UTC).
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/run-start.sql"
-- Input: write db-input.json with the write tool first, with "step": "run-start".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'run-start'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

INSERT INTO runs (started_at, mode)
SELECT strftime('%Y-%m-%dT%H:%M:%SZ', 'now'), json_extract(j, '$.mode') FROM temp.input
RETURNING id AS run_id, started_at, mode;

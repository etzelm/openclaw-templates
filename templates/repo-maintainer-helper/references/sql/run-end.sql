-- End a run. Input: run_id, note (optional: why it ended early). Refuses a run that already ended.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/run-end.sql"
-- Input: write db-input.json with the write tool first, with "step": "run-end".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'run-end'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE open_guard (n INTEGER CONSTRAINT run_unknown_or_ended CHECK (n = 1));
INSERT INTO temp.open_guard SELECT count(*) FROM runs
WHERE id = (SELECT json_extract(j, '$.run_id') FROM temp.input) AND ended_at IS NULL;

UPDATE runs SET
  ended_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'),
  note = coalesce((SELECT json_extract(j, '$.note') FROM temp.input), '')
WHERE id = (SELECT json_extract(j, '$.run_id') FROM temp.input)
RETURNING id AS run_id, kind, started_at, ended_at, note;

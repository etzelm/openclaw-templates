-- Register one repository from settings.md. Input: repo (owner/name). Safe to repeat.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/add-repo.sql"
-- Input: write db-input.json with the write tool first, with "step": "add-repo".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'add-repo'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- The repos table checks the name (letters, digits, dot, dash, underscore, one slash).
INSERT INTO repos (repo, added_at)
SELECT json_extract(j, '$.repo'), strftime('%Y-%m-%dT%H:%M:%SZ', 'now') FROM temp.input WHERE true
ON CONFLICT (repo) DO NOTHING;

SELECT repo, added_at, newest_issue, newest_pr FROM repos
WHERE repo = (SELECT json_extract(j, '$.repo') FROM temp.input);

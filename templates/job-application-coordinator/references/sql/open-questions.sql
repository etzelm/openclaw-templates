-- New questions for the digest: every question not yet answered, with how many postings wait on it. Input: none besides the step name. At most 50 rows.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/open-questions.sql"
-- Input: write db-input.json with the write tool first, with "step": "open-questions".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'open-questions'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

SELECT q.id AS question_id, q.question, q.first_seen,
       (SELECT count(*) FROM question_postings AS qp WHERE qp.question_id = q.id) AS waiting
FROM questions AS q
WHERE q.answered_at IS NULL
ORDER BY waiting DESC, q.id
LIMIT 50;

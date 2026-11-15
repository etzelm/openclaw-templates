-- Mark one question answered, only after the owner's own answer in the conversation was added to answers.md. Never in a scheduled run. Input: question_id. Returns now_eligible: postings that every answered question now unlocks. Refuses an unknown or already answered question. Times come from the database clock (UTC).
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/mark-answered.sql"
-- Input: write db-input.json with the write tool first, with "step": "mark-answered".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'mark-answered'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- The question must exist and still be open.
CREATE TEMP TABLE open_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.open_guard
SELECT count(*) FROM questions
WHERE id = (SELECT json_extract(j, '$.question_id') FROM temp.input) AND answered_at IS NULL;

UPDATE questions SET answered_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
WHERE id = (SELECT json_extract(j, '$.question_id') FROM temp.input) AND answered_at IS NULL;

SELECT q.id AS question_id, q.question, q.answered_at,
  (SELECT count(*) FROM question_postings AS qp
   JOIN applications AS a ON a.id = qp.application_id
   WHERE qp.question_id = q.id
     AND a.status = 'skipped' AND a.note = 'unknown question' AND a.attempts < 2
     AND NOT EXISTS (
       SELECT 1 FROM question_postings AS qp2 JOIN questions AS q2 ON q2.id = qp2.question_id
       WHERE qp2.application_id = a.id AND q2.answered_at IS NULL)) AS now_eligible
FROM questions AS q
WHERE q.id = (SELECT json_extract(j, '$.question_id') FROM temp.input);

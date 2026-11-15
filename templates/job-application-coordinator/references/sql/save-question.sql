-- Record a required question that no file answers, for the posting skipped as "unknown question". Input: application_id, question (as the form shows it). Returns question_id. The same question in other case or spacing is one row. Times come from the database clock (UTC).
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/save-question.sql"
-- Input: write db-input.json with the write tool first, with "step": "save-question".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'save-question'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE q (
  question TEXT NOT NULL CHECK (length(trim(question)) BETWEEN 1 AND 500),
  question_key TEXT NOT NULL
);
INSERT INTO temp.q
SELECT trim(json_extract(j, '$.question')),
       trim(replace(replace(replace(replace(replace(replace(lower(json_extract(j, '$.question')),
         char(9), ' '), char(10), ' '), char(13), ' '), '  ', ' '), '  ', ' '), '  ', ' '))
FROM temp.input;

BEGIN;
INSERT INTO questions (question, question_key, first_seen)
SELECT question, question_key, strftime('%Y-%m-%dT%H:%M:%SZ', 'now') FROM temp.q WHERE true
ON CONFLICT (question_key) DO NOTHING;
INSERT OR IGNORE INTO question_postings (question_id, application_id)
SELECT qs.id, json_extract(i.j, '$.application_id')
FROM temp.input AS i, questions AS qs
WHERE qs.question_key = (SELECT question_key FROM temp.q);
COMMIT;
SELECT qs.id AS question_id, qs.question, qs.answered_at,
       (SELECT count(*) FROM question_postings AS qp WHERE qp.question_id = qs.id) AS waiting
FROM questions AS qs WHERE qs.question_key = (SELECT question_key FROM temp.q);

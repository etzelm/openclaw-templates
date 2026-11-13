-- Fill order after the fit checks. Input: since_day (14 days ago), today. Returns at most 25 rows, highest score first, then oldest posting. kind is new for a fit prospect, or retry-answered for a posting skipped as "unknown question" whose questions the owner has all answered and that has an attempt left.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/ranked-queue.sql"
-- Input: write db-input.json with the write tool first, with "step": "ranked-queue".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'ranked-queue'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- Both dates must be real YYYY-MM-DD dates.
CREATE TEMP TABLE day_guard (d TEXT NOT NULL CHECK (d GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'));
INSERT INTO temp.day_guard SELECT json_extract(j, '$.since_day') FROM temp.input;
INSERT INTO temp.day_guard SELECT json_extract(j, '$.today') FROM temp.input;

SELECT
  p.id AS posting_id,
  a.id AS application_id,
  p.company,
  p.title,
  p.link,
  p.score,
  p.score_reason,
  p.fit_reason,
  a.status,
  a.attempts,
  CASE WHEN a.status = 'prospect' THEN 'new' ELSE 'retry-answered' END AS kind
FROM applications AS a
JOIN postings AS p ON p.id = a.posting_id
WHERE p.stage = 'fit'
  AND a.day >= (SELECT json_extract(j, '$.since_day') FROM temp.input)
  AND (
    a.status = 'prospect'
    OR (a.status = 'skipped' AND a.note = 'unknown question' AND a.attempts < 2
        AND EXISTS (SELECT 1 FROM question_postings AS qp WHERE qp.application_id = a.id)
        AND NOT EXISTS (
          SELECT 1 FROM question_postings AS qp JOIN questions AS q ON q.id = qp.question_id
          WHERE qp.application_id = a.id AND q.answered_at IS NULL))
  )
ORDER BY p.score IS NULL, p.score DESC, p.id
LIMIT 25;

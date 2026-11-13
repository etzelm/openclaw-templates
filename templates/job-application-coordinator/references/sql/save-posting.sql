-- Save a posting after its fit check, with its full job description. Input: company, title, link, source, first_seen, job_description, fit_reason, stage (fit or no-fit), score (0 to 100 for fit, null for no-fit), score_reason. Returns posting_id.
-- A pre-filter miss uses save-prefiltered instead.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/save-posting.sql"
-- Input: write db-input.json with the write tool first, with "step": "save-posting".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'save-posting'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- stage is fit or no-fit. A fit posting has a whole-number score from 0 to 100; a no-fit
-- posting has none. Anything else stops the step.
CREATE TEMP TABLE fit_guard (
  stage TEXT NOT NULL CHECK (stage IN ('fit', 'no-fit')),
  score ANY,
  CHECK ((stage = 'fit' AND typeof(score) = 'integer' AND score BETWEEN 0 AND 100)
      OR (stage = 'no-fit' AND score IS NULL))
);
INSERT INTO temp.fit_guard SELECT json_extract(j, '$.stage'), json_extract(j, '$.score') FROM temp.input;

INSERT INTO postings (company, title, link, source, first_seen, job_description, fit_reason, stage, score, score_reason)
SELECT
  json_extract(j, '$.company'),
  json_extract(j, '$.title'),
  json_extract(j, '$.link'),
  coalesce(json_extract(j, '$.source'), ''),
  json_extract(j, '$.first_seen'),
  coalesce(json_extract(j, '$.job_description'), ''),
  coalesce(json_extract(j, '$.fit_reason'), ''),
  json_extract(j, '$.stage'),
  json_extract(j, '$.score'),
  coalesce(json_extract(j, '$.score_reason'), '')
FROM temp.input WHERE true
ON CONFLICT (link) DO UPDATE SET
  job_description = CASE WHEN excluded.job_description = '' THEN job_description ELSE excluded.job_description END,
  fit_reason = excluded.fit_reason,
  stage = excluded.stage,
  score = excluded.score,
  score_reason = excluded.score_reason
RETURNING id AS posting_id, company, title, length(job_description) AS description_chars, stage, score;

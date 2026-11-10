-- Record every filled field for one application. Replaces earlier answers from a failed attempt. Input: application_id, answers: [{field_label, value, source (answers, resume, profile or computed), flagged (0 or 1)}].
-- Run from the workspace root:
--   sqlite3 -bail -json applications.db ".read references/sql/save-answers.sql"
-- Input: write db-input.json with the write tool first, with "step": "save-answers".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'save-answers'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

BEGIN;
DELETE FROM answers WHERE application_id = (SELECT json_extract(j, '$.application_id') FROM temp.input);
INSERT INTO answers (application_id, field_label, value, source, flagged)
SELECT
  json_extract(i.j, '$.application_id'),
  json_extract(e.value, '$.field_label'),
  coalesce(json_extract(e.value, '$.value'), ''),
  json_extract(e.value, '$.source'),
  coalesce(json_extract(e.value, '$.flagged'), 0)
FROM temp.input AS i, json_each(i.j, '$.answers') AS e;
COMMIT;
SELECT application_id, count(*) AS answers, sum(flagged) AS flagged
FROM answers
WHERE application_id = (SELECT json_extract(j, '$.application_id') FROM temp.input)
GROUP BY application_id;

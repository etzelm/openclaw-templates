-- Parked rows to reconcile at run start. Input: since_day (14 days ago), today. At most 10 rows. can_retry is 1 when the one automatic retry is still open.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/parked-rows.sql"
-- Input: write db-input.json with the write tool first, with "step": "parked-rows".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 2));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'parked-rows'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- Both dates must be real YYYY-MM-DD dates.
CREATE TEMP TABLE day_guard (d TEXT NOT NULL CHECK (d GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'));
INSERT INTO temp.day_guard SELECT json_extract(j, '$.since_day') FROM temp.input;
INSERT INTO temp.day_guard SELECT json_extract(j, '$.today') FROM temp.input;

SELECT
  a.id AS application_id,
  p.company,
  p.title,
  p.link,
  a.status,
  a.day,
  a.auto_retries,
  a.note,
  CASE WHEN a.auto_retries = 0 AND a.status <> 'applied'
            AND a.day < (SELECT json_extract(j, '$.today') FROM temp.input)
       THEN 1 ELSE 0 END AS can_retry
FROM applications AS a
JOIN postings AS p ON p.id = a.posting_id
WHERE (a.status IN ('held', 'ready-for-owner-review')
       OR (a.status = 'applied' AND a.note = 'submit clicked, unconfirmed'))
  AND a.day >= (SELECT json_extract(j, '$.since_day') FROM temp.input)
ORDER BY a.day, a.id
LIMIT 10;

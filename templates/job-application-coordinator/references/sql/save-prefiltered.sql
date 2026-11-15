-- Pre-filter miss: record a posting and its skipped application in one step, without its description. Input: company, title, link, source, reason, day. Use it only for a clear miss on title, location or work setup against the pre-filter rules in profile.md. Times come from the database clock (UTC).
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/save-prefiltered.sql"
-- Input: write db-input.json with the write tool first, with "step": "save-prefiltered".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'save-prefiltered'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- A short reason and a real YYYY-MM-DD day are required.
CREATE TEMP TABLE reason_guard (r TEXT NOT NULL CHECK (length(trim(r)) BETWEEN 1 AND 200));
INSERT INTO temp.reason_guard SELECT json_extract(j, '$.reason') FROM temp.input;
CREATE TEMP TABLE day_guard (d TEXT NOT NULL CHECK (d GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'));
INSERT INTO temp.day_guard SELECT json_extract(j, '$.day') FROM temp.input;

BEGIN;
-- A link already in the database is left as it is: find-posting runs first and decides.
INSERT INTO postings (company, title, link, source, first_seen, job_description, fit_reason, stage)
SELECT
  json_extract(j, '$.company'),
  json_extract(j, '$.title'),
  json_extract(j, '$.link'),
  coalesce(json_extract(j, '$.source'), ''),
  strftime('%Y-%m-%dT%H:%M:%SZ', 'now'),
  '',
  trim(json_extract(j, '$.reason')),
  'prefiltered'
FROM temp.input WHERE true
ON CONFLICT (link) DO NOTHING;
INSERT INTO applications (posting_id, status, day, created_at, updated_at, note)
SELECT p.id, 'skipped', json_extract(i.j, '$.day'), strftime('%Y-%m-%dT%H:%M:%SZ', 'now'), strftime('%Y-%m-%dT%H:%M:%SZ', 'now'),
       'pre-filter: ' || trim(json_extract(i.j, '$.reason'))
FROM temp.input AS i
JOIN postings AS p ON p.link = json_extract(i.j, '$.link') AND p.stage = 'prefiltered'
WHERE NOT EXISTS (SELECT 1 FROM applications AS a WHERE a.posting_id = p.id);
COMMIT;
SELECT p.id AS posting_id, p.stage, a.id AS application_id, a.status, a.note
FROM postings AS p
LEFT JOIN applications AS a ON a.posting_id = p.id
WHERE p.link = (SELECT json_extract(j, '$.link') FROM temp.input);

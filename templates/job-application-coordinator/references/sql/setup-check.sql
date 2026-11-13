-- Setup check: write one test row, read it back, delete it. Prints setup-check ok. No input.
-- Run from the workspace root:
--   sqlite3 -bail <db_path> ".read references/sql/setup-check.sql"
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;

.headers on
.mode list
CREATE TEMP TABLE expect (what TEXT, n INTEGER, CHECK (
  (what = 'written' AND n = 1) OR (what = 'events' AND n = 1) OR (what = 'left' AND n = 0)
));
BEGIN;
INSERT INTO postings (company, title, link, first_seen, job_description)
VALUES ('setup check', 'setup check', 'setup-check://row', datetime('now'), 'it''s a "test"; DROP TABLE postings; --');
INSERT INTO applications (posting_id, status, day, created_at, updated_at, note)
SELECT id, 'skipped', date('now'), datetime('now'), datetime('now'), 'setup check'
FROM postings WHERE link = 'setup-check://row';
INSERT INTO temp.expect SELECT 'written', count(*) FROM postings
WHERE link = 'setup-check://row' AND job_description = 'it''s a "test"; DROP TABLE postings; --';
INSERT INTO temp.expect SELECT 'events', count(*) FROM status_events AS e
JOIN applications AS a ON a.id = e.application_id
JOIN postings AS p ON p.id = a.posting_id WHERE p.link = 'setup-check://row';
SELECT p.company, p.title, p.job_description, a.status FROM postings AS p
JOIN applications AS a ON a.posting_id = p.id WHERE p.link = 'setup-check://row';
DELETE FROM applications WHERE posting_id = (SELECT id FROM postings WHERE link = 'setup-check://row');
DELETE FROM postings WHERE link = 'setup-check://row';
INSERT INTO temp.expect SELECT 'left', count(*) FROM postings WHERE link = 'setup-check://row';
COMMIT;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT 'setup-check ok, schema version ' || user_version AS result FROM pragma_user_version;

-- Setup check: write test rows, check the approval guards, read back, delete. Prints setup-check ok. No input.
-- Run from the workspace root:
--   sqlite3 -bail <db_path> ".read references/sql/setup-check.sql"
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;

.headers on
.mode list
CREATE TEMP TABLE expect (what TEXT, n INTEGER, CHECK (
  (what = 'written' AND n = 1) OR (what = 'events' AND n = 1) OR (what = 'used' AND n = 1)
  OR (what = 'left' AND n = 0)
));
BEGIN;
INSERT INTO candidates (repo, url, title, first_seen, updated_at, decision)
VALUES ('setup/check', 'setup-check://row', 'it''s a "test"; DROP TABLE candidates; --',
        datetime('now'), datetime('now'), 'approved');
INSERT INTO contributions (candidate_id, slug, branch, status, created_at, updated_at, note)
SELECT id, 'setup-check', 'setup-check', 'scope-approved', datetime('now'), datetime('now'), 'setup check'
FROM candidates WHERE url = 'setup-check://row';
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at)
SELECT c.id, k.id, 'push', 'setup check', 'abc', datetime('now')
FROM candidates AS c JOIN contributions AS k ON k.candidate_id = c.id WHERE c.url = 'setup-check://row';
UPDATE approvals SET decision = 'granted', decided_at = datetime('now') WHERE exact_step = 'setup check';
UPDATE approvals SET used_at = datetime('now') WHERE exact_step = 'setup check';
INSERT INTO temp.expect SELECT 'written', count(*) FROM candidates
WHERE url = 'setup-check://row' AND title = 'it''s a "test"; DROP TABLE candidates; --';
INSERT INTO temp.expect SELECT 'events', count(*) FROM status_events AS e
JOIN contributions AS k ON k.id = e.contribution_id WHERE k.slug = 'setup-check';
INSERT INTO temp.expect SELECT 'used', count(*) FROM approvals
WHERE exact_step = 'setup check' AND used_at IS NOT NULL;
SELECT c.title, k.status, a.decision FROM candidates AS c
JOIN contributions AS k ON k.candidate_id = c.id
JOIN approvals AS a ON a.contribution_id = k.id WHERE c.url = 'setup-check://row';
DELETE FROM approvals WHERE exact_step = 'setup check';
DELETE FROM contributions WHERE slug = 'setup-check';
DELETE FROM candidates WHERE url = 'setup-check://row';
INSERT INTO temp.expect SELECT 'left', count(*) FROM candidates WHERE url = 'setup-check://row';
COMMIT;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT 'setup-check ok, schema version ' || user_version AS result FROM pragma_user_version;

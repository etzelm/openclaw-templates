-- One-time upgrade of a job application coordinator database from schema version 2 (0.2.x) to version 3 (0.3.0).
-- Run only during setup, only after the owner has made their own copy of the file, and only
-- when `PRAGMA user_version;` prints 2:
--   sqlite3 -bail <db_path> ".read references/sql/migrate-v2-to-v3.sql"
-- It refuses any database that is not version 2, so running it twice changes nothing.
-- Version 3 adds postings.stage, postings.score and postings.score_reason, and the
-- questions and question_postings tables for learned questions.
-- Old postings whose application ever reached a status that only follows a fit check
-- get stage fit. Others keep ''. Old rows get no score.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 2));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;

BEGIN;
ALTER TABLE postings ADD COLUMN stage TEXT NOT NULL DEFAULT '' CHECK (stage IN ('', 'prefiltered', 'no-fit', 'fit'));
ALTER TABLE postings ADD COLUMN score INTEGER CHECK (score IS NULL OR (score BETWEEN 0 AND 100));
ALTER TABLE postings ADD COLUMN score_reason TEXT NOT NULL DEFAULT '';

UPDATE postings SET stage = 'fit'
WHERE EXISTS (
  SELECT 1 FROM applications AS a JOIN status_events AS e ON e.application_id = a.id
  WHERE a.posting_id = postings.id
    AND e.to_status IN ('prospect', 'ready-for-owner-review', 'applied', 'interviewing',
                        'offer-review', 'dry-run', 'held', 'handoff')
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  question TEXT NOT NULL CHECK (length(trim(question)) BETWEEN 1 AND 500),
  -- Lower case, spaces collapsed: one row per question whatever its case or spacing.
  question_key TEXT NOT NULL UNIQUE,
  first_seen TEXT NOT NULL,
  answered_at TEXT
);

CREATE TABLE question_postings (
  question_id INTEGER NOT NULL REFERENCES questions (id) ON DELETE CASCADE,
  application_id INTEGER NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  PRIMARY KEY (question_id, application_id)
);

CREATE INDEX question_postings_application ON question_postings (application_id);

PRAGMA user_version = 3;
COMMIT;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT 'migrate ok, schema version ' || user_version AS result FROM pragma_user_version;

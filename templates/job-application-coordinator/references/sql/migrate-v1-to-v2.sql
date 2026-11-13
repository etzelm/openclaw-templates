-- One-time upgrade of a job application coordinator database from schema version 1 (0.1.x) to version 2 (0.2.0).
-- Run only during setup, only after the owner has made their own copy of the file, and only
-- when `PRAGMA user_version;` prints 1:
--   sqlite3 -bail <db_path> ".read references/sql/migrate-v1-to-v2.sql"
-- It refuses any database that is not version 1, so running it twice changes nothing.
-- Version 2 adds status_events.day so the daily cap counts from history.
-- Old events get the day of their application row, the best date version 1 kept.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;

BEGIN;
ALTER TABLE status_events ADD COLUMN day TEXT NOT NULL DEFAULT '';
UPDATE status_events SET day = coalesce((
  SELECT a.day FROM applications AS a WHERE a.id = status_events.application_id
), '');
CREATE INDEX status_events_day ON status_events (day, to_status);

DROP TRIGGER applications_insert_event;
DROP TRIGGER applications_status_event;

CREATE TRIGGER applications_insert_event AFTER INSERT ON applications
BEGIN
  INSERT INTO status_events (application_id, at, from_status, to_status, note, day)
  VALUES (NEW.id, NEW.updated_at, NULL, NEW.status, NEW.note, NEW.day);
END;

CREATE TRIGGER applications_status_event AFTER UPDATE OF status, note, day ON applications
WHEN OLD.status IS NOT NEW.status OR OLD.note IS NOT NEW.note OR OLD.day IS NOT NEW.day
BEGIN
  INSERT INTO status_events (application_id, at, from_status, to_status, note, day)
  VALUES (NEW.id, NEW.updated_at, OLD.status, NEW.status, NEW.note, NEW.day);
END;

PRAGMA user_version = 2;
COMMIT;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT 'migrate ok, schema version ' || user_version AS result FROM pragma_user_version;

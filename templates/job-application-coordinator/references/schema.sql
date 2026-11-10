-- applications.db schema, version 1.
-- Setup runs this once, only when applications.db does not exist:
--   sqlite3 -bail applications.db ".read references/schema.sql"
-- Never run it against an existing database. No automatic migrations in v1.

PRAGMA foreign_keys = ON;

BEGIN;

CREATE TABLE postings (
  id INTEGER PRIMARY KEY,
  company TEXT NOT NULL CHECK (length(company) BETWEEN 1 AND 200),
  title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  link TEXT NOT NULL UNIQUE CHECK (length(link) BETWEEN 1 AND 2000),
  source TEXT NOT NULL DEFAULT '',
  first_seen TEXT NOT NULL,
  job_description TEXT NOT NULL DEFAULT '',
  fit_reason TEXT NOT NULL DEFAULT '',
  -- Normalized company: lower case, common punctuation to spaces, spaces collapsed.
  company_key TEXT GENERATED ALWAYS AS (
    trim(replace(replace(replace(
      replace(replace(replace(replace(replace(replace(replace(lower(company),
        ',', ' '), '.', ' '), '-', ' '), '/', ' '), '(', ' '), ')', ' '), '&', ' '),
      '  ', ' '), '  ', ' '), '  ', ' '))
  ) STORED,
  -- Normalized company plus title. The strict duplicate key.
  dedup_key TEXT GENERATED ALWAYS AS (
    trim(replace(replace(replace(
      replace(replace(replace(replace(replace(replace(replace(lower(company),
        ',', ' '), '.', ' '), '-', ' '), '/', ' '), '(', ' '), ')', ' '), '&', ' '),
      '  ', ' '), '  ', ' '), '  ', ' '))
    || '|' ||
    trim(replace(replace(replace(
      replace(replace(replace(replace(replace(replace(replace(lower(title),
        ',', ' '), '.', ' '), '-', ' '), '/', ' '), '(', ' '), ')', ' '), '&', ' '),
      '  ', ' '), '  ', ' '), '  ', ' '))
  ) STORED
);

CREATE INDEX postings_dedup_key ON postings (dedup_key);
CREATE INDEX postings_company_key ON postings (company_key);

CREATE TABLE applications (
  id INTEGER PRIMARY KEY,
  posting_id INTEGER NOT NULL UNIQUE REFERENCES postings (id) ON DELETE RESTRICT,
  status TEXT NOT NULL CHECK (status IN (
    'prospect', 'ready-for-owner-review', 'applied', 'interviewing', 'offer-review', 'closed',
    'skipped', 'dry-run', 'held', 'handoff'
  )),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 2),
  auto_retries INTEGER NOT NULL DEFAULT 0 CHECK (auto_retries BETWEEN 0 AND 1),
  resume_file TEXT NOT NULL DEFAULT '',
  -- Local date in the owner's time_zone. Used for the daily cap.
  day TEXT NOT NULL CHECK (day GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT ''
);

CREATE INDEX applications_status_day ON applications (status, day);

CREATE TABLE answers (
  id INTEGER PRIMARY KEY,
  application_id INTEGER NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  field_label TEXT NOT NULL CHECK (length(field_label) BETWEEN 1 AND 300),
  value TEXT NOT NULL,
  source TEXT NOT NULL CHECK (source IN ('answers', 'resume', 'profile', 'computed')),
  flagged INTEGER NOT NULL DEFAULT 0 CHECK (flagged IN (0, 1))
);

CREATE INDEX answers_application ON answers (application_id);

CREATE TABLE status_events (
  id INTEGER PRIMARY KEY,
  application_id INTEGER NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  at TEXT NOT NULL,
  from_status TEXT,
  to_status TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT ''
);

CREATE INDEX status_events_application ON status_events (application_id, at);

CREATE TABLE runs (
  id INTEGER PRIMARY KEY,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  mode TEXT NOT NULL CHECK (mode IN ('dry-run', 'confirm', 'autopilot')),
  end_reason TEXT,
  counts TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(counts))
);

-- Every status change, by the agent or by the owner, leaves a status_events row.
CREATE TRIGGER applications_insert_event AFTER INSERT ON applications
BEGIN
  INSERT INTO status_events (application_id, at, from_status, to_status, note)
  VALUES (NEW.id, NEW.updated_at, NULL, NEW.status, NEW.note);
END;

CREATE TRIGGER applications_status_event AFTER UPDATE OF status, note ON applications
WHEN OLD.status IS NOT NEW.status OR OLD.note IS NOT NEW.note
BEGIN
  INSERT INTO status_events (application_id, at, from_status, to_status, note)
  VALUES (NEW.id, NEW.updated_at, OLD.status, NEW.status, NEW.note);
END;

PRAGMA user_version = 1;

COMMIT;

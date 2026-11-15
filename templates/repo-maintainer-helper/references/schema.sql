-- Repo maintainer helper database, schema version 1.
-- Create once at setup:
--   sqlite3 -bail "<db_path>" ".read references/schema.sql"
-- All times the agent did not read from GitHub come from the database clock (UTC).
-- Issue and PR text reaches this database only as JSON values read from files, never as SQL text.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE fresh_guard (n INTEGER CHECK (n = 0));
INSERT INTO temp.fresh_guard SELECT count(*) FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE 'sqlite_%';

BEGIN;

-- One row per repository the owner listed in settings.md.
CREATE TABLE repos (
  repo TEXT PRIMARY KEY CHECK (
    length(repo) BETWEEN 3 AND 140
    AND repo GLOB '?*/?*'
    AND repo NOT GLOB '*/*/*'
    AND repo NOT GLOB '*[^A-Za-z0-9_./-]*'
    AND repo NOT GLOB '[.-]*' AND repo NOT GLOB '*/[.-]*'
  ),
  added_at TEXT NOT NULL,
  -- Newest GitHub updatedAt seen in a list read, per kind. Empty before the first read.
  newest_issue TEXT NOT NULL DEFAULT '',
  newest_pr TEXT NOT NULL DEFAULT ''
);

-- The repository's current label list. Suggested and applied labels must come from here.
CREATE TABLE labels (
  repo TEXT NOT NULL REFERENCES repos (repo),
  name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  PRIMARY KEY (repo, name)
);

CREATE TABLE runs (
  id INTEGER PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('scheduled', 'manual')),
  started_at TEXT NOT NULL,
  ended_at TEXT,
  note TEXT NOT NULL DEFAULT ''
);

-- One row per list read that was ingested, so the digest can name gaps.
CREATE TABLE reads (
  id INTEGER PRIMARY KEY,
  run_id INTEGER REFERENCES runs (id),
  repo TEXT NOT NULL REFERENCES repos (repo),
  kind TEXT NOT NULL CHECK (kind IN ('issue', 'pr')),
  fetched_at TEXT NOT NULL,
  read_count INTEGER NOT NULL,
  new_items INTEGER NOT NULL,
  queued INTEGER NOT NULL,
  -- 1 when the read hit its limit and its oldest item is newer than the newest one seen
  -- before, so changes in between may have been missed.
  limit_reached INTEGER NOT NULL CHECK (limit_reached IN (0, 1)),
  ingested_at TEXT NOT NULL
);

CREATE TABLE items (
  id INTEGER PRIMARY KEY,
  repo TEXT NOT NULL REFERENCES repos (repo),
  kind TEXT NOT NULL CHECK (kind IN ('issue', 'pr')),
  number INTEGER NOT NULL CHECK (typeof(number) = 'integer' AND number > 0),
  title TEXT NOT NULL,
  author TEXT NOT NULL DEFAULT '',
  author_is_bot INTEGER NOT NULL DEFAULT 0 CHECK (author_is_bot IN (0, 1)),
  state TEXT NOT NULL CHECK (state IN ('OPEN', 'CLOSED', 'MERGED')),
  is_draft INTEGER NOT NULL DEFAULT 0 CHECK (is_draft IN (0, 1)),
  labels TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(labels) AND json_type(labels) = 'array'),
  body TEXT NOT NULL DEFAULT '',
  url TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT '',
  -- GitHub's updatedAt from the latest read that included this item.
  updated_at TEXT NOT NULL CHECK (updated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'),
  first_seen TEXT NOT NULL,
  -- Database time of the latest fetch that included this item.
  last_seen TEXT NOT NULL,
  -- The updatedAt the latest triage (or the first-read baseline, or an approved action) covered.
  -- The item is queued for triage while updated_at is newer than this.
  triaged_updated_at TEXT NOT NULL DEFAULT '',
  UNIQUE (repo, number)
);

-- Titles of open and closed items, for the duplicate search (similar.sql).
CREATE VIRTUAL TABLE title_index USING fts5 (
  title,
  repo UNINDEXED,
  number UNINDEXED,
  kind UNINDEXED,
  state UNINDEXED
);

CREATE TABLE triage (
  id INTEGER PRIMARY KEY,
  item_id INTEGER NOT NULL REFERENCES items (id),
  run_id INTEGER REFERENCES runs (id),
  item_updated_at TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN (
    'bug', 'feature', 'question', 'docs', 'duplicate', 'needs-info', 'spam', 'ready-for-review', 'other'
  )),
  labels TEXT NOT NULL DEFAULT '[]' CHECK (
    json_valid(labels) AND json_type(labels) = 'array' AND json_array_length(labels) <= 5
  ),
  duplicate_of INTEGER CHECK (duplicate_of IS NULL OR (typeof(duplicate_of) = 'integer' AND duplicate_of > 0)),
  reason TEXT NOT NULL CHECK (length(trim(reason)) BETWEEN 1 AND 1000),
  suggested_action TEXT NOT NULL DEFAULT 'none' CHECK (suggested_action IN ('none', 'add-labels', 'comment', 'close')),
  created_at TEXT NOT NULL,
  CHECK (category <> 'duplicate' OR duplicate_of IS NOT NULL)
);
CREATE INDEX triage_item ON triage (item_id, id);

-- Suggested labels must exist in the repository's label list.
CREATE TRIGGER triage_labels_known BEFORE INSERT ON triage
WHEN EXISTS (
  SELECT 1 FROM json_each(NEW.labels) AS l
  WHERE l.value NOT IN (
    SELECT lb.name FROM labels AS lb JOIN items AS i ON i.repo = lb.repo WHERE i.id = NEW.item_id
  )
)
BEGIN
  SELECT RAISE(ABORT, 'a suggested label is not in the repository label list');
END;

-- An owner approval for one write to GitHub. The command is built by ask-approval.sql,
-- never by the agent. It is bound to the item as the owner saw it and used once.
CREATE TABLE approvals (
  id INTEGER PRIMARY KEY,
  item_id INTEGER NOT NULL REFERENCES items (id),
  action TEXT NOT NULL CHECK (action IN ('add-labels', 'comment', 'close')),
  labels TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(labels) AND json_type(labels) = 'array'),
  close_reason TEXT NOT NULL DEFAULT '' CHECK (close_reason IN ('', 'completed', 'not planned')),
  body_file TEXT NOT NULL DEFAULT '',
  body_sha3 TEXT NOT NULL DEFAULT '',
  exact_step TEXT NOT NULL CHECK (length(exact_step) BETWEEN 1 AND 2000),
  seen_state TEXT NOT NULL,
  seen_updated_at TEXT NOT NULL,
  asked_at TEXT NOT NULL,
  decision TEXT NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending', 'granted', 'refused', 'withdrawn')),
  owner_words TEXT NOT NULL DEFAULT '',
  decided_at TEXT,
  used_at TEXT,
  outcome TEXT NOT NULL DEFAULT '' CHECK (outcome IN ('', 'done', 'failed')),
  outcome_note TEXT NOT NULL DEFAULT '',
  outcome_at TEXT,
  CHECK (action <> 'comment' OR (body_file <> '' AND body_sha3 <> '')),
  CHECK (action <> 'add-labels' OR json_array_length(labels) BETWEEN 1 AND 5),
  CHECK (decision NOT IN ('granted', 'refused') OR length(trim(owner_words)) > 0),
  CHECK (used_at IS NULL OR decision = 'granted'),
  CHECK (outcome = '' OR used_at IS NOT NULL)
);

-- At most one open request per item and action.
CREATE UNIQUE INDEX approvals_one_pending ON approvals (item_id, action) WHERE decision = 'pending';

-- A decision is made once.
CREATE TRIGGER approvals_decided_once BEFORE UPDATE OF decision ON approvals
WHEN OLD.decision <> 'pending'
BEGIN
  SELECT RAISE(ABORT, 'this request was already decided');
END;

-- An approval is used once, and its outcome is recorded once.
CREATE TRIGGER approvals_used_once BEFORE UPDATE OF used_at ON approvals
WHEN OLD.used_at IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'this approval was already used');
END;
CREATE TRIGGER approvals_outcome_once BEFORE UPDATE OF outcome ON approvals
WHEN OLD.outcome <> ''
BEGIN
  SELECT RAISE(ABORT, 'this outcome was already recorded');
END;

-- What was asked never changes after the request.
CREATE TRIGGER approvals_request_fixed BEFORE UPDATE OF item_id, action, labels, close_reason, body_file, body_sha3, exact_step, seen_state, seen_updated_at, asked_at ON approvals
BEGIN
  SELECT RAISE(ABORT, 'a request cannot be changed; withdraw it and ask again');
END;

COMMIT;
PRAGMA user_version = 1;
SELECT 'schema version 1 created' AS result;

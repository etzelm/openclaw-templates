-- OpenClaw contributor database schema, version 1.
-- Setup runs this once, only when no database exists at db_path (settings.md):
--   sqlite3 -bail <db_path> ".read references/schema.sql"
-- Never run it against an existing database. No automatic migrations in v1.

PRAGMA foreign_keys = ON;

BEGIN;

-- Issues, bugs and PR ideas the agent looked at, and what was decided.
CREATE TABLE candidates (
  id INTEGER PRIMARY KEY,
  repo TEXT NOT NULL CHECK (repo GLOB '?*/?*'),
  number INTEGER CHECK (number IS NULL OR number > 0),
  url TEXT NOT NULL UNIQUE CHECK (length(url) BETWEEN 1 AND 2000),
  title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 300),
  area TEXT NOT NULL DEFAULT '',
  decision TEXT NOT NULL DEFAULT 'considering' CHECK (decision IN (
    'considering', 'proposed', 'approved', 'declined-by-owner', 'duplicate',
    'decided-upstream', 'out-of-scope', 'not-reproducible', 'parked'
  )),
  reason TEXT NOT NULL DEFAULT '',
  -- JSON array of related issues and PRs: [{"ref": "#123", "state": "closed", "note": "..."}].
  related TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(related) AND json_type(related) = 'array'),
  first_seen TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- One local branch and, later, one PR.
CREATE TABLE contributions (
  id INTEGER PRIMARY KEY,
  candidate_id INTEGER NOT NULL REFERENCES candidates (id) ON DELETE RESTRICT,
  slug TEXT NOT NULL UNIQUE CHECK (slug GLOB '[a-z0-9]*' AND slug NOT GLOB '*[^a-z0-9-]*' AND length(slug) <= 60),
  branch TEXT NOT NULL UNIQUE CHECK (length(branch) BETWEEN 1 AND 200),
  base_sha TEXT NOT NULL DEFAULT '',
  head_sha TEXT NOT NULL DEFAULT '',
  pr_url TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL CHECK (status IN (
    'scoping', 'scope-approved', 'reproducing', 'fixing', 'gates', 'ready-local',
    'awaiting-owner', 'pushed', 'pr-open', 'in-review', 'blocked-maintainer-decision',
    'merged', 'closed', 'abandoned'
  )),
  evidence_dir TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT ''
);

CREATE INDEX contributions_status ON contributions (status);

-- Proof: every command whose result the agent reports.
CREATE TABLE evidence (
  id INTEGER PRIMARY KEY,
  contribution_id INTEGER NOT NULL REFERENCES contributions (id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN (
    'repro-red', 'fix-green', 'gate', 'simplify', 'local-review', 'ci-classification', 'other'
  )),
  command TEXT NOT NULL DEFAULT '',
  exit_code INTEGER,
  result TEXT NOT NULL CHECK (result IN ('pass', 'fail', 'info')),
  commit_sha TEXT NOT NULL DEFAULT '',
  log_path TEXT NOT NULL DEFAULT '',
  note TEXT NOT NULL DEFAULT '',
  recorded_at TEXT NOT NULL
);

CREATE INDEX evidence_contribution ON evidence (contribution_id, recorded_at);

-- Owner approvals. One row per outward step. A row is used at most once.
CREATE TABLE approvals (
  id INTEGER PRIMARY KEY,
  candidate_id INTEGER NOT NULL REFERENCES candidates (id) ON DELETE RESTRICT,
  contribution_id INTEGER REFERENCES contributions (id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN (
    'push', 'force-push', 'open-pr', 'open-issue', 'comment', 'edit-pr', 'ready-for-review',
    'request-review', 'resolve-conversation', 'rerun-ci', 'create-fork', 'close', 'reopen', 'other'
  )),
  -- The exact command and body file shown to the owner.
  exact_step TEXT NOT NULL CHECK (length(exact_step) BETWEEN 1 AND 4000),
  head_sha TEXT NOT NULL DEFAULT '',
  asked_at TEXT NOT NULL,
  decision TEXT NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending', 'granted', 'denied')),
  owner_words TEXT NOT NULL DEFAULT '',
  decided_at TEXT,
  used_at TEXT,
  outcome TEXT NOT NULL DEFAULT '',
  CHECK (used_at IS NULL OR decision = 'granted')
);

CREATE INDEX approvals_contribution ON approvals (contribution_id, asked_at);

CREATE TRIGGER approvals_decided_once BEFORE UPDATE OF decision ON approvals
WHEN OLD.decision <> 'pending'
BEGIN
  SELECT RAISE(ABORT, 'approval already decided');
END;

CREATE TRIGGER approvals_used_once BEFORE UPDATE OF used_at ON approvals
WHEN OLD.used_at IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'approval already used');
END;

CREATE TABLE status_events (
  id INTEGER PRIMARY KEY,
  contribution_id INTEGER NOT NULL REFERENCES contributions (id) ON DELETE CASCADE,
  at TEXT NOT NULL,
  from_status TEXT,
  to_status TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT ''
);

CREATE INDEX status_events_contribution ON status_events (contribution_id, at);

-- Every status change leaves a status_events row.
CREATE TRIGGER contributions_insert_event AFTER INSERT ON contributions
BEGIN
  INSERT INTO status_events (contribution_id, at, from_status, to_status, note)
  VALUES (NEW.id, NEW.updated_at, NULL, NEW.status, NEW.note);
END;

CREATE TRIGGER contributions_status_event AFTER UPDATE OF status, note ON contributions
WHEN OLD.status IS NOT NEW.status OR OLD.note IS NOT NEW.note
BEGIN
  INSERT INTO status_events (contribution_id, at, from_status, to_status, note)
  VALUES (NEW.id, NEW.updated_at, OLD.status, NEW.status, NEW.note);
END;

PRAGMA user_version = 1;

COMMIT;

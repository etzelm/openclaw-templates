-- OpenClaw contributor database schema, version 3.
-- Setup runs this once, only when no database exists at db_path (settings.md):
--   sqlite3 -bail <db_path> ".read references/schema.sql"
-- Never run it against an existing database. A version 1 database (0.1.x to 0.3.x)
-- is upgraded in place with references/sql/migrate-v1-to-v2.sql, then migrate-v2-to-v3.sql.
-- A version 2 database (0.4.0, 0.4.1) needs only migrate-v2-to-v3.sql (BOOTSTRAP.md, "Upgrade").

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
    'repro-red', 'fix-green', 'gate', 'simplify', 'local-review', 'hosted-review',
    'ci-classification', 'other'
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

-- Standing grants: the owner allows a short list of outward steps for one open PR, once.
-- Each use is still its own approvals row, granted under the grant (grant_id).
CREATE TABLE grants (
  id INTEGER PRIMARY KEY,
  contribution_id INTEGER NOT NULL REFERENCES contributions (id) ON DELETE RESTRICT,
  pr_url TEXT NOT NULL CHECK (length(pr_url) BETWEEN 1 AND 2000),
  -- JSON array, a subset of push, edit-pr, request-review.
  actions TEXT NOT NULL CHECK (
    json_valid(actions) AND json_type(actions) = 'array' AND json_array_length(actions) > 0
  ),
  -- The scope and the stop conditions shown to the owner, as they saw them.
  scope TEXT NOT NULL CHECK (length(scope) BETWEEN 1 AND 4000),
  stop_conditions TEXT NOT NULL CHECK (length(stop_conditions) BETWEEN 1 AND 4000),
  owner_words TEXT NOT NULL CHECK (length(trim(owner_words)) > 0),
  granted_at TEXT NOT NULL,
  ended_at TEXT,
  end_reason TEXT NOT NULL DEFAULT ''
);

-- At most one open grant per contribution.
CREATE UNIQUE INDEX grants_one_open ON grants (contribution_id) WHERE ended_at IS NULL;

CREATE TRIGGER grants_actions_known BEFORE INSERT ON grants
WHEN EXISTS (SELECT 1 FROM json_each(NEW.actions)
             WHERE value NOT IN ('push', 'edit-pr', 'request-review'))
BEGIN
  SELECT RAISE(ABORT, 'a grant covers only push, edit-pr and request-review');
END;

CREATE TRIGGER grants_ended_once BEFORE UPDATE ON grants
WHEN OLD.ended_at IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'grant already ended');
END;

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
  -- sha256 of the --body-file shown to the owner, when the command has one.
  body_sha256 TEXT NOT NULL DEFAULT '' CHECK (body_sha256 = '' OR (length(body_sha256) = 64 AND body_sha256 NOT GLOB '*[^0-9a-f]*')),
  asked_at TEXT NOT NULL,
  -- granted and denied are the owner's answer. withdrawn: the agent closed the request
  -- before any answer (the step changed or is no longer needed). recorded-outside: the
  -- owner did the step outside this agent; the agent only records the verified result.
  decision TEXT NOT NULL DEFAULT 'pending' CHECK (decision IN (
    'pending', 'granted', 'denied', 'withdrawn', 'recorded-outside'
  )),
  owner_words TEXT NOT NULL DEFAULT '',
  decided_at TEXT,
  used_at TEXT,
  outcome TEXT NOT NULL DEFAULT '',
  -- Set when the row was granted under a standing grant instead of a fresh owner answer.
  grant_id INTEGER REFERENCES grants (id) ON DELETE RESTRICT,
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
-- A row granted under a standing grant must fit the grant exactly: the grant is open, for the
-- same contribution, and lists the action; the head is a full SHA; and the command has the
-- one allowed shape for that action (contribution-loop.md, step 12):
--   push: a plain git push of one refspec to one remote that is not origin, ending in the
--     contribution's branch (`<remote> <branch>` or `<remote> <sha>:refs/heads/<branch>`),
--     with no force, delete, mirror, all, tags or + refspec.
--   edit-pr: gh pr edit <PR number> --repo openclaw/openclaw with --body-file and a body hash, nothing else.
--   request-review: gh pr comment <PR number> --repo openclaw/openclaw --body-file references/re-review.md, whose
--     content is the one line "@clawsweeper re-review" (sha256 below).
-- No shell operators in any of them.
CREATE TRIGGER approvals_grant_scope BEFORE UPDATE OF decision, grant_id ON approvals
WHEN NEW.grant_id IS NOT NULL AND NOT (
  NEW.decision = 'granted'
  AND length(NEW.head_sha) IN (40, 64) AND NEW.head_sha NOT GLOB '*[^0-9a-f]*'
  AND NEW.exact_step NOT GLOB '*[;&|<>`$]*'
  AND EXISTS (
    SELECT 1 FROM grants AS g JOIN contributions AS k ON k.id = g.contribution_id
    WHERE g.id = NEW.grant_id AND g.ended_at IS NULL
      AND g.contribution_id IS NEW.contribution_id
      AND EXISTS (SELECT 1 FROM json_each(g.actions) WHERE value = NEW.action)
      AND CASE NEW.action
        WHEN 'push' THEN
          NEW.exact_step GLOB 'git *' AND ' ' || NEW.exact_step || ' ' GLOB '* push *'
          AND (NEW.exact_step GLOB '* ' || k.branch OR NEW.exact_step GLOB '*:refs/heads/' || k.branch)
          AND substr(NEW.exact_step, instr(NEW.exact_step, ' push ') + 6) GLOB '?* ?*'
          AND substr(NEW.exact_step, instr(NEW.exact_step, ' push ') + 6) NOT GLOB '* * *'
          AND substr(NEW.exact_step, instr(NEW.exact_step, ' push ') + 6) NOT GLOB 'origin *'
          AND ' ' || NEW.exact_step || ' ' NOT GLOB '* -f *'
          AND ' ' || NEW.exact_step || ' ' NOT GLOB '* -d *'
          AND NEW.exact_step NOT GLOB '*--force*' AND NEW.exact_step NOT GLOB '*--delete*'
          AND NEW.exact_step NOT GLOB '*--mirror*' AND NEW.exact_step NOT GLOB '*--all*'
          AND NEW.exact_step NOT GLOB '*--tags*' AND NEW.exact_step NOT GLOB '*--prune*'
          AND NEW.exact_step NOT GLOB '* +*' AND NEW.exact_step NOT GLOB '* :*'
        WHEN 'edit-pr' THEN
          NEW.exact_step GLOB 'gh pr edit *' AND NEW.exact_step GLOB '* --repo openclaw/openclaw*'
          AND instr(' ' || NEW.exact_step || ' ', ' ' || replace(g.pr_url, rtrim(g.pr_url, '0123456789'), '') || ' ') > 0
          AND NEW.exact_step GLOB '* --body-file *' AND length(NEW.body_sha256) = 64
          AND NEW.exact_step NOT GLOB '*--title*' AND ' ' || NEW.exact_step || ' ' NOT GLOB '* -t *'
          AND NEW.exact_step NOT GLOB '*--add-*' AND NEW.exact_step NOT GLOB '*--remove-*'
          AND NEW.exact_step NOT GLOB '*--base*' AND ' ' || NEW.exact_step || ' ' NOT GLOB '* -B *'
          AND NEW.exact_step NOT GLOB '*--milestone*'
        WHEN 'request-review' THEN
          NEW.exact_step GLOB 'gh pr comment *' AND NEW.exact_step GLOB '* --repo openclaw/openclaw*'
          AND instr(' ' || NEW.exact_step || ' ', ' ' || replace(g.pr_url, rtrim(g.pr_url, '0123456789'), '') || ' ') > 0
          AND ' ' || NEW.exact_step || ' ' GLOB '* --body-file references/re-review.md *'
          AND NEW.body_sha256 = '27b98c8ea0dc9261503d813de11b061a3d4e238b14b8ffa5608d4d597d207443'
        ELSE 0 END
  )
)
BEGIN
  SELECT RAISE(ABORT, 'not covered by the open standing grant: check the action, the full head SHA and the command shape');
END;

-- At most one re-review per head, and at most 5 in all, under one grant.
CREATE TRIGGER approvals_grant_one_review_per_head BEFORE UPDATE OF decision, grant_id ON approvals
WHEN NEW.grant_id IS NOT NULL AND NEW.action = 'request-review' AND (
  EXISTS (SELECT 1 FROM approvals AS a
          WHERE a.id <> NEW.id AND a.grant_id = NEW.grant_id AND a.action = 'request-review'
            AND a.head_sha = NEW.head_sha AND a.decision = 'granted')
  OR (SELECT count(*) FROM approvals AS a
      WHERE a.id <> NEW.id AND a.grant_id = NEW.grant_id AND a.action = 'request-review'
        AND a.decision = 'granted') >= 5
)
BEGIN
  SELECT RAISE(ABORT, 'a re-review for this head was already granted under this grant, or the grant used all 5');
END;

CREATE TRIGGER approvals_grant_on_insert BEFORE INSERT ON approvals
WHEN NEW.grant_id IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'ask first, then grant under the standing grant with decide-approval');
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

PRAGMA user_version = 3;

COMMIT;

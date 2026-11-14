-- Upgrade a version 2 database (Template 0.4.0 and 0.4.1) to version 3 in place. No input.
-- Version 3 adds standing grants (the grants table and approvals.grant_id) and the evidence kind hosted-review.
-- Every row is kept. Pending requests stay pending. The evidence table is rebuilt in one transaction; on any error nothing changes.
-- Back up the file first (BOOTSTRAP.md, "Upgrade from an earlier version"). Run from the workspace root:
--   sqlite3 -bail <db_path> ".read references/sql/migrate-v2-to-v3.sql"
-- It refuses unless the database is version 2. Prints migrate ok when done.
.bail on
PRAGMA foreign_keys = OFF;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 2));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE before_rows AS SELECT
  (SELECT count(*) FROM candidates) AS candidates,
  (SELECT count(*) FROM contributions) AS contributions,
  (SELECT count(*) FROM evidence) AS evidence,
  (SELECT count(*) FROM approvals) AS approvals,
  (SELECT count(*) FROM status_events) AS status_events;

BEGIN;

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

ALTER TABLE approvals ADD COLUMN grant_id INTEGER REFERENCES grants (id) ON DELETE RESTRICT;

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

CREATE TABLE evidence_v3 (
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

INSERT INTO evidence_v3 (id, contribution_id, kind, command, exit_code, result, commit_sha, log_path, note, recorded_at)
SELECT id, contribution_id, kind, command, exit_code, result, commit_sha, log_path, note, recorded_at FROM evidence;

DROP TABLE evidence;
ALTER TABLE evidence_v3 RENAME TO evidence;

CREATE INDEX evidence_contribution ON evidence (contribution_id, recorded_at);

CREATE TEMP TABLE rows_kept (ok INTEGER CHECK (ok = 1));
INSERT INTO temp.rows_kept SELECT
  (SELECT count(*) FROM candidates) = b.candidates
  AND (SELECT count(*) FROM contributions) = b.contributions
  AND (SELECT count(*) FROM evidence) = b.evidence
  AND (SELECT count(*) FROM approvals) = b.approvals
  AND (SELECT count(*) FROM status_events) = b.status_events
FROM temp.before_rows AS b;
CREATE TEMP TABLE fk_clean (n INTEGER CHECK (n = 0));
INSERT INTO temp.fk_clean SELECT count(*) FROM pragma_foreign_key_check;

PRAGMA user_version = 3;
COMMIT;
PRAGMA foreign_keys = ON;
PRAGMA integrity_check;
SELECT 'migrate ok, schema version ' || user_version || ', approvals kept: ' || (SELECT count(*) FROM approvals)
       || ', evidence kept: ' || (SELECT count(*) FROM evidence) AS result
FROM pragma_user_version;

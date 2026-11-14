-- Upgrade a version 1 database (Template 0.1.x to 0.3.x) to version 2 in place. No input.
-- Version 2 adds approvals.body_sha256 and the approval decisions withdrawn and recorded-outside.
-- Every row is kept. A request still pending becomes withdrawn: ask it again after the upgrade. The approvals table is rebuilt in one transaction; on any error nothing changes.
-- Back up the file first (BOOTSTRAP.md, "Upgrade from 0.3.x"). Run from the workspace root:
--   sqlite3 -bail <db_path> ".read references/sql/migrate-v1-to-v2.sql"
-- It refuses unless the database is version 1. Prints migrate ok when done.
.bail on
PRAGMA foreign_keys = OFF;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE before_rows AS SELECT
  (SELECT count(*) FROM candidates) AS candidates,
  (SELECT count(*) FROM contributions) AS contributions,
  (SELECT count(*) FROM evidence) AS evidence,
  (SELECT count(*) FROM approvals) AS approvals,
  (SELECT count(*) FROM status_events) AS status_events;

BEGIN;

CREATE TABLE approvals_v2 (
  id INTEGER PRIMARY KEY,
  candidate_id INTEGER NOT NULL REFERENCES candidates (id) ON DELETE RESTRICT,
  contribution_id INTEGER REFERENCES contributions (id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN (
    'push', 'force-push', 'open-pr', 'open-issue', 'comment', 'edit-pr', 'ready-for-review',
    'request-review', 'resolve-conversation', 'rerun-ci', 'create-fork', 'close', 'reopen', 'other'
  )),
  exact_step TEXT NOT NULL CHECK (length(exact_step) BETWEEN 1 AND 4000),
  head_sha TEXT NOT NULL DEFAULT '',
  body_sha256 TEXT NOT NULL DEFAULT '' CHECK (body_sha256 = '' OR (length(body_sha256) = 64 AND body_sha256 NOT GLOB '*[^0-9a-f]*')),
  asked_at TEXT NOT NULL,
  decision TEXT NOT NULL DEFAULT 'pending' CHECK (decision IN (
    'pending', 'granted', 'denied', 'withdrawn', 'recorded-outside'
  )),
  owner_words TEXT NOT NULL DEFAULT '',
  decided_at TEXT,
  used_at TEXT,
  outcome TEXT NOT NULL DEFAULT '',
  CHECK (used_at IS NULL OR decision = 'granted')
);

INSERT INTO approvals_v2 (id, candidate_id, contribution_id, action, exact_step, head_sha,
                          asked_at, decision, owner_words, decided_at, used_at, outcome)
SELECT id, candidate_id, contribution_id, action, exact_step, head_sha, asked_at,
       CASE decision WHEN 'pending' THEN 'withdrawn' ELSE decision END,
       CASE decision WHEN 'pending' THEN 'withdrawn by the version 2 upgrade, before any answer: ask again'
            ELSE owner_words END,
       CASE decision WHEN 'pending' THEN strftime('%Y-%m-%dT%H:%M:%SZ', 'now') ELSE decided_at END,
       used_at, outcome
FROM approvals;

DROP TABLE approvals;
ALTER TABLE approvals_v2 RENAME TO approvals;

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

PRAGMA user_version = 2;
COMMIT;
PRAGMA foreign_keys = ON;
PRAGMA integrity_check;
SELECT 'migrate ok, schema version ' || user_version || ', approvals kept: ' || (SELECT count(*) FROM approvals) AS result
FROM pragma_user_version;

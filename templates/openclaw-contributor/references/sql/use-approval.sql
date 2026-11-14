-- Run right before the outward step. Fails unless the approval is granted, unused, for the same action and the same exact command, bound to the current head, and, when a body hash was approved, bound to the same body. Input: approval_id, action, exact_step (the command you are about to run), head_sha (current), body_sha256 (current hash of the body file, when there is one), now.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/use-approval.sql"
-- Input: write db-input.json with the write tool first, with "step": "use-approval".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 2));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'use-approval'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- Every approval is bound to what the owner saw: the exact command, the body hash when there
-- was a body, and the head. Head-bound actions need a stored SHA equal to the current head.
-- The only steps that carry no head are open-issue, create-fork, and steps with no
-- contribution; they stay bound by the exact command and, when they have a body, its hash.
-- A body-file step asked before version 2 has no hash and never matches: ask again.
CREATE TEMP TABLE use_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.use_guard SELECT count(*) FROM approvals AS a, temp.input AS i
WHERE a.id = json_extract(i.j, '$.approval_id')
  AND a.action = json_extract(i.j, '$.action')
  AND a.exact_step = coalesce(json_extract(i.j, '$.exact_step'), '')
  AND a.decision = 'granted'
  AND a.used_at IS NULL
  AND a.body_sha256 = coalesce(json_extract(i.j, '$.body_sha256'), '')
  AND (a.exact_step NOT GLOB '*--body-file*' OR a.body_sha256 <> '')
  AND CASE WHEN a.action IN ('push', 'force-push', 'open-pr', 'edit-pr', 'ready-for-review')
             OR (a.contribution_id IS NOT NULL AND a.action NOT IN ('open-issue', 'create-fork'))
           THEN a.head_sha <> '' AND a.head_sha = coalesce(json_extract(i.j, '$.head_sha'), '')
           ELSE a.head_sha = coalesce(json_extract(i.j, '$.head_sha'), '')
      END;

UPDATE approvals SET used_at = (SELECT json_extract(j, '$.now') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input)
RETURNING id AS approval_id, action, exact_step, used_at;

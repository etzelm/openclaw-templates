-- Write ahead before asking the owner for one outward step. Input: candidate_id, contribution_id (or null), action, exact_step, head_sha, now. head_sha (the commit SHA, 7 to 64 lowercase hex characters, never a branch name or HEAD) is required for push, force-push, open-pr, edit-pr and ready-for-review, and for any other action with a contribution_id except open-issue and create-fork. Returns the approval id to name in the request.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/ask-approval.sql"
-- Input: write db-input.json with the write tool first, with "step": "ask-approval".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'ask-approval'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

-- Head-bound steps must name the head SHA the owner is approving: the five PR-head actions,
-- and every action tied to a contribution except open-issue and create-fork.
CREATE TEMP TABLE head_guard (ok INTEGER CHECK (ok = 1));
INSERT INTO temp.head_guard SELECT
  CASE WHEN json_extract(j, '$.action') IN ('push', 'force-push', 'open-pr', 'edit-pr', 'ready-for-review')
         OR (json_extract(j, '$.contribution_id') IS NOT NULL
             AND json_extract(j, '$.action') NOT IN ('open-issue', 'create-fork'))
       THEN coalesce(length(json_extract(j, '$.head_sha')), 0) BETWEEN 7 AND 64
            AND json_extract(j, '$.head_sha') NOT GLOB '*[^0-9a-f]*'
       ELSE 1 END
FROM temp.input;

INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at)
SELECT json_extract(j, '$.candidate_id'), json_extract(j, '$.contribution_id'),
       json_extract(j, '$.action'), json_extract(j, '$.exact_step'),
       coalesce(json_extract(j, '$.head_sha'), ''), json_extract(j, '$.now')
FROM temp.input
RETURNING id AS approval_id, action, head_sha, decision;

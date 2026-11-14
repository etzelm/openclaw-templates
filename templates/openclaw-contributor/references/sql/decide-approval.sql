-- Close one pending approval request. Input: approval_id, decision, owner_words, now, and grant_id only when granting under a standing grant.
-- decision: granted or denied (the owner's answer, quoted in owner_words, with where and when they said it if it was relayed);
-- withdrawn (you close it before any answer: the step changed or is no longer needed; owner_words says why);
-- recorded-outside (the owner did the step outside this agent; owner_words says who did it and on whose word).
-- grant_id: granted under that standing grant, not a fresh answer. The grant must be open, for this contribution,
-- and list the action; a request-review is granted at most once per head under one grant. owner_words then names the grant.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/decide-approval.sql"
-- Input: write db-input.json with the write tool first, with "step": "decide-approval".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'decide-approval'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE decision_guard (ok INTEGER CHECK (ok = 1));
INSERT INTO temp.decision_guard SELECT
  json_extract(j, '$.decision') IN ('granted', 'denied', 'withdrawn', 'recorded-outside')
  AND length(trim(coalesce(json_extract(j, '$.owner_words'), ''))) > 0
FROM temp.input;

CREATE TEMP TABLE pending_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.pending_guard SELECT count(*) FROM approvals
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input) AND decision = 'pending';

UPDATE approvals SET
  grant_id = (SELECT json_extract(j, '$.grant_id') FROM temp.input),
  decision = (SELECT json_extract(j, '$.decision') FROM temp.input),
  owner_words = (SELECT coalesce(json_extract(j, '$.owner_words'), '') FROM temp.input),
  decided_at = (SELECT json_extract(j, '$.now') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input)
RETURNING id AS approval_id, action, decision, grant_id;

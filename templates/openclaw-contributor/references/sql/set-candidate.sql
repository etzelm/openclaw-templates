-- Record the decision on a candidate after the duplicate and decision check or the owner's answer. Input: candidate_id, decision, reason, related (JSON array), now, and optional url and number (set them once the GitHub issue exists).
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/set-candidate.sql"
-- Input: write db-input.json with the write tool first, with "step": "set-candidate".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'set-candidate'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

UPDATE candidates SET
  decision = (SELECT json_extract(j, '$.decision') FROM temp.input),
  reason = (SELECT coalesce(json_extract(j, '$.reason'), '') FROM temp.input),
  related = (SELECT coalesce(json(json_extract(j, '$.related')), related) FROM temp.input),
  url = (SELECT coalesce(json_extract(j, '$.url'), url) FROM temp.input),
  number = (SELECT coalesce(json_extract(j, '$.number'), number) FROM temp.input),
  updated_at = (SELECT json_extract(j, '$.now') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.candidate_id') FROM temp.input)
RETURNING id AS candidate_id, url, number, decision, reason;

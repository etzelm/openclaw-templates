-- Change a contribution's status and, when given, its head SHA, base SHA or PR url. Input: contribution_id, status, note, now, and optional head_sha, base_sha, pr_url.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/set-status.sql"
-- Input: write db-input.json with the write tool first, with "step": "set-status".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'set-status'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

UPDATE contributions SET
  status = (SELECT json_extract(j, '$.status') FROM temp.input),
  note = (SELECT coalesce(json_extract(j, '$.note'), '') FROM temp.input),
  head_sha = (SELECT coalesce(json_extract(j, '$.head_sha'), head_sha) FROM temp.input),
  base_sha = (SELECT coalesce(json_extract(j, '$.base_sha'), base_sha) FROM temp.input),
  pr_url = (SELECT coalesce(json_extract(j, '$.pr_url'), pr_url) FROM temp.input),
  updated_at = (SELECT json_extract(j, '$.now') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.contribution_id') FROM temp.input)
RETURNING id AS contribution_id, status, head_sha, pr_url, note;

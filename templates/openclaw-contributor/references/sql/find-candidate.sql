-- Look up a candidate by url, or by repo and number, with its contributions. Input: url, or repo and number.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/find-candidate.sql"
-- Input: write db-input.json with the write tool first, with "step": "find-candidate".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'find-candidate'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

SELECT c.id AS candidate_id, c.url, c.title, c.decision, c.reason, c.related,
       k.id AS contribution_id, k.slug, k.branch, k.status, k.head_sha, k.pr_url
FROM candidates AS c
LEFT JOIN contributions AS k ON k.candidate_id = c.id
WHERE c.url = (SELECT json_extract(j, '$.url') FROM temp.input)
   OR (c.repo = (SELECT json_extract(j, '$.repo') FROM temp.input)
       AND c.number = (SELECT json_extract(j, '$.number') FROM temp.input))
ORDER BY k.id;

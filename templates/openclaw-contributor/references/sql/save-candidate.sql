-- Save an issue, bug or idea the agent looked at. Input: repo, number (or null), url, title, area, now. Returns the row and any earlier decision.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/save-candidate.sql"
-- Input: write db-input.json with the write tool first, with "step": "save-candidate".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'save-candidate'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

INSERT INTO candidates (repo, number, url, title, area, first_seen, updated_at)
SELECT json_extract(j, '$.repo'), json_extract(j, '$.number'), json_extract(j, '$.url'),
       json_extract(j, '$.title'), coalesce(json_extract(j, '$.area'), ''),
       json_extract(j, '$.now'), json_extract(j, '$.now')
FROM temp.input WHERE true
ON CONFLICT (url) DO UPDATE SET title = excluded.title, updated_at = excluded.updated_at
RETURNING id AS candidate_id, url, decision, reason, related;

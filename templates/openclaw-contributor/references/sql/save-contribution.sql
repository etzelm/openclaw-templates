-- Start a contribution for an approved candidate. Input: candidate_id, slug, branch, base_sha, evidence_dir, now. Status starts at scope-approved.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/save-contribution.sql"
-- Input: write db-input.json with the write tool first, with "step": "save-contribution".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 2));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'save-contribution'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE approved_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.approved_guard SELECT count(*) FROM candidates
WHERE id = (SELECT json_extract(j, '$.candidate_id') FROM temp.input) AND decision = 'approved';

INSERT INTO contributions (candidate_id, slug, branch, base_sha, status, evidence_dir, created_at, updated_at, note)
SELECT json_extract(j, '$.candidate_id'), json_extract(j, '$.slug'), json_extract(j, '$.branch'),
       coalesce(json_extract(j, '$.base_sha'), ''), 'scope-approved',
       coalesce(json_extract(j, '$.evidence_dir'), ''),
       json_extract(j, '$.now'), json_extract(j, '$.now'), 'scope approved by owner'
FROM temp.input
RETURNING id AS contribution_id, slug, branch, status;

-- Record the owner's standing grant for one open PR, once. Input: contribution_id, actions (JSON array, a subset of push, edit-pr, request-review), scope, stop_conditions, owner_words, now.
-- scope and stop_conditions are the text the owner was shown. owner_words quotes the owner, with where and when if relayed.
-- Refuses unless the contribution has a PR url and no other open grant. Returns the grant id.
-- Each use is still its own approval: ask-approval, then decide-approval with grant_id (see contribution-loop.md, step 12).
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/record-grant.sql"
-- Input: write db-input.json with the write tool first, with "step": "record-grant".
-- Issue, PR and page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 3));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'record-grant'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE pr_guard (n INTEGER CHECK (n = 1));
INSERT INTO temp.pr_guard SELECT count(*) FROM contributions
WHERE id = (SELECT json_extract(j, '$.contribution_id') FROM temp.input) AND pr_url <> '';

INSERT INTO grants (contribution_id, pr_url, actions, scope, stop_conditions, owner_words, granted_at)
SELECT k.id, k.pr_url, json(json_extract(i.j, '$.actions')), json_extract(i.j, '$.scope'),
       json_extract(i.j, '$.stop_conditions'), coalesce(json_extract(i.j, '$.owner_words'), ''),
       json_extract(i.j, '$.now')
FROM temp.input AS i JOIN contributions AS k ON k.id = json_extract(i.j, '$.contribution_id')
RETURNING id AS grant_id, contribution_id, pr_url, actions;

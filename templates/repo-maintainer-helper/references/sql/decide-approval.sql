-- Record the owner's answer to one request. Input: approval_id, decision (granted, refused or withdrawn), owner_words (the owner's own words; required for granted and refused).
-- Only the owner grants or refuses. Withdraw a request yourself when the item changed or the owner moved on; never record that as a refusal.
-- A grant is refused when the item changed on GitHub after the request: withdraw it and ask again.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/decide-approval.sql"
-- Input: write db-input.json with the write tool first, with "step": "decide-approval".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'decide-approval'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE a AS
SELECT a.*, it.updated_at, it.state FROM approvals AS a JOIN items AS it ON it.id = a.item_id
WHERE a.id = (SELECT json_extract(j, '$.approval_id') FROM temp.input);
CREATE TEMP TABLE g1 (ok INTEGER CONSTRAINT request_unknown_or_already_decided CHECK (ok = 1));
INSERT INTO temp.g1 SELECT count(*) = 1 AND min(decision = 'pending') FROM temp.a;
CREATE TEMP TABLE g2 (ok INTEGER CONSTRAINT item_changed_since_the_request CHECK (ok = 1));
INSERT INTO temp.g2 SELECT json_extract(i.j, '$.decision') <> 'granted' OR (a.updated_at = a.seen_updated_at AND a.state = a.seen_state)
FROM temp.input AS i, temp.a AS a;

UPDATE approvals SET
  decision = (SELECT json_extract(j, '$.decision') FROM temp.input),
  owner_words = coalesce((SELECT json_extract(j, '$.owner_words') FROM temp.input), ''),
  decided_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
WHERE id = (SELECT json_extract(j, '$.approval_id') FROM temp.input)
RETURNING id AS approval_id, action, exact_step, decision, decided_at;

-- Record the triage of one item. Input: run_id, item_id, item_updated_at (the updated_at to-triage showed), category, labels (suggested, from the repo's list),
-- duplicate_of (number, for category duplicate), reason (one or two plain sentences), suggested_action (none, add-labels, comment, close).
-- Refuses when the item changed since to-triage showed it: read it again. The item leaves the queue until it changes on GitHub.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/save-triage.sql"
-- Input: write db-input.json with the write tool first, with "step": "save-triage".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'save-triage'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE fresh_guard (n INTEGER CONSTRAINT item_changed_since_to_triage CHECK (n = 1));
INSERT INTO temp.fresh_guard SELECT count(*) FROM items
WHERE id = (SELECT json_extract(j, '$.item_id') FROM temp.input)
  AND updated_at = (SELECT json_extract(j, '$.item_updated_at') FROM temp.input);

BEGIN;
INSERT INTO triage (item_id, run_id, item_updated_at, category, labels, duplicate_of, reason, suggested_action, created_at)
SELECT json_extract(j, '$.item_id'), json_extract(j, '$.run_id'), json_extract(j, '$.item_updated_at'),
       json_extract(j, '$.category'), json(coalesce(json_extract(j, '$.labels'), '[]')),
       json_extract(j, '$.duplicate_of'), json_extract(j, '$.reason'),
       coalesce(json_extract(j, '$.suggested_action'), 'none'), strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
FROM temp.input;
UPDATE items SET triaged_updated_at = (SELECT json_extract(j, '$.item_updated_at') FROM temp.input)
WHERE id = (SELECT json_extract(j, '$.item_id') FROM temp.input);
COMMIT;

SELECT t.id AS triage_id, t.item_id, i.repo, i.number, t.category, t.labels, t.duplicate_of, t.suggested_action
FROM triage AS t JOIN items AS i ON i.id = t.item_id WHERE t.id = last_insert_rowid();

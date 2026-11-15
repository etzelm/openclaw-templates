-- The digest data for one run, as one JSON object: reads (with gaps), triaged items, items still waiting, and open requests.
-- Input: run_id. Read only. Write the digest from this result and templates/digest.md; never from memory.
-- Run from the workspace root:
--   sqlite3 -bail <db_path> ".read references/sql/digest.sql"
-- No -json flag here: the step prints one JSON object as it is.
-- Input: write db-input.json with the write tool first, with "step": "digest".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'digest'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE run_guard (n INTEGER CONSTRAINT unknown_run CHECK (n = 1));
INSERT INTO temp.run_guard SELECT count(*) FROM runs WHERE id = (SELECT json_extract(j, '$.run_id') FROM temp.input);

SELECT json_object(
  'run', (SELECT json_object('run_id', id, 'kind', kind, 'started_at', started_at, 'ended_at', ended_at, 'note', note)
          FROM runs WHERE id = (SELECT json_extract(j, '$.run_id') FROM temp.input)),
  'reads', (SELECT json_group_array(json_object('repo', repo, 'kind', kind, 'read_count', read_count,
                   'new_items', new_items, 'queued', queued, 'limit_reached', limit_reached, 'fetched_at', fetched_at))
            FROM reads WHERE run_id = (SELECT json_extract(j, '$.run_id') FROM temp.input)),
  'triaged', (SELECT json_group_array(json_object('repo', i.repo, 'kind', i.kind, 'number', i.number, 'title', i.title,
                     'url', i.url, 'category', t.category, 'labels', json(t.labels), 'duplicate_of', t.duplicate_of,
                     'reason', t.reason, 'suggested_action', t.suggested_action))
              FROM (SELECT * FROM triage WHERE run_id = (SELECT json_extract(j, '$.run_id') FROM temp.input) ORDER BY id) AS t
              JOIN items AS i ON i.id = t.item_id),
  'still_waiting', (SELECT count(*) FROM items WHERE state = 'OPEN' AND updated_at > triaged_updated_at),
  'open_requests', (SELECT json_group_array(json_object('approval_id', a.id, 'repo', i.repo, 'number', i.number,
                           'action', a.action, 'exact_step', a.exact_step, 'decision', a.decision, 'asked_at', a.asked_at,
                           'item_changed', i.updated_at <> a.seen_updated_at OR i.state <> a.seen_state))
                    FROM (SELECT * FROM approvals WHERE decision = 'pending' OR (decision = 'granted' AND used_at IS NULL) ORDER BY id) AS a
                    JOIN items AS i ON i.id = a.item_id)
);

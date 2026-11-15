-- Possible duplicates for one item, from the title index of the same repository. Input: item_id, words (1 to 8 key words you picked from its title).
-- Each word is quoted, so no word can change the search syntax. Returns up to 8 matches, best first.
-- Run from the workspace root:
--   sqlite3 -bail -json <db_path> ".read references/sql/similar.sql"
-- Input: write db-input.json with the write tool first, with "step": "similar".
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CONSTRAINT wrong_schema_version CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CONSTRAINT db_input_not_json CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CONSTRAINT db_input_for_another_step CHECK (s = 'similar'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE w (word TEXT NOT NULL CONSTRAINT w CHECK (length(word) BETWEEN 1 AND 40));
INSERT INTO temp.w SELECT e.value FROM temp.input AS i, json_each(i.j, '$.words') AS e;
CREATE TEMP TABLE words_guard (n INTEGER CONSTRAINT words_not_1_to_8 CHECK (n BETWEEN 1 AND 8));
INSERT INTO temp.words_guard SELECT count(*) FROM temp.w;
CREATE TEMP TABLE item (id INTEGER NOT NULL, repo TEXT NOT NULL, number INTEGER NOT NULL);
INSERT INTO temp.item SELECT id, repo, number FROM items WHERE id = (SELECT json_extract(j, '$.item_id') FROM temp.input);
CREATE TEMP TABLE item_guard (n INTEGER CONSTRAINT unknown_item CHECK (n = 1));
INSERT INTO temp.item_guard SELECT count(*) FROM temp.item;

SELECT t.number, t.kind, t.state, t.title, round(bm25(title_index), 3) AS rank
FROM title_index AS t
WHERE title_index MATCH (SELECT group_concat('"' || replace(word, '"', '""') || '"', ' OR ') FROM temp.w)
  AND t.repo = (SELECT repo FROM temp.item)
  AND t.number <> (SELECT number FROM temp.item)
ORDER BY bm25(title_index)
LIMIT 8;

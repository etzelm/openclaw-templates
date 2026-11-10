-- Dedup lookup before a posting. Input: company, title, link (optional). Returns rows with the same link, the same normalized company and title, or the same company (check those titles for a similar role).
-- Run from the workspace root:
--   sqlite3 -bail -json applications.db ".read references/sql/find-posting.sql"
-- Input: write db-input.json with the write tool first, with "step": "find-posting".
-- Page text goes only into db-input.json, never into the command line.
.bail on
PRAGMA foreign_keys = ON;
CREATE TEMP TABLE schema_guard (v INTEGER CHECK (v = 1));
INSERT INTO temp.schema_guard SELECT user_version FROM pragma_user_version;
CREATE TEMP TABLE input (j TEXT NOT NULL CHECK (json_valid(j)));
INSERT INTO temp.input VALUES (CAST(readfile('db-input.json') AS TEXT));
CREATE TEMP TABLE step_guard (s TEXT CHECK (s = 'find-posting'));
INSERT INTO temp.step_guard SELECT json_extract(j, '$.step') FROM temp.input;

CREATE TEMP TABLE probe (
  company TEXT NOT NULL,
  title TEXT NOT NULL,
  link TEXT NOT NULL,
  company_key TEXT GENERATED ALWAYS AS (
    trim(replace(replace(replace(
      replace(replace(replace(replace(replace(replace(replace(lower(company),
        ',', ' '), '.', ' '), '-', ' '), '/', ' '), '(', ' '), ')', ' '), '&', ' '),
      '  ', ' '), '  ', ' '), '  ', ' '))
  ) STORED,
  dedup_key TEXT GENERATED ALWAYS AS (
    trim(replace(replace(replace(
      replace(replace(replace(replace(replace(replace(replace(lower(company),
        ',', ' '), '.', ' '), '-', ' '), '/', ' '), '(', ' '), ')', ' '), '&', ' '),
      '  ', ' '), '  ', ' '), '  ', ' '))
    || '|' ||
    trim(replace(replace(replace(
      replace(replace(replace(replace(replace(replace(replace(lower(title),
        ',', ' '), '.', ' '), '-', ' '), '/', ' '), '(', ' '), ')', ' '), '&', ' '),
      '  ', ' '), '  ', ' '), '  ', ' '))
  ) STORED
);
INSERT INTO temp.probe (company, title, link)
SELECT json_extract(j, '$.company'), json_extract(j, '$.title'), coalesce(json_extract(j, '$.link'), '') FROM temp.input;

SELECT
  p.id AS posting_id,
  p.company,
  p.title,
  p.link,
  CASE
    WHEN p.link = q.link THEN 'same-link'
    WHEN p.dedup_key = q.dedup_key THEN 'same-title'
    ELSE 'same-company'
  END AS match,
  a.id AS application_id,
  a.status,
  a.attempts,
  a.auto_retries,
  a.day,
  a.note
FROM postings AS p
JOIN temp.probe AS q
  ON p.link = q.link OR p.dedup_key = q.dedup_key OR p.company_key = q.company_key
LEFT JOIN applications AS a ON a.posting_id = p.id
ORDER BY match, p.id;

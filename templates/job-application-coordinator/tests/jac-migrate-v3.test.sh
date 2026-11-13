#!/bin/zsh
# A 0.2.0 (schema 2) database upgrades to schema 3 with the packaged step,
# keeps its rows, marks rows that clearly passed a fit check as fit, passes
# setup-check, refuses to run twice, and matches a fresh v3 database.
# Usage: jac-migrate-v3.test.sh <new package dir> <0.2.0 package dir>
OLD="${2:?old package dir}"; OLD="${OLD:A}"
source "${0:A:h}/lib.sh" "$1"
DB="$SCRATCH/data/applications.db"
mkdir -p "$SCRATCH/old" && cp -R "$OLD/references" "$SCRATCH/old/"
oldstep() { ( cd "$SCRATCH/old" && printf '%s' "$2" > db-input.json && sqlite3 -bail -json "$DB" ".read references/sql/$1.sql" >/dev/null ); }
( cd "$SCRATCH/old" && sqlite3 -bail "$DB" ".read references/schema.sql" ) || { echo "FAIL building v2 database"; exit 1; }
for n in 1 2 3 4; do
  oldstep save-posting '{"step":"save-posting","company":"Old Co '$n'","title":"Engineer","link":"https://jobs.example.com/old'$n'","source":"https://jobs.example.com/s","first_seen":"2026-11-01T09:00:00Z","job_description":"d","fit_reason":"r"}' || { echo "FAIL v2 posting"; exit 1; }
done
oldstep save-application '{"step":"save-application","posting_id":1,"status":"applied","note":"submitted by agent","now":"2026-11-01T10:00:00Z","day":"2026-11-01","new_attempt":1,"auto_retry":0}'
oldstep save-application '{"step":"save-application","posting_id":2,"status":"skipped","note":"no fit","now":"2026-11-01T10:00:00Z","day":"2026-11-01","new_attempt":0,"auto_retry":0}'
oldstep save-application '{"step":"save-application","posting_id":3,"status":"prospect","note":"","now":"2026-11-01T10:00:00Z","day":"2026-11-01","new_attempt":0,"auto_retry":0}'
oldstep save-application '{"step":"save-application","posting_id":4,"status":"dry-run","note":"","now":"2026-11-01T10:00:00Z","day":"2026-11-01","new_attempt":1,"auto_retry":0}'
RC=0; OUT="$(sqlite3 "$DB" 'PRAGMA user_version;')"; expect_has "old database is version 2" "2"

step "$DB" cap-count '{"step":"cap-count","day":"2026-11-01"}'
expect_fail "new steps refuse a version 2 database"

OUT="$(sqlite3 -bail "$DB" ".read references/sql/migrate-v2-to-v3.sql" 2>&1)"; RC=$?
expect_has "migrate prints ok" "migrate ok, schema version 3"
OUT="$(sqlite3 -bail "$DB" ".read references/sql/migrate-v2-to-v3.sql" 2>&1)"; RC=$?
expect_fail "migrate refuses to run twice"
OUT="$(sqlite3 -bail "$DB" ".read references/sql/migrate-v1-to-v2.sql" 2>&1)"; RC=$?
expect_fail "v1-to-v2 migrate refuses a version 3 database"
OUT="$(sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" 2>&1)"; RC=$?
expect_has "setup-check on migrated db" "setup-check ok, schema version 3"
OUT="$(sqlite3 "$DB" "SELECT group_concat(id || ':' || stage || ':' || coalesce(score, 'null'), ',') FROM (SELECT * FROM postings ORDER BY id);")"; RC=0
expect_has "stages inferred from history, scores empty" "1:fit:null,2::null,3:fit:null,4:fit:null"
step "$DB" cap-count '{"step":"cap-count","day":"2026-11-01"}'
expect_has "old rows keep their cap count" '"cap_count":2'
step "$DB" ranked-queue '{"step":"ranked-queue","since_day":"2026-11-01","today":"2026-11-02"}'
expect_has "old prospect is in the ranked queue" "Old Co 3"
OUT="$(sqlite3 -bail "$DB" ".read references/sql/tracker.sql" 2>&1)"; RC=$?
expect_has "tracker on migrated db" "tracker.md regenerated: 4 rows"

FRESH="$SCRATCH/data/fresh.db"
sqlite3 -bail "$FRESH" ".read references/schema.sql"
cols() { sqlite3 "$1" "SELECT group_concat(t.name || '.' || c.name || ':' || c.type || ':' || c.\"notnull\" || ':' || coalesce(c.dflt_value,''), ',') FROM sqlite_master AS t, pragma_table_xinfo(t.name) AS c WHERE t.type = 'table' ORDER BY t.name;"; }
objs() { sqlite3 "$1" "SELECT group_concat(type || ':' || name, ',') FROM (SELECT type, name FROM sqlite_master ORDER BY type, name);"; }
trg() { sqlite3 "$1" "SELECT group_concat(name || '=' || replace(replace(sql, char(10), ' '), '  ', ' '), ';') FROM (SELECT name, sql FROM sqlite_master WHERE type IN ('trigger','index') AND sql IS NOT NULL ORDER BY name);"; }
RC=0
[[ "$(cols "$DB")" == "$(cols "$FRESH")" ]] && ok "columns match fresh v3" || { OUT="$(cols "$DB") vs $(cols "$FRESH")"; bad "columns"; }
[[ "$(objs "$DB")" == "$(objs "$FRESH")" ]] && ok "tables, indexes and triggers match fresh v3" || { OUT="$(objs "$DB") vs $(objs "$FRESH")"; bad "objects"; }
[[ "$(trg "$DB")" == "$(trg "$FRESH")" ]] && ok "trigger and index SQL match fresh v3" || { OUT="differ"; bad "triggers"; }
finish

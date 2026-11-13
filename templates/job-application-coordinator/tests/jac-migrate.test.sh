#!/bin/zsh
# J14: a 0.1.x (schema 1) applications.db upgrades to schema 2 with the
# packaged migrate step, keeps its rows, passes setup-check, and the
# migrate step refuses to run twice.
# Usage: jac-migrate.test.sh <new package dir> <old 0.1.x package dir>
OLD="${2:?old package dir}"; OLD="${OLD:A}"
source "${0:A:h}/lib.sh" "$1"
DB="$SCRATCH/data/applications.db"
mkdir -p "$SCRATCH/old" && cp -R "$OLD/references" "$SCRATCH/old/"
( cd "$SCRATCH/old" && sqlite3 -bail "$DB" ".read references/schema.sql" \
  && printf '%s' '{"step":"save-posting","company":"Old Co","title":"Engineer","link":"https://jobs.example.com/old","first_seen":"2026-11-01T09:00:00Z"}' > db-input.json \
  && sqlite3 -bail -json "$DB" ".read references/sql/save-posting.sql" >/dev/null \
  && printf '%s' '{"step":"save-application","posting_id":1,"status":"applied","note":"","now":"2026-11-01T10:00:00Z","day":"2026-11-01","new_attempt":1,"auto_retry":0}' > db-input.json \
  && sqlite3 -bail -json "$DB" ".read references/sql/save-application.sql" >/dev/null ) \
  || { echo "FAIL building v1 database"; exit 1; }
RC=0; OUT="$(sqlite3 "$DB" 'PRAGMA user_version;')"; expect_has "old database is version 1" "1"

step "$DB" cap-count '{"step":"cap-count","day":"2026-11-01"}'
expect_fail "new steps refuse a version 1 database"

OUT="$(sqlite3 -bail "$DB" ".read references/sql/migrate-v1-to-v2.sql" 2>&1)"; RC=$?
expect_has "migrate prints ok" "migrate ok, schema version 2"
OUT="$(sqlite3 -bail "$DB" ".read references/sql/migrate-v1-to-v2.sql" 2>&1)"; RC=$?
expect_fail "migrate refuses to run twice"
OUT="$(sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" 2>&1)"; RC=$?
expect_has "setup-check on migrated db" "setup-check ok, schema version 2"
step "$DB" cap-count '{"step":"cap-count","day":"2026-11-01"}'
expect_has "old row keeps its day in the cap" '"cap_count":1'
step "$DB" set-status '{"step":"set-status","application_id":1,"status":"closed","note":"","now":"2026-11-02T10:00:00Z"}'
step "$DB" cap-count '{"step":"cap-count","day":"2026-11-01"}'
expect_has "closing the old row keeps the count" '"cap_count":1'
step "$DB" find-posting '{"step":"find-posting","company":"Old Co","title":"Engineer","link":"https://jobs.example.com/old"}'
expect_has "old posting still found" "Old Co"

# A fresh v2 database and a migrated one have the same columns and triggers.
FRESH="$SCRATCH/data/fresh.db"
sqlite3 -bail "$FRESH" ".read references/schema.sql"
cols() { sqlite3 "$1" "SELECT group_concat(name || ':' || type || ':' || \"notnull\" || ':' || coalesce(dflt_value,''), ',') FROM pragma_table_info('status_events');"; }
trg() { sqlite3 "$1" "SELECT group_concat(name || '=' || replace(replace(sql, char(10), ' '), '  ', ' '), ';') FROM (SELECT name, sql FROM sqlite_master WHERE type IN ('trigger','index') AND sql IS NOT NULL ORDER BY name);"; }
RC=0; [[ "$(cols "$DB")" == "$(cols "$FRESH")" ]] && ok "status_events columns match fresh v2" || { OUT="$(cols "$DB") vs $(cols "$FRESH")"; bad "columns"; }
[[ "$(trg "$DB")" == "$(trg "$FRESH")" ]] && ok "triggers and indexes match fresh v2" || { OUT="differ"; bad "triggers"; }
finish

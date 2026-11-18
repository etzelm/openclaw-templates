#!/bin/zsh
# 0.4.5: per-task DB input files.
# Red on 0.4.4 (every step reads the shared db-input.json and ignores @db_input), green on 0.4.5.
# Usage: occ-db-input-045.test.sh <package dir>
source "${0:A:h}/lib.sh" "$1"
N='"now":"2026-11-17T18:00:00Z"'
DB="$SCRATCH/data/t.db"
sqlite3 -bail "$DB" ".read references/schema.sql" >/dev/null 2>&1 || { echo "FAIL schema"; exit 1; }
mk() { printf '{"step":"save-candidate","repo":"openclaw/openclaw","number":%s,"url":"https://github.com/openclaw/openclaw/issues/%s","title":"%s","area":"x",%s}' "$1" "$1" "$2" "$N"; }

# (a) two tasks, two files, each step reads only its own
step_in "$DB" save-candidate db-input/a.json "$(mk 101 task-a)"
expect_has "a reads its own file" "issues/101"
step_in "$DB" save-candidate db-input/b.json "$(mk 202 task-b)"
expect_has "b reads its own file" "issues/202"
[[ "$OUT" != *"issues/101"* ]] && ok "b output has no a row" || bad "b output has no a row"

# (b) a stale root db-input.json is ignored when the parameter is set
printf '%s' "$(mk 999 stale)" > db-input.json
step_in "$DB" save-candidate db-input/a.json "$(mk 101 task-a)"
expect_has "param wins over root file" "issues/101"
[[ "$(sqlite3 "$DB" "SELECT count(*) FROM candidates WHERE number=999")" == "0" ]] && ok "stale root file not used" || bad "stale root file not used"

# (c) old form without the parameter still reads db-input.json
step "$DB" save-candidate "$(mk 303 old-form)"
expect_has "old form reads db-input.json" "issues/303"

# (d) a missing per-task file fails, with no fallback to db-input.json
printf '%s' "$(mk 404 fallback)" > db-input.json
OUT="$(sqlite3 -bail -json "$DB" ".parameter set @db_input db-input/missing.json" ".read references/sql/save-candidate.sql" 2>&1)"; RC=$?
expect_fail "missing per-task file fails"
[[ "$(sqlite3 "$DB" "SELECT count(*) FROM candidates WHERE number=404")" == "0" ]] && ok "no silent fallback" || bad "no silent fallback"

# (e) every step that reads input uses the coalesce form
n=0
for f in references/sql/*.sql; do
  grep -q "readfile(" "$f" || continue
  n=$((n + 1))
  if grep -qF "readfile('db-input.json')" "$f" || ! grep -qF "readfile(coalesce(@db_input, 'db-input.json'))" "$f"; then RC=1; OUT="$f"; bad "coalesce form in $f"; fi
done
RC=0; [[ $n -ge 12 ]] && ok "checked $n step files" || { RC=1; OUT="only $n"; bad "step file count"; }
for f in references/sql/*.sql; do grep -q "readfile(" "$f" || continue; grep -qF '".parameter set @db_input db-input/<slug>.json" ".read references/sql/' "$f" || { RC=1; OUT="$f"; bad "header form in $f"; }; done

# (f) the loop doc names the per-task file and the .parameter form
L="references/contribution-loop.md"
RC=0; OUT=""
grep -qF 'db-input/<slug>.json' "$L" && ok "doc names db-input/<slug>.json" || bad "doc names db-input/<slug>.json"
grep -qF '".parameter set @db_input db-input/<slug>.json" ".read references/sql/<step>.sql"' "$L" && ok "doc has .parameter form" || bad "doc has .parameter form"
grep -qF 'db-input/pick-<session>.json' "$L" && ok "doc has pick file" || bad "doc has pick file"
finish

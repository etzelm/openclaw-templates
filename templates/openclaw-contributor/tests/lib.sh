#!/bin/zsh
# Shared helpers for the packaged SQL step tests.
# Each test copies the package into a scratch dir, keeps the database
# outside that dir (as db_path does), and asserts on sqlite3 output.
set -u
PKG="${1:?package dir}"
PKG="${PKG:A}"
mkdir -p "${0:A:h}/../tmp"
SCRATCH="$(mktemp -d "${0:A:h}/../tmp/tplsql.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/ws" "$SCRATCH/data"
cp -R "$PKG/references" "$SCRATCH/ws/"
cd "$SCRATCH/ws" || exit 1
FAILS=0
PASSES=0
# step <db> <sql-step> <json>  -> prints sqlite3 -json output, sets RC
step() {
  printf '%s' "$3" > db-input.json
  OUT="$(sqlite3 -bail -json "$1" ".read references/sql/$2.sql" 2>&1)"
  RC=$?
}
ok() { PASSES=$((PASSES + 1)); echo "PASS $1"; }
bad() { FAILS=$((FAILS + 1)); echo "FAIL $1 :: rc=$RC out=$OUT"; }
expect_rc0() { [[ $RC -eq 0 ]] && ok "$1" || bad "$1"; }
expect_fail() { [[ $RC -ne 0 ]] && ok "$1" || bad "$1"; }
expect_has() { [[ $RC -eq 0 && "$OUT" == *"$2"* ]] && ok "$1" || bad "$1 (want $2)"; }
finish() { echo "passed=$PASSES failed=$FAILS"; [[ $FAILS -eq 0 ]]; }

#!/bin/zsh
# Release gates for the Job Application Coordinator Template. Run on a build host.
# Usage: gates.sh <package dir> <out dir> [0.2.0 package dir] [0.1.2 package dir]
#   The two older package dirs feed the migration tests; get them from the repo tags.
# Env:
#   OCJS      openclaw.mjs of an OpenClaw main build (required)
#   CHJS      the clawhub CLI entry file, 0.26.0 or newer (required)
#   OC_EXTRA  more OpenClaw launchers for the ClawHub load gate, space separated,
#             for example the released openclaw executable
set -u -o pipefail
P="${1:?package dir}"; OUT="${2:?out dir}"; REF2="${3:-}"; REF1="${4:-}"
P="${P:A}"; mkdir -p "$OUT"; OUT="${OUT:A}"
: "${OCJS:?set OCJS to an openclaw.mjs}"; : "${CHJS:?set CHJS to the clawhub CLI entry file}"
OC=(node "$OCJS"); CH=(node "$CHJS")
T="$P/tests"; S="$P/scripts"
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
NAME=$(node -p "require('$P/package.json').name.split('/')[1]")
VER=$(node -p "require('$P/package.json').version")
BASE="etzelm-$NAME-$VER"
echo "=== $BASE"
echo "openclaw $("${OC[@]}" --version 2>/dev/null | tail -1), clawhub $("${CH[@]}" --cli-version 2>/dev/null | tail -1)"
for t in jac-v3-steps jac-cap-count jac-dry-run-attempts jac-db-clock jac-package; do
  zsh "$T/$t.test.sh" "$P" > "$OUT/test-$t.log" 2>&1; gate "test $t ($(tail -1 "$OUT/test-$t.log"))" $?
done
if [[ -n "$REF2" ]]; then
  zsh "$T/jac-migrate-v3.test.sh" "$P" "$REF2" > "$OUT/test-jac-migrate-v3.log" 2>&1; gate "test jac-migrate-v3 ($(tail -1 "$OUT/test-jac-migrate-v3.log"))" $?
else echo "GATE SKIP test jac-migrate-v3 (no 0.2.0 package dir given)"; fi
if [[ -n "$REF1" ]]; then
  zsh "$T/jac-migrate.test.sh" "$P" "$REF1" > "$OUT/test-jac-migrate.log" 2>&1; gate "test jac-migrate v1 chain ($(tail -1 "$OUT/test-jac-migrate.log"))" $?
else echo "GATE SKIP test jac-migrate v1 chain (no 0.1.2 package dir given)"; fi
"${OC[@]}" templates validate "$P" > "$OUT/validate.log" 2>&1; gate "validate" $?
! grep -q "Excluded: assets/icon.png" "$OUT/validate.log"; gate "validate does not exclude assets/icon.png" $?
"${OC[@]}" templates dev "$P" > "$OUT/dev.log" 2>&1; gate "dev" $?
rm -f "$OUT/$BASE.tgz" "$OUT/$BASE.b.tgz"
"${OC[@]}" templates build "$P" --out "$OUT/$BASE.tgz" > "$OUT/build1.log" 2>&1; gate "build 1" $?
sleep 2
"${OC[@]}" templates build "$P" --out "$OUT/$BASE.b.tgz" > "$OUT/build2.log" 2>&1; gate "build 2" $?
A=$(shasum -a 256 "$OUT/$BASE.tgz" | cut -d' ' -f1); B=$(shasum -a 256 "$OUT/$BASE.b.tgz" | cut -d' ' -f1)
echo "sha256 $BASE.tgz $A"
[[ "$A" == "$B" ]]; gate "deterministic build" $?
rm -f "$OUT/$BASE.b.tgz"
echo "$A  $BASE.tgz" > "$OUT/$BASE.tgz.sha256"
tar tzf "$OUT/$BASE.tgz" | sort > "$OUT/files.txt"
grep -qx "package/assets/icon.png" "$OUT/files.txt"; gate "artifact contains package/assets/icon.png" $?
! grep -qE "^package/(tests|scripts)/" "$OUT/files.txt"; gate "artifact leaves out tests/ and scripts/" $?
"${CH[@]}" package publish "$OUT/$BASE.tgz" --family template --dry-run > "$OUT/clawhub-dry-run.log" 2>&1; gate "clawhub package publish --dry-run" $?
"${CH[@]}" package publish "$OUT/$BASE.tgz" --family template --dry-run --json > "$OUT/clawhub-dry-run.json" 2>&1
grep -q "assets/icon.png" "$OUT/clawhub-dry-run.log" "$OUT/clawhub-dry-run.json"; gate "clawhub dry run lists assets/icon.png" $?
# The ClawHub publish check is not enough: OpenClaw must also load the artifact from ClawHub.
zsh "$S/clawhub-load.sh" "$OUT/$BASE.tgz" "$OUT/clawhub-load" ok "$OCJS" ${=OC_EXTRA:-} > "$OUT/clawhub-load.log" 2>&1; LRC=$?
grep "^GATE" "$OUT/clawhub-load.log"; [[ $LRC -eq 0 ]] || FAIL=1
# Greps on the exact archive contents.
X="$OUT/extract"; rm -rf "$X"; mkdir -p "$X"; tar xzf "$OUT/$BASE.tgz" -C "$X"
LEAK='(/Use[r]s/|/Volu[m]es/|/home/[a-z]|192\.168\.|\.local\b|mitchell|etzel@|@live\.com|@gmail|stu[d]io|macbook|nas\b|qnap|gitlab|workboard|claude|anthropic|opus|sonnet|haiku|fable|gpt-|deepseek|qwen|llama|mlx)'
grep -rniIE "$LEAK" "$X" | grep -viE 'Mitchell Etzel|@etzelm/' > "$OUT/leak.log"; [[ ! -s "$OUT/leak.log" ]]; gate "leak grep (archive)" $?
grep -rniIE "$LEAK" "$T" "$S" | grep -viE 'Mitchell Etzel|@etzelm/|LEAK=' > "$OUT/leak-src.log"; [[ ! -s "$OUT/leak-src.log" ]]; gate "leak grep (tests and scripts)" $?
EM="$(printf '\342\200\224')"
grep -rn "$EM" "$X" "$T" "$S" > "$OUT/emdash.log"; [[ ! -s "$OUT/emdash.log" ]]; gate "no em dashes" $?
grep -rniIE -f "$S/vendor-names.regex" "$X" > "$OUT/vendor.log"; [[ ! -s "$OUT/vendor.log" ]]; gate "no job-site, ATS or vendor names (archive)" $?
grep -rniIE -f "$S/vendor-names.regex" --exclude vendor-names.regex "$T" "$S" > "$OUT/vendor-src.log"; [[ ! -s "$OUT/vendor-src.log" ]]; gate "no job-site, ATS or vendor names (tests and scripts)" $?
rm -rf "$X"
echo "gates failed=$FAIL"
exit $FAIL

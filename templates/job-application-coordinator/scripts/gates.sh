#!/bin/zsh
# Release gates for JAC 0.3.0. Run on a build host.
# Usage: gates.sh <src dir with jac/, tests/, scripts/> <out dir>
set -u -o pipefail
SRC="${1:?src}"; OUT="${2:?out}"; SRC="${SRC:A}"; mkdir -p "$OUT"; OUT="${OUT:A}"
OC=(node "${OCJS:-$HOME/work/templates-v03-oc/oc/openclaw.mjs}")
# clawhub 0.26.0 (npm latest since 2026-11-13) understands the CLAW.md format.
CH=(node "${CHJS:-$HOME/work/templates-v03-live/clawhub-cli/node_modules/clawhub/bin/clawdhub.js}")
mkdir -p "$OUT"
FAIL=0
gate() { # name rc
  if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi
}
P="$SRC/jac"
NAME=$(node -p "require('$P/package.json').name.split('/')[1]")
VER=$(node -p "require('$P/package.json').version")
BASE="etzelm-$NAME-$VER"
echo "=== jac ($BASE)"
for t in jac-v3-steps jac-cap-count jac-package; do
  zsh "$SRC/tests/$t.test.sh" "$P" > "$OUT/test-$t.log" 2>&1; gate "test $t ($(tail -1 "$OUT/test-$t.log"))" $?
done
zsh "$SRC/tests/jac-migrate-v3.test.sh" "$P" "$SRC/ref/jac-0.2.0" > "$OUT/test-jac-migrate-v3.log" 2>&1; gate "test jac-migrate-v3 ($(tail -1 "$OUT/test-jac-migrate-v3.log"))" $?
zsh "$SRC/tests/jac-migrate.test.sh" "$P" "$SRC/ref/jac-0.1.2" > "$OUT/test-jac-migrate.log" 2>&1; gate "test jac-migrate v1 chain ($(tail -1 "$OUT/test-jac-migrate.log"))" $?
"${OC[@]}" templates validate "$P" > "$OUT/validate.log" 2>&1; gate "validate" $?
"${OC[@]}" templates dev "$P" > "$OUT/dev.log" 2>&1; gate "dev" $?
rm -f "$OUT/$BASE.tgz" "$OUT/$BASE.b.tgz"
"${OC[@]}" templates build "$P" --out "$OUT/$BASE.tgz" > "$OUT/build1.log" 2>&1; gate "build 1" $?
sleep 2
"${OC[@]}" templates build "$P" --out "$OUT/$BASE.b.tgz" > "$OUT/build2.log" 2>&1; gate "build 2" $?
A=$(shasum -a 256 "$OUT/$BASE.tgz" | cut -d' ' -f1); B=$(shasum -a 256 "$OUT/$BASE.b.tgz" | cut -d' ' -f1)
echo "sha256 $BASE.tgz $A"; echo "sha256 $BASE.b.tgz $B"
[[ "$A" == "$B" ]]; gate "deterministic build" $?
rm -f "$OUT/$BASE.b.tgz"
echo "$A  $BASE.tgz" > "$OUT/$BASE.tgz.sha256"
tar tzf "$OUT/$BASE.tgz" | sort > "$OUT/files.txt"
"${CH[@]}" package publish "$OUT/$BASE.tgz" --family template --dry-run > "$OUT/clawhub-dry-run.log" 2>&1; gate "clawhub $("${CH[@]}" --cli-version 2>/dev/null | tail -1) publish --dry-run" $?
# Greps on the exact archive contents.
X="$OUT/extract"; rm -rf "$X"; mkdir -p "$X"; tar xzf "$OUT/$BASE.tgz" -C "$X"
LEAK='(/Use[r]s/|/home/[a-z]|192\.168\.|\.local\b|mitchell|etzel@|@live\.com|@gmail|stu[d]io|macbook|nas\b|qnap|gitlab|workboard|claude|anthropic|opus|sonnet|haiku|fable|gpt-|deepseek|qwen|llama|mlx)'
grep -rniIE "$LEAK" "$X" | grep -viE 'Mitchell Etzel|@etzelm/' > "$OUT/leak.log"; [[ ! -s "$OUT/leak.log" ]]; gate "leak grep" $?
grep -rn $'\u2014' "$X" > "$OUT/emdash.log"; [[ ! -s "$OUT/emdash.log" ]]; gate "no em dashes" $?
grep -rniIE -f "$SRC/scripts/vendor-names.regex" "$X" > "$OUT/vendor.log"; [[ ! -s "$OUT/vendor.log" ]]; gate "no job-site, ATS or vendor names" $?
grep -rniIE -f "$SRC/scripts/vendor-names.regex" "$SRC/tests" "$SRC/jac" > "$OUT/vendor-src.log"; [[ ! -s "$OUT/vendor-src.log" ]]; gate "no vendor names in tests and source" $?
rm -rf "$X"
echo "gates failed=$FAIL"
exit $FAIL

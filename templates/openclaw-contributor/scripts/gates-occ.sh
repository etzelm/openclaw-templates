#!/bin/zsh
# Release gates for the OpenClaw contributor Template 0.3.0. Run on a build host.
# Usage: gates-occ.sh <package dir> <out dir>
# Leak grep allows two public names (claude-cli, ANTHROPIC_API_KEY) used for the ClawSweeper OpenClaw runner limit and key list.
# Needs ~/work/occ-v03/oc (OpenClaw main build) and ~/work/occ-v03/clawhub (npm clawhub).
set -u -o pipefail
P="${1:?package dir}"; OUT="${2:?out}"
mkdir -p "$OUT"; P="${P:A}"; OUT="${OUT:A}"
OC=(node "$HOME/work/occ-v03/oc/openclaw.mjs")
CH=("$HOME/work/occ-v03/clawhub/node_modules/.bin/clawhub")
mkdir -p "$OUT"
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
NAME=$(node -p "require('$P/package.json').name.split('/')[1]")
VER=$(node -p "require('$P/package.json').version")
BASE="etzelm-$NAME-$VER"
echo "=== $BASE"
echo "openclaw $(git -C "$HOME/work/occ-v03/oc" rev-parse --short HEAD), clawhub $("${CH[@]}" --version 2>/dev/null | tail -1)"
"${OC[@]}" templates validate "$P" > "$OUT/validate.log" 2>&1; gate "validate" $?
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
"${CH[@]}" package publish "$OUT/$BASE.tgz" --family template --dry-run > "$OUT/clawhub-dry-run.log" 2>&1; gate "clawhub package publish --dry-run" $?
X="$OUT/extract"; rm -rf "$X"; mkdir -p "$X"; tar xzf "$OUT/$BASE.tgz" -C "$X"
LEAK='(/Use[r]s/|/home/[a-z]|192\.168\.|\.local\b|mitchell|etzel@|@live\.com|@gmail|stu[d]io|macbook|nas\b|qnap|gitlab|workboard|claude|anthropic|opus|sonnet|haiku|fable|gpt-|deepseek|qwen|llama|mlx)'
grep -rniE "$LEAK" "$X" | grep -viE 'Mitchell Etzel|@etzelm/|finds possible leaks' | sed -E 's/claude-cli|ANTHROPIC_API_KEY//g' | grep -iE "$LEAK" > "$OUT/leak.log"; [[ ! -s "$OUT/leak.log" ]]; gate "leak grep" $?
grep -rn $'\u2014' "$X" > "$OUT/emdash.log"; [[ ! -s "$OUT/emdash.log" ]]; gate "no em dashes" $?
rm -rf "$X"
echo "gates failed=$FAIL"
exit $FAIL

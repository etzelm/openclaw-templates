#!/bin/zsh
# Release gates for the OpenClaw contributor Template 0.4.2. Run on a build machine with an OpenClaw main build.
# Usage: gates-occ.sh <package dir> <out dir> [tests dir]
# Leak grep: generic patterns here; add your own names, hosts and emails one per line in the file named by
# OCC_LEAK_PATTERNS (kept outside this repo). Two public names (claude-cli, ANTHROPIC_API_KEY) are allowed.
# Needs ~/work/occ-v042/oc (OpenClaw main build) and ~/work/occ-v042/clawhub (npm clawhub).
set -u -o pipefail
P="${1:?package dir}"; OUT="${2:?out}"; T="${3:-}"
mkdir -p "$OUT"; P="${P:A}"; OUT="${OUT:A}"
OC=(node "$HOME/work/occ-v042/oc/openclaw.mjs")
CH=("$HOME/work/occ-v042/clawhub/node_modules/.bin/clawhub")
mkdir -p "$OUT"
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
NAME=$(node -p "require('$P/package.json').name.split('/')[1]")
VER=$(node -p "require('$P/package.json').version")
BASE="etzelm-$NAME-$VER"
echo "=== $BASE"
echo "openclaw $(git -C "$HOME/work/occ-v042/oc" rev-parse --short HEAD), clawhub $("${CH[@]}" -V 2>/dev/null | tail -1)"
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
"${CH[@]}" package publish "$OUT/$BASE.tgz" --family template --dry-run > "$OUT/clawhub-dry-run.log" 2>&1; gate "clawhub package publish --dry-run" $?
"${CH[@]}" package publish "$OUT/$BASE.tgz" --family template --dry-run --json > "$OUT/clawhub-dry-run.json" 2>&1
grep -q "assets/icon.png" "$OUT/clawhub-dry-run.log" "$OUT/clawhub-dry-run.json"; gate "clawhub dry run lists assets/icon.png" $?
X="$OUT/extract"; rm -rf "$X"; mkdir -p "$X"; tar xzf "$OUT/$BASE.tgz" -C "$X"
LEAK='(/Users/|/home/[a-z]|192\.168\.|10\.[0-9]+\.[0-9]+\.|\.local\b|@gmail|@outlook|@live\.|@hotmail|claude|anthropic|opus|sonnet|haiku|fable|gpt-|deepseek|qwen|llama|mlx)'
if [[ -n "${OCC_LEAK_PATTERNS:-}" && -s "$OCC_LEAK_PATTERNS" ]]; then LEAK="${LEAK%)}|$(grep -v '^\s*$' "$OCC_LEAK_PATTERNS" | paste -sd'|' -))"; fi
grep -rniE "$LEAK" "$X" | grep -viE 'Mitchell Etzel|@etzelm/|finds possible leaks' | sed -E 's/claude-cli|ANTHROPIC_API_KEY//g' | grep -iE "$LEAK" > "$OUT/leak.log"; [[ ! -s "$OUT/leak.log" ]]; gate "leak grep" $?
grep -rn $'—' "$X" > "$OUT/emdash.log"; [[ ! -s "$OUT/emdash.log" ]]; gate "no em dashes" $?
rm -rf "$X"
if [[ -n "$T" ]]; then
  for t in "$T"/occ-*.test.sh; do
    zsh "$t" "$P" > "$OUT/sql-$(basename "$t" .test.sh).log" 2>&1; gate "sql $(basename "$t"): $(tail -1 "$OUT/sql-$(basename "$t" .test.sh).log")" $?
  done
  node "$T/pr-watch.test.mjs" "$P" > "$OUT/pr-watch.log" 2>&1; gate "pr-watch.test.mjs: $(tail -1 "$OUT/pr-watch.log")" $?
fi
# The packaged watcher must parse as an async script body (top-level await and return).
node -e "const s=require('fs').readFileSync('$P/references/pr-watch.js','utf8'); new (Object.getPrototypeOf(async function(){}).constructor)('exec','trigger',s)" > "$OUT/pr-watch-parse.log" 2>&1; gate "pr-watch.js parses as a trigger script" $?
echo "gates failed=$FAIL"
exit $FAIL

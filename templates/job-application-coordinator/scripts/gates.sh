#!/bin/zsh
# Release gates for the two Templates. Run on a build host.
# Usage: gates.sh <src dir with jac/ and occ/> <out dir>
set -u -o pipefail
SRC="${1:?src}"; OUT="${2:?out}"
OC=(node "$HOME/work/templates-v02-oc/oc/openclaw.mjs")
CH_NEW=(node "$HOME/work/templates-v02-live/clawhub-src/packages/clawhub/bin/clawdhub.js")
CH_OLD=(node "$HOME/work/templates-v02-live/clawhub-cli/x/package/bin/clawdhub.js")
mkdir -p "$OUT"
FAIL=0
gate() { # name rc
  if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi
}
for t in jac occ; do
  P="$SRC/$t"
  NAME=$(node -p "require('$P/package.json').name.split('/')[1]")
  VER=$(node -p "require('$P/package.json').version")
  BASE="etzelm-$NAME-$VER"
  echo "=== $t ($BASE)"
  "${OC[@]}" templates validate "$P" > "$OUT/$t-validate.log" 2>&1; gate "$t validate" $?
  "${OC[@]}" templates dev "$P" > "$OUT/$t-dev.log" 2>&1; gate "$t dev" $?
  rm -f "$OUT/$BASE.tgz" "$OUT/$BASE.b.tgz"
  "${OC[@]}" templates build "$P" --out "$OUT/$BASE.tgz" > "$OUT/$t-build1.log" 2>&1; gate "$t build 1" $?
  sleep 2
  "${OC[@]}" templates build "$P" --out "$OUT/$BASE.b.tgz" > "$OUT/$t-build2.log" 2>&1; gate "$t build 2" $?
  A=$(shasum -a 256 "$OUT/$BASE.tgz" | cut -d' ' -f1); B=$(shasum -a 256 "$OUT/$BASE.b.tgz" | cut -d' ' -f1)
  echo "sha256 $BASE.tgz $A"; echo "sha256 $BASE.b.tgz $B"
  [[ "$A" == "$B" ]]; gate "$t deterministic build" $?
  rm -f "$OUT/$BASE.b.tgz"
  echo "$A  $BASE.tgz" > "$OUT/$BASE.tgz.sha256"
  tar tzf "$OUT/$BASE.tgz" | sort > "$OUT/$t-files.txt"
  "${CH_NEW[@]}" package publish "$OUT/$BASE.tgz" --family template --dry-run > "$OUT/$t-clawhub-0.26.0-dry-run.log" 2>&1; gate "$t clawhub 0.26.0 (main) publish --dry-run" $?
  "${CH_OLD[@]}" package publish "$OUT/$BASE.tgz" --family template --dry-run > "$OUT/$t-clawhub-0.25.1-dry-run.log" 2>&1
  echo "info: clawhub 0.25.1 (npm latest) dry-run rc=$? (expected non-zero: old schema)"
  # Leak grep on the exact archive contents.
  X="$OUT/$t-extract"; rm -rf "$X"; mkdir -p "$X"; tar xzf "$OUT/$BASE.tgz" -C "$X"
  LEAK='(/Use[r]s/|/home/[a-z]|192\.168\.|\.local\b|mitchell|etzel@|@live\.com|@gmail|stu[d]io|macbook|nas\b|qnap|gitlab|workboard|claude|anthropic|opus|sonnet|haiku|fable|gpt-|deepseek|qwen|llama|mlx|greenhouse|lever\.co|workday|ashby|linkedin|indeed|glassdoor|smartrecruiters|icims|taleo)'
  grep -rniE "$LEAK" "$X" | grep -viE 'Mitchell Etzel|@etzelm/|finds possible leaks' > "$OUT/$t-leak.log"; [[ ! -s "$OUT/$t-leak.log" ]]; gate "$t leak grep" $?
  grep -rn $'\u2014' "$X" > "$OUT/$t-emdash.log"; [[ ! -s "$OUT/$t-emdash.log" ]]; gate "$t no em dashes" $?
  rm -rf "$X"
done
echo "gates failed=$FAIL"
exit $FAIL

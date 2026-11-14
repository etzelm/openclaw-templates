#!/bin/zsh
# Gate: a built Template .tgz must load through OpenClaw's own ClawHub path, not only
# pass the ClawHub publish check. 0.1.2 passed the publish check and then failed in
# every OpenClaw with "Downloaded Template package manifest is invalid."
# Serves the .tgz from a local mock registry and runs
#   openclaw templates add @publisher/name --dry-run --json
# against it, once per OpenClaw given, each in its own empty HOME and state folder.
# Usage: clawhub-load.sh <tgz> <out dir> <expect: ok|invalid> <openclaw launcher>...
#   A launcher is an openclaw.mjs file (run with node) or an openclaw executable.
# Env: MOCK_PORT (default 18951).
set -u -o pipefail
TGZ="${1:?tgz}"; OUT="${2:?out dir}"; EXPECT="${3:?ok or invalid}"; shift 3
[[ $# -ge 1 ]] || { echo "need at least one openclaw launcher"; exit 2; }
TGZ="${TGZ:A}"; mkdir -p "$OUT"; OUT="${OUT:A}"
PORT="${MOCK_PORT:-18951}"
HERE="${0:A:h}"
NAME=$(tar xzOf "$TGZ" package/package.json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).name))')
VER=$(tar xzOf "$TGZ" package/package.json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).version))')
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
node "$HERE/mock-registry.mjs" "$TGZ" "$PORT" > "$OUT/mock-registry.log" 2>&1 &
MOCK=$!
trap 'kill $MOCK 2>/dev/null' EXIT INT TERM
for i in {1..20}; do sleep 0.5; grep -q "mock registry for" "$OUT/mock-registry.log" 2>/dev/null && break; done
REAL_HOME="$HOME"
N=0
for L in "$@"; do
  N=$((N + 1))
  if [[ "$L" == *.mjs ]]; then OC=(node "${L:A}"); else OC=("$L"); fi
  I="$OUT/load-$N"; rm -rf "$I"; mkdir -p "$I/home"
  (
    export HOME="$I/home" OPENCLAW_STATE_DIR="$I/home/.openclaw" OPENCLAW_CLAWHUB_URL="http://127.0.0.1:$PORT"
    unset OPENCLAW_CONFIG_PATH OPENCLAW_PROFILE OPENCLAW_HOME CLAWHUB_URL
    "${OC[@]}" --version > "$I/version.txt" 2>&1
    "${OC[@]}" config set gateway.mode local > /dev/null 2>&1
    "${OC[@]}" config set gateway.controlUi.experimental.templates true > /dev/null 2>&1
    "${OC[@]}" templates add "$NAME" --dry-run --json > "$I/add-plan.json" 2> "$I/add-plan.err"
  )
  export HOME="$REAL_HOME"
  V="$(tail -1 "$I/version.txt")"
  RESULT=$(node -e '
    const t = require("fs").readFileSync(process.argv[1], "utf8"); const i = t.indexOf("{");
    let j = {}; try { j = JSON.parse(t.slice(i)); } catch {}
    const tpl = j.template ?? j.plan?.template ?? {};
    console.log(j.ok === false ? `error:${j.error?.code}` : `ok:${tpl.version ?? j.version ?? ""}`);
  ' "$I/add-plan.json")
  if [[ "$EXPECT" == ok ]]; then
    [[ "$RESULT" == ok:* ]] && grep -q "\"$VER\"" "$I/add-plan.json"; gate "ClawHub add plan loads $NAME@$VER on $V ($RESULT)" $?
  else
    [[ "$RESULT" == "error:clawhub_manifest_invalid" ]]; gate "known-bad package is refused on $V ($RESULT)" $?
  fi
done
grep -c "artifact/download" "$OUT/mock-registry.log" > "$OUT/downloads.txt"
[[ "$(cat "$OUT/downloads.txt")" -ge $# ]]; gate "every OpenClaw downloaded the artifact from the mock registry" $?
echo "clawhub-load failed=$FAIL"
exit $FAIL

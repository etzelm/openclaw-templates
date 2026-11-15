#!/bin/zsh
# Isolated Add of the built Template on a build host: own HOME and state folder, no Gateway.
# Adds the built .tgz (extracted, as ClawHub serves it) with defaults, checks what Add
# wrote (setup file, MCP server, tool policy, paused automation, icon, site notes),
# then runs the setup database commands from the new workspace.
# Usage: isolated-add.sh <tgz> <instance dir>
# Env:
#   OCJS         openclaw.mjs of the OpenClaw build to test (required)
#   MODEL_SETUP  a zsh file that configures a working model for the instance (required).
#                It is sourced with HOME and OPENCLAW_STATE_DIR already isolated and may
#                call "${OC[@]}" config set ... and export variables. Add ends with a
#                greeting turn from the new agent; without a model that turn fails and
#                Add leaves a half-made agent.
set -u -o pipefail
TGZ="${1:?tgz}"; INST="${2:?instance dir}"
: "${OCJS:?set OCJS to an openclaw.mjs}"; : "${MODEL_SETUP:?set MODEL_SETUP to a zsh file that configures a model}"
TGZ="${TGZ:A}"; MODEL_SETUP="${MODEL_SETUP:A}"
rm -rf "$INST"; mkdir -p "$INST/home"; INST="${INST:A}"
export HOME="$INST/home"
export OPENCLAW_STATE_DIR="$HOME/.openclaw"
unset OPENCLAW_CONFIG_PATH OPENCLAW_PROFILE OPENCLAW_HOME
mkdir -p "$OPENCLAW_STATE_DIR"
OC=(node "$OCJS")
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
"${OC[@]}" config set gateway.mode local >/dev/null
"${OC[@]}" config set gateway.bind loopback >/dev/null
"${OC[@]}" config set gateway.controlUi.experimental.templates true >/dev/null
source "$MODEL_SETUP"
ID=job-application-coordinator
X="$INST/extract"; mkdir -p "$X"; tar xzf "$TGZ" -C "$X"
"${OC[@]}" templates add "$X/package" --dry-run --json > "$INST/add-dry-run.json" 2>&1; gate "add --dry-run (defaults)" $?
# Some model runtimes keep a helper process warm, and Add then stays up after it has
# written its result. Wait for the result, not for the process.
"${OC[@]}" templates add "$X/package" --json > "$INST/add.json" 2> "$INST/add.err" < /dev/null &
APID=$!
for i in {1..150}; do
  sleep 2
  kill -0 $APID 2>/dev/null || break
  grep -q '"status"' "$INST/add.json" 2>/dev/null && { sleep 3; break; }
done
kill $APID 2>/dev/null; wait $APID 2>/dev/null
grep -q '"status": "complete"' "$INST/add.json"; gate "add (defaults) completes, greeting included" $?
cp "$OPENCLAW_STATE_DIR/openclaw.json" "$INST/config-after-add.json"
"${OC[@]}" agents list --json > "$INST/agents.json" 2>/dev/null
WS=$(node -e "const t=require('fs').readFileSync('$INST/agents.json','utf8'); const a=JSON.parse(t.slice(t.search(/[\[{]/))); const l=Array.isArray(a)?a:(a.agents||[]); const x=l.find(e=>e.id==='$ID'); console.log(x?.workspace||x?.workspaceDir||'')" 2>/dev/null)
[[ -z "$WS" ]] && WS="$OPENCLAW_STATE_DIR/workspace-$ID"
echo "workspace: ${WS#$INST/}"
[[ -f "$WS/BOOTSTRAP.md" ]]; gate "BOOTSTRAP.md is in the workspace" $?
"${OC[@]}" mcp show chrome-devtools-jobs --json > "$INST/mcp-show.json" 2>&1; gate "mcp show chrome-devtools-jobs" $?
"${OC[@]}" mcp doctor chrome-devtools-jobs > "$INST/mcp-doctor.log" 2>&1; grep -q "chrome-devtools-jobs: ok" "$INST/mcp-doctor.log"; gate "mcp doctor chrome-devtools-jobs (the documented check)" $?
node -e '
const c=require(process.argv[1]); const id=process.argv[2]; const s=c.mcp?.servers?.["chrome-devtools-jobs"];
const a=c.agents?.entries?.[id] ?? (c.agents?.list??[]).find(x=>x.id===id);
const granted=[...(a?.tools?.allow??[]), ...(a?.tools?.alsoAllow??[])].filter(t=>t.includes("__"));
const ok = s && s.command==="npx" && s.args.includes("chrome-devtools-mcp@1.12.0") && s.args.includes("--no-javascript-evaluation") && s.args.filter(x=>x.startsWith("--workspace")).join()==="--workspace=${HOME}/job-application-coordinator-files"
  && s.toolFilter?.include?.length===18 && !s.toolFilter.include.includes("evaluate_script")
  && a?.tools && a.tools.deny.includes("chrome-devtools-jobs__evaluate_script") && a.tools.deny.includes("gateway")
  && granted.length===18 && granted.every(t=>t.startsWith("chrome-devtools-jobs__") && s.toolFilter.include.includes(t.slice("chrome-devtools-jobs__".length)));
console.log(JSON.stringify({server:s, agentTools:a?.tools}, null, 1)); process.exit(ok?0:1);
' "$INST/config-after-add.json" "$ID" > "$INST/config-check.json" 2>&1; gate "Add wrote the pinned server, its 18-tool filter and the agent tool policy" $?
sqlite3 -readonly "$OPENCLAW_STATE_DIR/state/openclaw.sqlite" "SELECT enabled FROM cron_jobs WHERE declaration_key = 'template:$ID:daily-apply-run';" > "$INST/automation-enabled.txt" 2>&1
[[ "$(cat "$INST/automation-enabled.txt")" == "0" ]]; gate "daily automation installed paused (cron_jobs.enabled = 0)" $?
[[ -f "$WS/site-notes.md" ]]; gate "site-notes.md is in the workspace" $?
[[ -f "$WS/avatars/job-application-coordinator.svg" && -f "$WS/avatars/catalog.png" ]]; gate "avatar and catalog icon are in the workspace" $?
[[ -f "$WS/docs/README.md" ]]; gate "docs/README.md is in the workspace" $?
for f in save-prefiltered ranked-queue save-question open-questions mark-answered migrate-v2-to-v3; do
  [[ -f "$WS/references/sql/$f.sql" ]]; gate "workspace has references/sql/$f.sql" $?
done
DB="$HOME/job-application-coordinator.db"
( cd "$WS" && sqlite3 -version >/dev/null && sqlite3 -bail "$DB" ".read references/schema.sql" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" ) > "$INST/setup-check.log" 2>&1
grep -q "setup-check ok, schema version 3" "$INST/setup-check.log"; gate "setup self-test (setup-check ok, schema version 3)" $?
rm -f "$DB"
echo "isolated add failed=$FAIL"
exit $FAIL

#!/bin/zsh
# Isolated OpenClaw instance on a build host: own HOME, own state dir, own port.
# Adds the built JAC 0.3.0 .tgz (extracted, as ClawHub serves it) with defaults,
# checks what Add wrote (MCP server, tool policy, paused automation, site notes),
# then runs the BOOTSTRAP database commands from the new workspace.
# Usage: isolated-add.sh <gates out dir> <instance dir>
set -u -o pipefail
OUTDIR="${1:?gates out}"; INST="${2:?instance dir}"
OCJS="${OCJS:-$HOME/work/templates-v03-oc/oc/openclaw.mjs}"
rm -rf "$INST"; mkdir -p "$INST/home"
export HOME="$INST/home"
export OPENCLAW_STATE_DIR="$HOME/.openclaw"
unset OPENCLAW_CONFIG_PATH OPENCLAW_PROFILE OPENCLAW_HOME
mkdir -p "$OPENCLAW_STATE_DIR"
OC=(node "$OCJS")
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
# No secrets: the local model server needs no key; the value below is a placeholder.
"${OC[@]}" config set gateway.mode local >/dev/null
"${OC[@]}" config set gateway.port 19431 >/dev/null
"${OC[@]}" config set gateway.bind loopback >/dev/null
"${OC[@]}" config set gateway.controlUi.experimental.templates true >/dev/null
"${OC[@]}" config set models.providers.local '{"baseUrl":"'"${LOCAL_MODEL_URL:-http://localhost:1236/v1}"'","api":"openai-completions","apiKey":"local-no-auth","timeoutSeconds":3600,"models":[{"id":"DeepSeek-V4.1-Flash-1017-oQ3e-mtp","name":"Local","api":"openai-completions","reasoning":true,"input":["text"],"contextWindow":262144}]}' --strict-json >/dev/null
"${OC[@]}" config set agents.defaults.model.primary local/DeepSeek-V4.1-Flash-1017-oQ3e-mtp >/dev/null
BASE=etzelm-job-application-coordinator-0.3.0
X="$INST/extract/$BASE"; mkdir -p "$X"
tar xzf "$OUTDIR/$BASE.tgz" -C "$X"
"${OC[@]}" templates add "$X/package" --dry-run --json > "$INST/add-dry-run.json" 2>&1; gate "add --dry-run (defaults)" $?
"${OC[@]}" templates add "$X/package" --json > "$INST/add.json" 2>&1; gate "add (defaults, offline)" $?
cp "$OPENCLAW_STATE_DIR/openclaw.json" "$INST/config-after-add.json"
"${OC[@]}" agents list --json > "$INST/agents.json" 2>&1
"${OC[@]}" automations list --all --json > "$INST/automations.json" 2>&1 || true
"${OC[@]}" mcp show jac-chrome --json > "$INST/mcp-show.json" 2>&1; gate "mcp show jac-chrome" $?
node -e '
const c=require(process.argv[1]); const s=c.mcp?.servers?.["jac-chrome"];
const a=c.agents?.entries?.["job-application-coordinator"] ?? (c.agents?.list??[]).find(x=>x.id==="job-application-coordinator");
const ok = s && s.command==="npx" && s.args.includes("chrome-devtools-mcp@1.12.0") && s.args.includes("--no-javascript-evaluation") && s.args.filter(x=>x.startsWith("--workspace")).join()==="--workspace=${HOME}/job-application-coordinator-files"
  && s.toolFilter?.include?.length===18 && !s.toolFilter.include.includes("evaluate_script")
  && a?.tools && a.tools.deny.includes("jac-chrome__evaluate_script")
  && [...(a.tools.allow??[]), ...(a.tools.alsoAllow??[])].filter(t=>t.includes("__")).length===18
  && [...(a.tools.allow??[]), ...(a.tools.alsoAllow??[])].filter(t=>t.includes("__")).every(t=>t.startsWith("jac-chrome__") && s.toolFilter.include.includes(t.slice(12)));
console.log(JSON.stringify({server:s, agentTools:a?.tools}, null, 1)); process.exit(ok?0:1);
' "$INST/config-after-add.json" > "$INST/config-check.json" 2>&1; gate "Add wrote the pinned server, its 18-tool filter and the agent tool policy" $?
sqlite3 -readonly "$OPENCLAW_STATE_DIR/state/openclaw.sqlite" "SELECT enabled FROM cron_jobs WHERE declaration_key = 'template:job-application-coordinator:daily-apply-run';" > "$INST/automation-enabled.txt" 2>&1
[[ "$(cat "$INST/automation-enabled.txt")" == "0" ]]; gate "daily automation installed paused (cron_jobs.enabled = 0)" $?
WS=$(node -e "const a=require('$INST/agents.json'); const l=Array.isArray(a)?a:(a.agents||[]); const x=l.find(e=>e.id==='job-application-coordinator'); console.log(x?.workspace||x?.workspaceDir||'')")
[[ -z "$WS" ]] && WS="$OPENCLAW_STATE_DIR/workspace-job-application-coordinator"
echo "workspace: $WS"
[[ -f "$WS/site-notes.md" ]]; gate "site-notes.md is in the workspace" $?
for f in save-prefiltered ranked-queue save-question open-questions mark-answered migrate-v2-to-v3; do
  [[ -f "$WS/references/sql/$f.sql" ]]; gate "workspace has references/sql/$f.sql" $?
done
DB="$HOME/job-application-coordinator.db"
( cd "$WS" && sqlite3 -version >/dev/null && sqlite3 -bail "$DB" ".read references/schema.sql" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" ) > "$INST/setup-check.log" 2>&1
grep -q "setup-check ok, schema version 3" "$INST/setup-check.log"; gate "setup self-test (setup-check ok, schema version 3)" $?
rm -f "$DB"
echo "isolated add failed=$FAIL"
exit $FAIL

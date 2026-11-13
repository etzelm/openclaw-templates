#!/bin/zsh
# Isolated OpenClaw instance on a build host: own HOME, own state dir, own port.
# Adds each built .tgz (extracted, as ClawHub serves it) with defaults, then
# runs the BOOTSTRAP database commands from the new workspace.
# Usage: isolated-add.sh <gates out dir> <instance dir>
set -u -o pipefail
OUTDIR="${1:?gates out}"; INST="${2:?instance dir}"
OCJS="$HOME/work/templates-v02-oc/oc/openclaw.mjs"
export HOME="$INST/home"
export OPENCLAW_STATE_DIR="$HOME/.openclaw"
unset OPENCLAW_CONFIG_PATH OPENCLAW_PROFILE OPENCLAW_HOME
mkdir -p "$OPENCLAW_STATE_DIR"
OC=(node "$OCJS")
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
if [[ ! -f "$OPENCLAW_STATE_DIR/openclaw.json" ]]; then
  # No secrets: the local model server needs no key; the value below is a placeholder.
  "${OC[@]}" config set gateway.mode local >/dev/null
  "${OC[@]}" config set gateway.port 19411 >/dev/null
  "${OC[@]}" config set gateway.bind loopback >/dev/null
  "${OC[@]}" config set gateway.controlUi.experimental.templates true >/dev/null
  "${OC[@]}" config set models.providers.local '{"baseUrl":"'"${LOCAL_MODEL_URL:-http://localhost:1236/v1}"'","api":"openai-completions","apiKey":"local-no-auth","timeoutSeconds":3600,"models":[{"id":"DeepSeek-V4.1-Flash-1017-oQ3e-mtp","name":"Local","api":"openai-completions","reasoning":true,"input":["text"],"contextWindow":262144}]}' --strict-json >/dev/null
  "${OC[@]}" config set agents.defaults.model.primary local/DeepSeek-V4.1-Flash-1017-oQ3e-mtp >/dev/null
fi
for BASE in etzelm-job-application-coordinator-0.2.0 etzelm-openclaw-contributor-0.2.0; do
  X="$INST/extract/$BASE"; rm -rf "$X"; mkdir -p "$X"
  tar xzf "$OUTDIR/$BASE.tgz" -C "$X"
  "${OC[@]}" templates add "$X/package" --dry-run --json > "$INST/$BASE-add-dry-run.json" 2>&1; gate "$BASE add --dry-run (defaults)" $?
  "${OC[@]}" templates add "$X/package" --json > "$INST/$BASE-add.json" 2>&1; gate "$BASE add (defaults, offline)" $?
done
"${OC[@]}" agents list --json > "$INST/agents.json" 2>&1
"${OC[@]}" automations list --all --json > "$INST/automations.json" 2>&1 || true
# Setup self-test, exactly as BOOTSTRAP.md runs it, from each default workspace.
for pair in "job-application-coordinator:~/job-application-coordinator.db:2" "openclaw-contributor:~/openclaw-contributor.db:1"; do
  ID="${pair%%:*}"; rest="${pair#*:}"; DBP="${rest%%:*}"; V="${rest##*:}"
  WS=$(node -e "const a=require('$INST/agents.json'); const l=Array.isArray(a)?a:(a.agents||[]); const x=l.find(e=>e.id==='$ID'); console.log(x?.workspace||x?.workspaceDir||'')")
  [[ -z "$WS" ]] && WS="$OPENCLAW_STATE_DIR/workspace-$ID"
  echo "workspace $ID: $WS"
  [[ "$WS" == "$OPENCLAW_STATE_DIR"* ]]; gate "$ID default workspace is inside the state dir (the case db_path solves)" $?
  DB="${DBP/#\~/$HOME}"
  rm -f "$DB"
  ( cd "$WS" && sqlite3 -version >/dev/null && sqlite3 -bail "$DB" ".read references/schema.sql" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" ) > "$INST/$ID-setup-check.log" 2>&1
  grep -q "setup-check ok, schema version $V" "$INST/$ID-setup-check.log"; gate "$ID setup self-test (setup-check ok, schema version $V)" $?
  rm -f "$DB"
done
echo "isolated add failed=$FAIL"
exit $FAIL

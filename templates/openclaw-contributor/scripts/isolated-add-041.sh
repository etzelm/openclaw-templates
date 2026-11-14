#!/bin/zsh
# Isolated Add of the built 0.4.1 package with defaults, setup self-test and the setup owner commands,
# then README "Upgrade in place" from the published 0.4.0 artifact, compared with the fresh 0.4.1 Add.
# Own HOME and OPENCLAW_STATE_DIR per instance; no Gateway is started.
# Usage: isolated-add-041.sh <0.4.1 tgz> <0.4.0 tgz> <out dir>
set -u -o pipefail
T41="${1:?0.4.1 tgz}"; T40="${2:?0.4.0 tgz}"; OUT="${3:?out dir}"
T41="${T41:A}"; T40="${T40:A}"; mkdir -p "$OUT"; OUT="${OUT:A}"
OCJS="$HOME/work/occ-v041/oc/openclaw.mjs"
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }

instance() { # <dir>: own HOME and state dir, minimal local config, no secrets
  export HOME="$1/home"; export OPENCLAW_STATE_DIR="$HOME/.openclaw"
  unset OPENCLAW_CONFIG_PATH OPENCLAW_PROFILE OPENCLAW_HOME
  mkdir -p "$OPENCLAW_STATE_DIR"
  node "$OCJS" config set gateway.mode local >/dev/null
  node "$OCJS" config set gateway.bind loopback >/dev/null
  node "$OCJS" config set gateway.controlUi.experimental.templates true >/dev/null
  # Add runs an opening turn, so the instance needs a model: a local model server, no key (placeholder value).
  node "$OCJS" config set models.providers.local '{"baseUrl":"'"${LOCAL_MODEL_URL:-http://localhost:1236/v1}"'","api":"openai-completions","apiKey":"local-no-auth","timeoutSeconds":3600,"models":[{"id":"DeepSeek-V4.1-Flash-1017-oQ3e-mtp","name":"Local","api":"openai-completions","reasoning":true,"input":["text"],"contextWindow":262144}]}' --strict-json >/dev/null
  node "$OCJS" config set agents.defaults.model.primary local/DeepSeek-V4.1-Flash-1017-oQ3e-mtp >/dev/null
}
workspace_of() { # <agents.json> <id>
  node -e "const a=require('$1'); const l=Array.isArray(a)?a:(a.agents||[]); const x=l.find(e=>e.id==='$2'); console.log(x?.workspace||x?.workspaceDir||'')"
}
REAL_HOME="$HOME"

# --- A. Fresh Add of 0.4.1 with defaults ---
A="$OUT/fresh"; rm -rf "$A"; mkdir -p "$A/x"
tar xzf "$T41" -C "$A/x"
instance "$A"
node "$OCJS" templates add "$A/x/package" --dry-run --json > "$A/add-dry-run.json" 2>&1; gate "0.4.1 add --dry-run (defaults)" $?
node "$OCJS" templates add "$A/x/package" --json > "$A/add.json" 2>&1; gate "0.4.1 add (defaults, offline)" $?
grep -q '"status": *"partial"' "$A/add.json"; [[ $? -ne 0 ]]; gate "0.4.1 add status is not partial" $?
node "$OCJS" agents list --json > "$A/agents.json" 2>&1
WSA="$(workspace_of "$A/agents.json" openclaw-contributor)"; [[ -z "$WSA" ]] && WSA="$OPENCLAW_STATE_DIR/workspace-openclaw-contributor"
echo "fresh workspace: $WSA"
[[ -f "$WSA/BOOTSTRAP.md" && -f "$WSA/SOUL.md" && -f "$WSA/avatars/openclaw-contributor.svg" ]]; gate "0.4.1 workspace has BOOTSTRAP, SOUL and the avatar" $?
cmp -s "$WSA/avatars/catalog.png" "$A/x/package/assets/icon.png"; gate "0.4.1 workspace avatars/catalog.png equals assets/icon.png" $?
grep -q "tools.exec.host' gateway" "$WSA/BOOTSTRAP.md"; gate "BOOTSTRAP has the exec host pin" $?
grep -q "Approval relay.*always ask" "$WSA/BOOTSTRAP.md"; gate "BOOTSTRAP asks the approval relay question" $?
DBA="$HOME/openclaw-contributor.db"; rm -f "$DBA"
( cd "$WSA" && sqlite3 -bail "$DBA" ".read references/schema.sql" && sqlite3 -bail "$DBA" ".read references/sql/setup-check.sql" && sqlite3 -bail "$DBA" ".read references/sql/tracker.sql" ) > "$A/setup-check.log" 2>&1
grep -q "setup-check ok, schema version 2" "$A/setup-check.log"; gate "0.4.1 setup self-test (setup-check ok, schema version 2)" $?
grep -q "tracker.md regenerated" "$A/setup-check.log"; gate "0.4.1 tracker step" $?
# The owner commands setup hands out, verbatim with the default agent id.
( set -e
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.host' gateway
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.mode' ask
  chmod -R a-w "$WSA/references"
  node "$OCJS" exec-policy show --agent openclaw-contributor
) > "$A/owner-commands.log" 2>&1; gate "setup owner commands (exec host pin, ask mode, chmod, exec-policy show)" $?
[[ "$(node "$OCJS" config get 'agents.entries.openclaw-contributor.tools.exec.host' 2>/dev/null | tail -1)" == *gateway* ]]; gate "config reads back exec.host gateway" $?
node "$OCJS" config validate > "$A/config-validate.log" 2>&1; gate "config validate after the owner commands" $?
[[ ! -w "$WSA/references/sql/use-approval.sql" ]]; gate "references read-only" $?

# --- B. Upgrade in place from the published 0.4.0 ---
HOME="$REAL_HOME"
B="$OUT/upgrade"; [[ -d "$B" ]] && chmod -R u+w "$B"; rm -rf "$B"; mkdir -p "$B/x40" "$B/x41"
tar xzf "$T40" -C "$B/x40"; tar xzf "$T41" -C "$B/x41"
instance "$B"
node "$OCJS" templates add "$B/x40/package" --json > "$B/add-0.4.0.json" 2>&1; gate "0.4.0 add (defaults, offline)" $?
node "$OCJS" agents list --json > "$B/agents.json" 2>&1
W="$(workspace_of "$B/agents.json" openclaw-contributor)"; [[ -z "$W" ]] && W="$OPENCLAW_STATE_DIR/workspace-openclaw-contributor"
echo "upgrade workspace: $W"
DB="$HOME/openclaw-contributor.db"
( cd "$W" && sqlite3 -bail "$DB" ".read references/schema.sql" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" ) > "$B/setup-check-0.4.0.log" 2>&1
grep -q "setup-check ok, schema version 2" "$B/setup-check-0.4.0.log"; gate "0.4.0 setup self-test" $?
# Rows like a real agent: one candidate saved through the packaged step.
( cd "$W" && printf '%s' '{"step":"save-candidate","url":"https://github.com/openclaw/openclaw/issues/1","repo":"openclaw/openclaw","number":1,"title":"t","area":"docs","now":"2026-11-14T00:00:00Z"}' > db-input.json && sqlite3 -bail -json "$DB" ".read references/sql/save-candidate.sql" ) > "$B/save-candidate.log" 2>&1
# What a live 0.4.0 workspace holds: settings with a relay, a local file, evidence, read-only references.
sed 's/^- approval_relay: .*/- approval_relay: main/' "$W/templates/settings.md" > "$W/settings.md"
printf 'local rules\n' > "$W/USER.md"
mkdir -p "$W/evidence/demo" && printf 'x\n' > "$W/evidence/demo/red.log"
chmod -R a-w "$W/references"
ROWS_BEFORE="$(sqlite3 "$DB" "SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events);")"
SET_BEFORE="$(shasum -a 256 "$W/settings.md" "$W/USER.md" "$W/evidence/demo/red.log" | cut -d' ' -f1)"
P="$B/x41/package"
(
  set -e
  cp -p "$DB" "$DB.backup"
  tar czf "$W.old-files.tgz" -C "$W" AGENTS.md SOUL.md settings.md references templates docs avatars
  chmod -R u+w "$W/references"
  cp -R "$P/references/." "$W/references/"
  cp -R "$P/templates/." "$W/templates/"
  cp "$P/workspace/AGENTS.md" "$W/AGENTS.md"
  awk 'f; /^---$/ && ++n == 2 {f = 1}' "$P/CLAW.md" > "$W/SOUL.md"
  cp "$P/README.md" "$W/docs/README.md"
  cp "$P/CHANGELOG.md" "$W/docs/CHANGELOG.md"
  cp -R "$P/examples/." "$W/docs/examples/"
  cp "$P/avatars/openclaw-contributor.svg" "$W/avatars/openclaw-contributor.svg"
  cp "$P/assets/icon.png" "$W/avatars/catalog.png"
  chmod -R a-w "$W/references"
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.host' gateway
  cd "$W" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql"
) > "$B/upgrade-steps.log" 2>&1
gate "upgrade-in-place commands ran (README, 0.4.0 to 0.4.1)" $?
grep -q "setup-check ok, schema version 2" "$B/upgrade-steps.log"; gate "setup-check after upgrade (schema version 2, no migration)" $?
ROWS_AFTER="$(sqlite3 "$DB" "SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events);")"
echo "rows before $ROWS_BEFORE after $ROWS_AFTER"
[[ "$ROWS_BEFORE" == "$ROWS_AFTER" && "$ROWS_BEFORE" != "0,0,0,0,0" ]]; gate "every DB row kept" $?
SET_AFTER="$(shasum -a 256 "$W/settings.md" "$W/USER.md" "$W/evidence/demo/red.log" | cut -d' ' -f1)"
[[ "$SET_BEFORE" == "$SET_AFTER" ]]; gate "settings.md (approval_relay: main), USER.md and evidence untouched" $?
grep -q '^- approval_relay: main' "$W/settings.md"; gate "approval_relay: main kept" $?
DIFFS=0
for f in AGENTS.md SOUL.md references templates docs avatars; do
  diff -r "$WSA/$f" "$W/$f" > "$B/diff-$f.log" 2>&1 || { DIFFS=1; echo "differs from fresh 0.4.1: $f (see diff-$f.log)"; }
done
[[ $DIFFS -eq 0 ]]; gate "upgraded packaged files equal a fresh 0.4.1 Add (AGENTS, SOUL, references, templates, docs, avatars)" $?
[[ ! -w "$W/references/sql/use-approval.sql" ]]; gate "references read-only again" $?
[[ "$(node "$OCJS" config get 'agents.entries.openclaw-contributor.tools.exec.host' 2>/dev/null | tail -1)" == *gateway* ]]; gate "upgraded agent has exec.host gateway" $?
echo "isolated add and upgrade failed=$FAIL"
exit $FAIL

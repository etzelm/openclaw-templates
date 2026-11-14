#!/bin/zsh
# Isolated Add of the built 0.4.0 package with defaults, setup self-test, and an upgrade test:
# Add 0.3.0, give it a version 1 database (a copy of real rows), then apply README "Upgrade in place"
# step by step and compare the result with the fresh 0.4.0 workspace.
# Own HOME and OPENCLAW_STATE_DIR per instance; no Gateway is started.
# Usage: isolated-add-upgrade.sh <0.4.0 tgz> <0.3.0 tgz> <v1 db copy> <out dir>
set -u -o pipefail
T04="${1:?0.4.0 tgz}"; T03="${2:?0.3.0 tgz}"; V1DB="${3:?v1 db copy}"; OUT="${4:?out dir}"
T04="${T04:A}"; T03="${T03:A}"; V1DB="${V1DB:A}"; mkdir -p "$OUT"; OUT="${OUT:A}"
OCJS="$HOME/work/occ-v04/oc/openclaw.mjs"
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }

instance() { # <dir>: sets HOME and state dir, minimal local config, no secrets
  export HOME="$1/home"; export OPENCLAW_STATE_DIR="$HOME/.openclaw"
  unset OPENCLAW_CONFIG_PATH OPENCLAW_PROFILE OPENCLAW_HOME
  mkdir -p "$OPENCLAW_STATE_DIR"
  node "$OCJS" config set gateway.mode local >/dev/null
  node "$OCJS" config set gateway.bind loopback >/dev/null
  node "$OCJS" config set gateway.controlUi.experimental.templates true >/dev/null
  # Add on current main runs an opening turn, so the instance needs a model. A local model server, no key (placeholder value).
  node "$OCJS" config set models.providers.local '{"baseUrl":"'"${LOCAL_MODEL_URL:-http://localhost:1236/v1}"'","api":"openai-completions","apiKey":"local-no-auth","timeoutSeconds":3600,"models":[{"id":"DeepSeek-V4.1-Flash-1017-oQ3e-mtp","name":"Local","api":"openai-completions","reasoning":true,"input":["text"],"contextWindow":262144}]}' --strict-json >/dev/null
  node "$OCJS" config set agents.defaults.model.primary local/DeepSeek-V4.1-Flash-1017-oQ3e-mtp >/dev/null
}
workspace_of() { # <agents.json> <id>
  node -e "const a=require('$1'); const l=Array.isArray(a)?a:(a.agents||[]); const x=l.find(e=>e.id==='$2'); console.log(x?.workspace||x?.workspaceDir||'')"
}

REAL_HOME="$HOME"

# --- A. Fresh Add of 0.4.0 with defaults ---
A="$OUT/fresh"; rm -rf "$A"; mkdir -p "$A/x"
tar xzf "$T04" -C "$A/x"
instance "$A"
node "$OCJS" templates add "$A/x/package" --dry-run --json > "$A/add-dry-run.json" 2>&1; gate "0.4.0 add --dry-run (defaults)" $?
node "$OCJS" templates add "$A/x/package" --json > "$A/add.json" 2>&1; gate "0.4.0 add (defaults, offline)" $?
node "$OCJS" agents list --json > "$A/agents.json" 2>&1
WSA="$(workspace_of "$A/agents.json" openclaw-contributor)"; [[ -z "$WSA" ]] && WSA="$OPENCLAW_STATE_DIR/workspace-openclaw-contributor"
echo "fresh workspace: $WSA"
[[ -f "$WSA/references/sql/migrate-v1-to-v2.sql" && -f "$WSA/BOOTSTRAP.md" && -f "$WSA/SOUL.md" ]]; gate "0.4.0 workspace has the migration step, BOOTSTRAP and SOUL" $?
DBA="$HOME/openclaw-contributor.db"; rm -f "$DBA"
( cd "$WSA" && sqlite3 -bail "$DBA" ".read references/schema.sql" && sqlite3 -bail "$DBA" ".read references/sql/setup-check.sql" && sqlite3 -bail "$DBA" ".read references/sql/tracker.sql" ) > "$A/setup-check.log" 2>&1
grep -q "setup-check ok, schema version 2" "$A/setup-check.log"; gate "0.4.0 setup self-test (setup-check ok, schema version 2)" $?
grep -q "tracker.md regenerated" "$A/setup-check.log"; gate "0.4.0 tracker step" $?

# --- B. Add 0.3.0, version 1 database with real rows, then upgrade in place ---
HOME="$REAL_HOME"
B="$OUT/upgrade"; [[ -d "$B" ]] && chmod -R u+w "$B"; rm -rf "$B"; mkdir -p "$B/x03" "$B/x04"
tar xzf "$T03" -C "$B/x03"; tar xzf "$T04" -C "$B/x04"
instance "$B"
node "$OCJS" templates add "$B/x03/package" --json > "$B/add-0.3.0.json" 2>&1; gate "0.3.0 add (defaults, offline)" $?
node "$OCJS" agents list --json > "$B/agents.json" 2>&1
W="$(workspace_of "$B/agents.json" openclaw-contributor)"; [[ -z "$W" ]] && W="$OPENCLAW_STATE_DIR/workspace-openclaw-contributor"
echo "upgrade workspace: $W"
DB="$HOME/openclaw-contributor.db"
cp "$V1DB" "$DB"
( cd "$W" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" ) > "$B/setup-check-0.3.0.log" 2>&1
grep -q "setup-check ok, schema version 1" "$B/setup-check-0.3.0.log"; gate "0.3.0 setup self-test on the v1 copy" $?
# What setup leaves behind in a real 0.3.0 workspace: settings, tracker, evidence, read-only references, a local file.
cp "$W/templates/settings.md" "$W/settings.md"
printf 'local rules\n' > "$W/USER.md"
mkdir -p "$W/evidence/demo" && printf 'x\n' > "$W/evidence/demo/red.log"
chmod -R a-w "$W/references"
ROWS_BEFORE="$(sqlite3 "$DB" "SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events);")"
APPR_BEFORE="$(sqlite3 "$DB" "SELECT group_concat(id||':'||action||':'||decision||':'||(used_at IS NOT NULL), ' ') FROM approvals;")"
SET_BEFORE="$(shasum -a 256 "$W/settings.md" "$W/USER.md" "$W/evidence/demo/red.log" | cut -d' ' -f1)"

# README "Upgrade in place", command by command, with <pkg>, <workspace>, <db_path> filled in.
P="$B/x04/package"
(
  set -e
  cp -p "$DB" "$DB.v1-backup"
  tar czf "$W.0.3-files.tgz" -C "$W" AGENTS.md SOUL.md settings.md references templates docs
  chmod -R u+w "$W/references"
  cp -R "$P/references/." "$W/references/"
  cp -R "$P/templates/." "$W/templates/"
  cp "$P/workspace/AGENTS.md" "$W/AGENTS.md"
  awk 'f; /^---$/ && ++n == 2 {f = 1}' "$P/CLAW.md" > "$W/SOUL.md"
  cp "$P/README.md" "$W/docs/README.md"
  cp "$P/CHANGELOG.md" "$W/docs/CHANGELOG.md"
  cp -R "$P/examples/." "$W/docs/examples/"
  chmod -R a-w "$W/references"
  sqlite3 -bail "$DB" ".read $W/references/sql/migrate-v1-to-v2.sql"
  cd "$W" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql"
) > "$B/upgrade-steps.log" 2>&1
RC=$?
gate "upgrade-in-place commands ran" $RC
grep -q "migrate ok, schema version 2" "$B/upgrade-steps.log"; gate "migration printed migrate ok, schema version 2" $?
grep -q "setup-check ok, schema version 2" "$B/upgrade-steps.log"; gate "setup-check after upgrade (schema version 2)" $?
ROWS_AFTER="$(sqlite3 "$DB" "SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events);")"
APPR_AFTER="$(sqlite3 "$DB" "SELECT group_concat(id||':'||action||':'||decision||':'||(used_at IS NOT NULL), ' ') FROM approvals;")"
echo "rows before $ROWS_BEFORE after $ROWS_AFTER"; echo "approvals before: $APPR_BEFORE"; echo "approvals after:  $APPR_AFTER"
[[ "$ROWS_BEFORE" == "$ROWS_AFTER" ]]; gate "every DB row kept" $?
[[ "$APPR_BEFORE" == "$APPR_AFTER" ]]; gate "approval decisions and use kept (no pending rows in the copy)" $?
[[ "$(sqlite3 "$DB.v1-backup" 'PRAGMA user_version;')" == "1" ]]; gate "backup is still version 1" $?
SET_AFTER="$(shasum -a 256 "$W/settings.md" "$W/USER.md" "$W/evidence/demo/red.log" | cut -d' ' -f1)"
[[ "$SET_BEFORE" == "$SET_AFTER" ]]; gate "settings.md, USER.md and evidence untouched" $?
DIFFS=0
for f in AGENTS.md SOUL.md references templates docs; do
  diff -r "$WSA/$f" "$W/$f" > "$B/diff-$f.log" 2>&1 || { DIFFS=1; echo "differs from fresh 0.4.0: $f (see diff-$f.log)"; }
done
[[ $DIFFS -eq 0 ]]; gate "upgraded packaged files equal a fresh 0.4.0 Add (AGENTS, SOUL, references, templates, docs)" $?
[[ ! -w "$W/references/sql/use-approval.sql" ]]; gate "references read-only again" $?
( cd "$W" && sqlite3 -bail "$DB" ".read references/sql/tracker.sql" ) > "$B/tracker.log" 2>&1; gate "tracker step after upgrade" $?
# The upgraded database works with the new steps.
( cd "$W" && printf '%s' '{"step":"find-candidate","url":"x","repo":"openclaw/openclaw","number":198642}' > db-input.json && sqlite3 -bail -json "$DB" ".read references/sql/find-candidate.sql" ) > "$B/find.log" 2>&1; gate "find-candidate on the upgraded database" $?
echo "isolated add and upgrade failed=$FAIL"
exit $FAIL

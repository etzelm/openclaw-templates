#!/bin/zsh
# Isolated Add of the built 0.4.2 package with defaults: setup self-test, the setup owner commands,
# the automations grant, and the commit identity and signing block on a test checkout (ssh, throwaway key).
# Then README "Upgrade in place" from the published 0.4.1 and 0.4.0 artifacts with a version 2 database
# and a relay in settings.md, compared with the fresh 0.4.2 Add.
# Own HOME and OPENCLAW_STATE_DIR per instance; no Gateway is started.
# Usage: isolated-add-042.sh <0.4.2 tgz> <0.4.1 tgz> <0.4.0 tgz> <out dir>
set -u -o pipefail
setopt NULL_GLOB
T42="${1:?0.4.2 tgz}"; T41="${2:?0.4.1 tgz}"; T40="${3:?0.4.0 tgz}"; OUT="${4:?out dir}"
T42="${T42:A}"; T41="${T41:A}"; T40="${T40:A}"; mkdir -p "$OUT"; OUT="${OUT:A}"
OCJS="${OCC_OPENCLAW_MJS:-$HOME/work/occ-v042/oc/openclaw.mjs}"
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
ROWS="SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events);"

instance() { # <dir>: own HOME and state dir, minimal local config, no secrets
  export HOME="$1/home"; export OPENCLAW_STATE_DIR="$HOME/.openclaw"
  unset OPENCLAW_CONFIG_PATH OPENCLAW_PROFILE OPENCLAW_HOME
  export GIT_CONFIG_NOSYSTEM=1
  mkdir -p "$OPENCLAW_STATE_DIR"
  node "$OCJS" config set gateway.mode local >/dev/null
  node "$OCJS" config set gateway.bind loopback >/dev/null
  node "$OCJS" config set gateway.controlUi.experimental.templates true >/dev/null
  # Add runs an opening turn, so the instance needs a model. Point it at a local OpenAI-compatible
  # server with no key: OCC_TEST_MODEL_URL (default http://127.0.0.1:8080/v1) and OCC_TEST_MODEL_ID.
  node "$OCJS" config set models.providers.local "{\"baseUrl\":\"${OCC_TEST_MODEL_URL:-http://127.0.0.1:8080/v1}\",\"api\":\"openai-completions\",\"apiKey\":\"local-no-auth\",\"timeoutSeconds\":3600,\"models\":[{\"id\":\"${OCC_TEST_MODEL_ID:?set OCC_TEST_MODEL_ID}\",\"name\":\"Local\",\"api\":\"openai-completions\",\"reasoning\":true,\"input\":[\"text\"],\"contextWindow\":262144}]}" --strict-json >/dev/null
  node "$OCJS" config set agents.defaults.model.primary "local/${OCC_TEST_MODEL_ID}" >/dev/null
}
workspace_of() { # <agents.json> <id>
  node -e "const a=require('$1'); const l=Array.isArray(a)?a:(a.agents||[]); const x=l.find(e=>e.id==='$2'); console.log(x?.workspace||x?.workspaceDir||'')"
}
REAL_HOME="$HOME"

# --- A. Fresh Add of 0.4.2 with defaults ---
A="$OUT/fresh"; [[ -d "$A" ]] && chmod -R u+w "$A"; rm -rf "$A"; mkdir -p "$A/x"
tar xzf "$T42" -C "$A/x"
instance "$A"
node "$OCJS" templates add "$A/x/package" --dry-run --json > "$A/add-dry-run.json" 2>&1; gate "0.4.2 add --dry-run (defaults)" $?
node "$OCJS" templates add "$A/x/package" --json > "$A/add.json" 2>&1; ADDRC=$?
opening_limit() { grep -q "Template opening did not complete with visible model output" "$1" && grep -rqs "embedded run timeout: runId=templates.add:openclaw-contributor:opening" "$HOME/.openclaw/logs"; }
if [[ $ADDRC -eq 0 ]]; then gate "0.4.2 add (defaults, offline)" 0
elif opening_limit "$A/add.json"; then echo "HOST LIMIT 0.4.2 add: files and config applied; the opening turn timed out on the local test model (Add then defers BOOTSTRAP.md)"
else gate "0.4.2 add (defaults, offline)" $ADDRC; fi
grep -q '"target": *"[^"]*/workspace-openclaw-contributor/BOOTSTRAP.md"' "$A/add-dry-run.json"; gate "0.4.2 Add plan writes BOOTSTRAP.md to the workspace" $?
node "$OCJS" agents list --json > "$A/agents.json" 2>&1
WSA="$(workspace_of "$A/agents.json" openclaw-contributor)"; [[ -z "$WSA" ]] && WSA="$OPENCLAW_STATE_DIR/workspace-openclaw-contributor"
echo "fresh workspace: $WSA"
[[ -f "$WSA/SOUL.md" && -f "$WSA/avatars/openclaw-contributor.svg" ]]; gate "0.4.2 workspace has SOUL and the avatar" $?
cmp -s "$WSA/avatars/catalog.png" "$A/x/package/assets/icon.png"; gate "0.4.2 workspace avatars/catalog.png equals assets/icon.png" $?
for f in references/pr-watch.js references/sql/record-grant.sql references/sql/end-grant.sql references/sql/migrate-v2-to-v3.sql templates/standing-grant.md; do
  [[ -f "$WSA/$f" ]]; gate "workspace has $f" $?
done
grep -q "## Commit identity and signing" "$A/x/package/BOOTSTRAP.md"; gate "BOOTSTRAP has the commit identity and signing step" $?
grep -q "## 12. After the PR opens" "$WSA/references/contribution-loop.md"; gate "loop has the post-open phase" $?
node "$OCJS" config get 'agents.entries.openclaw-contributor.tools' --json > "$A/tools.json" 2>&1
grep -q '"automations"' "$A/tools.json"; gate "Add grants the automations tool" $?
DBA="$HOME/openclaw-contributor.db"; rm -f "$DBA"
( cd "$WSA" && sqlite3 -bail "$DBA" ".read references/schema.sql" && sqlite3 -bail "$DBA" ".read references/sql/setup-check.sql" && sqlite3 -bail "$DBA" ".read references/sql/tracker.sql" ) > "$A/setup-check.log" 2>&1
cat "$WSA/tracker.md" >> "$A/setup-check.log"
grep -q "setup-check ok, schema version 3" "$A/setup-check.log"; gate "0.4.2 setup self-test (setup-check ok, schema version 3)" $?
grep -q "| standing grant |" "$WSA/templates/tracker.md"; gate "tracker template has the standing grant column (rows: occ-v3.test.sh)" $?
( set -e
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.host' gateway
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.mode' ask
  chmod -R a-w "$WSA/references"
  node "$OCJS" exec-policy show --agent openclaw-contributor
) > "$A/owner-commands.log" 2>&1; gate "setup owner commands (exec host pin, ask mode, chmod, exec-policy show)" $?
node "$OCJS" config validate > "$A/config-validate.log" 2>&1; gate "config validate after the owner commands" $?
[[ ! -w "$WSA/references/sql/use-approval.sql" ]]; gate "references read-only" $?

# Commit identity and signing on a test checkout, with the BOOTSTRAP ssh block and the agent's checks.
R="$WSA/openclaw"; E="12345+test-user@users.noreply.github.com"
( set -e; git init -q -b main "$R"; printf 'x\n' > "$R/f"; git -C "$R" add f
  GIT_AUTHOR_NAME=base GIT_AUTHOR_EMAIL=base@example.invalid GIT_COMMITTER_NAME=base GIT_COMMITTER_EMAIL=base@example.invalid git -C "$R" commit -q --no-gpg-sign -m base ) > "$A/sign-init.log" 2>&1
mkdir -p "$HOME/.ssh"; ssh-keygen -q -t ed25519 -N "" -C "$E" -f "$HOME/.ssh/openclaw_signing" >/dev/null
git config --global user.email "private@example.invalid"; git config --global user.name "Global Name"
TREE="$(git -C "$R" write-tree)"
C0="$(git -C "$R" commit-tree "$TREE" -m "signing test" 2>&1)"
L0="$(git -C "$R" log -1 --format='%G? %ae %ce' "$C0" 2>/dev/null)"
echo "before the block: $L0" > "$A/sign.log"
[[ "$L0" == "N private@example.invalid private@example.invalid" ]]; gate "red: without the block a commit uses the global private email, unsigned ($L0)" $?
PUB="$HOME/.ssh/openclaw_signing.pub"
( set -e
  git -C "$R" config user.name "Test User"
  git -C "$R" config user.email "$E"
  git -C "$R" config gpg.format ssh
  git -C "$R" config user.signingkey "$PUB"
  git -C "$R" config commit.gpgsign true
  printf '%s %s\n' "$E" "$(cat "$PUB")" > "$R/.git/allowed_signers"
  git -C "$R" config gpg.ssh.allowedSignersFile "$R/.git/allowed_signers"
) >> "$A/sign.log" 2>&1; gate "BOOTSTRAP ssh signing block runs" $?
O="$(git -C "$R" config --show-origin --get user.email)"; echo "origin: $O" >> "$A/sign.log"
[[ "$O" == "file:.git/config"*"$E" ]]; gate "user.email comes from the checkout's .git/config" $?
[[ "$(git -C "$R" config --get commit.gpgsign)" == "true" ]]; gate "commit.gpgsign reads true in the checkout" $?
CNS="$(git -C "$R" commit-tree "$(git -C "$R" write-tree)" -m "no -S")"
echo "commit-tree without -S: $(git -C "$R" log -1 --format='%G?' "$CNS")" >> "$A/sign.log"
C1="$(git -C "$R" commit-tree -S "$(git -C "$R" write-tree)" -m "signing test")"
L1="$(git -C "$R" log -1 --format='%G? %ae %ce' "$C1")"; echo "after: $L1" >> "$A/sign.log"
[[ "$L1" == "G $E $E" ]]; gate "green: test commit prints G and the noreply address twice ($L1)" $?
[[ -z "$(git -C "$R" branch --contains "$C1" 2>/dev/null)" && "$(git -C "$R" rev-parse HEAD)" != "$C1" ]]; gate "test commit is on no branch" $?
git -C "$R" worktree add -q -b wt-test "$WSA/wt-test" >> "$A/sign.log" 2>&1
printf 'y\n' > "$WSA/wt-test/g"; git -C "$WSA/wt-test" add g; git -C "$WSA/wt-test" commit -q -m "fix: test" >> "$A/sign.log" 2>&1
L2="$(git -C "$WSA/wt-test" log -1 --format='%G? %ae %ce')"; echo "worktree: $L2" >> "$A/sign.log"
[[ "$L2" == "G $E $E" ]]; gate "a worktree added later commits signed as the noreply author ($L2)" $?
L3="$(git -C "$WSA/wt-test" log --format='%G? %ae %ce' main..wt-test)"
[[ "$L3" == "G $E $E" ]]; gate "pre-push author check passes on the branch" $?
# Adopted worktree of an outside repo whose own config carries a private email: worktree-only block.
X="$A/outside-repo"; ( set -e; git init -q -b main "$X"; git -C "$X" config user.email "private@example.invalid"; printf 'z\n' > "$X/z"; git -C "$X" add z; git -C "$X" commit -q --no-gpg-sign -m base ) >> "$A/sign.log" 2>&1
git -C "$X" worktree add -q -b adopt "$WSA/wt-adopt" >> "$A/sign.log" 2>&1
WT="$WSA/wt-adopt"
( set -e
  git -C "$WT" config extensions.worktreeConfig true
  git -C "$WT" config --worktree user.name "Test User"
  git -C "$WT" config --worktree user.email "$E"
  git -C "$WT" config --worktree gpg.format ssh
  git -C "$WT" config --worktree user.signingkey "$PUB"
  git -C "$WT" config --worktree commit.gpgsign true
  git -C "$WT" config --worktree gpg.ssh.allowedSignersFile "$R/.git/allowed_signers"
) >> "$A/sign.log" 2>&1; gate "worktree-only identity block runs in an adopted worktree" $?
C4="$(git -C "$WT" commit-tree -S "$(git -C "$WT" write-tree)" -m "signing test")"
L4="$(git -C "$WT" log -1 --format='%G? %ae %ce' "$C4")"; echo "adopted worktree: $L4" >> "$A/sign.log"
[[ "$L4" == "G $E $E" ]]; gate "adopted worktree test commit prints G and the noreply address ($L4)" $?
[[ "$(git -C "$X" config --get user.email)" == "private@example.invalid" ]]; gate "the outside repo's own config is untouched" $?
git config --global --unset user.email; git config --global --unset user.name

# --- B. Upgrade in place from a published version with a version 2 database ---
upgrade_from() { # <label> <old tgz>
  local L="$1" TOLD="$2"
  HOME="$REAL_HOME"
  local B="$OUT/upgrade-$L"; [[ -d "$B" ]] && chmod -R u+w "$B"; rm -rf "$B"; mkdir -p "$B/xold" "$B/xnew"
  tar xzf "$TOLD" -C "$B/xold"; tar xzf "$T42" -C "$B/xnew"
  instance "$B"
  node "$OCJS" templates add "$B/xold/package" --json > "$B/add-old.json" 2>&1; local RC=$?
  if [[ $RC -eq 0 ]]; then gate "$L add (defaults, offline)" 0
  elif opening_limit "$B/add-old.json"; then echo "HOST LIMIT $L add: files and config applied; the opening turn timed out on the local test model"
  else gate "$L add (defaults, offline)" $RC; fi
  node "$OCJS" agents list --json > "$B/agents.json" 2>&1
  local W="$(workspace_of "$B/agents.json" openclaw-contributor)"; [[ -z "$W" ]] && W="$OPENCLAW_STATE_DIR/workspace-openclaw-contributor"
  local DB="$HOME/openclaw-contributor.db"
  ( cd "$W" && sqlite3 -bail "$DB" ".read references/schema.sql" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" ) > "$B/setup-check-old.log" 2>&1
  grep -q "setup-check ok, schema version 2" "$B/setup-check-old.log"; gate "$L setup self-test (version 2)" $?
  # Rows like a live agent with an open PR, written through the old version's packaged steps.
  ( cd "$W"
    s() { printf '%s' "$2" > db-input.json; sqlite3 -bail -json "$DB" ".read references/sql/$1.sql" >/dev/null; }
    s save-candidate '{"step":"save-candidate","url":"https://github.com/openclaw/openclaw/issues/1","repo":"openclaw/openclaw","number":1,"title":"t","area":"plugins","now":"2026-11-14T00:00:00Z"}'
    s set-candidate '{"step":"set-candidate","candidate_id":1,"decision":"approved","reason":"ok","now":"2026-11-14T00:00:01Z"}'
    s save-contribution '{"step":"save-contribution","candidate_id":1,"slug":"demo","branch":"fix/demo","base_sha":"05aaca51d99","now":"2026-11-14T00:00:02Z"}'
    s add-evidence '{"step":"add-evidence","contribution_id":1,"kind":"repro-red","result":"fail","now":"2026-11-14T00:00:03Z"}'
    s ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"push","exact_step":"git -C wt push fork fix/demo","head_sha":"c02af35c87d5ee62bf24c39c48eb85a702bbace4","now":"2026-11-14T00:00:04Z"}'
    s decide-approval '{"step":"decide-approval","approval_id":1,"decision":"granted","owner_words":"push signed (relayed)","now":"2026-11-14T00:00:05Z"}'
    s use-approval '{"step":"use-approval","approval_id":1,"action":"push","exact_step":"git -C wt push fork fix/demo","head_sha":"c02af35c87d5ee62bf24c39c48eb85a702bbace4","now":"2026-11-14T00:00:06Z"}'
    s approval-outcome '{"step":"approval-outcome","approval_id":1,"outcome":"pushed"}'
    s set-status '{"step":"set-status","contribution_id":1,"status":"pr-open","note":"opened","pr_url":"https://github.com/openclaw/openclaw/pull/2","head_sha":"c02af35c87d5ee62bf24c39c48eb85a702bbace4","now":"2026-11-14T00:00:07Z"}'
    s ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"edit-pr","exact_step":"gh pr edit 2 --body-file evidence/demo/pr-body.md","head_sha":"c02af35c87d5ee62bf24c39c48eb85a702bbace4","body_sha256":"'"$(printf 'a%.0s' {1..64})"'","now":"2026-11-14T00:00:08Z"}'
  ) > "$B/rows.log" 2>&1; gate "$L rows written through the old packaged steps" $?
  sed 's/^- approval_relay: .*/- approval_relay: main/' "$W/templates/settings.md" > "$W/settings.md"
  printf 'local rules\n' > "$W/USER.md"
  mkdir -p "$W/evidence/demo" && printf 'x\n' > "$W/evidence/demo/red.log"
  chmod -R a-w "$W/references"
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.mode' full >/dev/null
  local RB="$(sqlite3 "$DB" "$ROWS")"
  local SB="$(shasum -a 256 "$W/settings.md" "$W/USER.md" "$W/evidence/demo/red.log" | cut -d' ' -f1)"
  local P="$B/xnew/package"
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
    cd "$W" && sqlite3 -bail "$DB" ".read references/sql/migrate-v2-to-v3.sql"
    cd "$W" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql"
  ) > "$B/upgrade-steps.log" 2>&1
  gate "$L to 0.4.2 upgrade-in-place commands ran (README)" $?
  grep -q "migrate ok, schema version 3, approvals kept: 2, evidence kept: 1" "$B/upgrade-steps.log"; gate "$L migration to version 3 keeps approvals and evidence" $?
  grep -q "setup-check ok, schema version 3" "$B/upgrade-steps.log"; gate "$L setup-check after upgrade (version 3)" $?
  local RA="$(sqlite3 "$DB" "$ROWS")"; echo "$L rows before $RB after $RA"
  [[ "$RB" == "$RA" && "$RB" != "0,0,0,0,0" ]]; gate "$L every DB row kept ($RA)" $?
  [[ "$(sqlite3 "$DB" "SELECT group_concat(decision||':'||(used_at IS NOT NULL), ' ') FROM approvals;")" == "granted:1 pending:0" ]]; gate "$L used approval kept, pending request still pending" $?
  [[ "$(sqlite3 "$DB" "SELECT status||' '||pr_url FROM contributions;")" == "pr-open https://github.com/openclaw/openclaw/pull/2" ]]; gate "$L in-flight PR state kept" $?
  # The in-flight PR gets a standing grant after the upgrade, through the new packaged step.
  ( cd "$W" && printf '%s' '{"step":"record-grant","contribution_id":1,"actions":["push","edit-pr","request-review"],"scope":"s","stop_conditions":"c","owner_words":"I give the standing approval. (relayed)","now":"2026-11-14T00:01:00Z"}' > db-input.json && sqlite3 -bail -json "$DB" ".read references/sql/record-grant.sql" ) > "$B/grant.log" 2>&1
  grep -q '"grant_id":1' "$B/grant.log"; gate "$L record-grant works on the upgraded database" $?
  local SA="$(shasum -a 256 "$W/settings.md" "$W/USER.md" "$W/evidence/demo/red.log" | cut -d' ' -f1)"
  [[ "$SB" == "$SA" ]]; gate "$L settings.md (approval_relay: main), USER.md and evidence untouched" $?
  local DIFFS=0
  for f in AGENTS.md SOUL.md references templates docs avatars; do
    diff -r "$WSA/$f" "$W/$f" > "$B/diff-$f.log" 2>&1 || { DIFFS=1; echo "$L differs from fresh 0.4.2: $f (see diff-$f.log)"; }
  done
  [[ $DIFFS -eq 0 ]]; gate "$L upgraded packaged files equal a fresh 0.4.2 Add" $?
  [[ ! -w "$W/references/sql/use-approval.sql" ]]; gate "$L references read-only again" $?
  # README: give the agent the automations tool, keeping every tool it has.
  node "$OCJS" config get 'agents.entries.openclaw-contributor.tools.allow' --json > "$B/allow-before.json" 2>&1
  local NEWALLOW="$(node -e "const a=JSON.parse(require('fs').readFileSync('$B/allow-before.json','utf8')); if(!a.includes('automations')) a.push('automations'); console.log(JSON.stringify(a))")"
  echo "allow list: $NEWALLOW" > "$B/automations.log"
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.allow' "$NEWALLOW" --strict-json >> "$B/automations.log" 2>&1; gate "$L README automations command (allow list plus automations)" $?
  node "$OCJS" config get 'agents.entries.openclaw-contributor.tools' --json > "$B/tools.json" 2>&1
  grep -q '"automations"' "$B/tools.json" && grep -q '"web_fetch"' "$B/tools.json"; gate "$L agent has automations and keeps its tools" $?
  grep -q '"mode": *"full"' "$B/tools.json" && grep -q '"host": *"gateway"' "$B/tools.json"; gate "$L exec mode full and host gateway kept" $?
  node "$OCJS" config validate > "$B/config-validate.log" 2>&1; gate "$L config validate after upgrade" $?
}
upgrade_from 0.4.1 "$T41"
upgrade_from 0.4.0 "$T40"
echo "isolated add and upgrade failed=$FAIL"
exit $FAIL

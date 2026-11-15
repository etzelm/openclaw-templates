#!/bin/zsh
# Isolated Add of the built 0.4.4 package with defaults, plus the PR dashboard build steps from the workspace
# with a fixture gh (no GitHub call): setup self-test, the setup owner commands,
# the commit identity and signing block on a test checkout (ssh, throwaway key), and the packaged
# references/setup-worktree.sh run from the workspace on an outside repository.
# Then README "Upgrade in place" from the published 0.4.3 artifact with a live-shaped version 3 database
# (open and ended standing grants, granted uses, an in-flight PR), exec mode full, runner_prefix and a relay,
# compared with the fresh 0.4.4 Add.
# Own HOME and OPENCLAW_STATE_DIR per instance; no Gateway is started.
# Usage: isolated-add-044.sh <0.4.4 tgz> <0.4.3 tgz> <out dir> [<v3 schema dump>]
# The optional schema dump is `.schema` output from a database that reached version 3 through the
# packaged migrations (no rows); without it the 0.4.3 schema.sql is used.
set -u -o pipefail
setopt NULL_GLOB
T44="${1:?0.4.4 tgz}"; T43="${2:?0.4.3 tgz}"; OUT="${3:?out dir}"; SCHEMA="${4:-}"
T44="${T44:A}"; T43="${T43:A}"; mkdir -p "$OUT"; OUT="${OUT:A}"; [[ -n "$SCHEMA" ]] && SCHEMA="${SCHEMA:A}"
OCJS="${OCC_OPENCLAW_MJS:-$HOME/work/occ-v044/oc/openclaw.mjs}"
FAIL=0
gate() { if [[ $2 -eq 0 ]]; then echo "GATE PASS $1"; else echo "GATE FAIL $1 (rc=$2)"; FAIL=1; fi; }
ROWS="SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events)||','||(SELECT count(*) FROM grants)||','||(SELECT count(*) FROM grants WHERE ended_at IS NULL);"

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
# Add ends with an opening turn on the instance's model. With no usable test model (for example
# OCC_TEST_MODEL_URL pointing at a closed port) the opening fails after the files and config are applied,
# and Add defers BOOTSTRAP.md. That is a host limit, reported as such; the gates below check the files.
opening_limit() { grep -q "Template opening did not complete\|Couldn't connect to the AI service" "$1" && grep -q "The agent was already made available and was kept\|Template opening did not complete" "$1"; }
REAL_HOME="$HOME"
# Fixture gh for the dashboard build: answers api user and the two GraphQL reads, never calls GitHub.
FGH="$OUT/fake-gh"; rm -rf "$FGH"; mkdir -p "$FGH"
cat > "$FGH/gh" <<'GH'
#!/usr/bin/env node
const a = process.argv.slice(2);
if (a[0] === "api" && a[1] === "user") { process.stdout.write("test-user\n"); process.exit(0); }
if (a[0] !== "api" || a[1] !== "graphql") { process.stderr.write("fixture gh: not a read"); process.exit(2); }
const ci = a.some((x) => x.includes("ci.graphql"));
const pr = { number: 7, title: "fix(core): demo", url: "https://github.com/openclaw/openclaw/pull/7", state: "OPEN", merged: false,
  updatedAt: "2026-11-14T10:00:00Z", isDraft: false, mergeStateStatus: "CLEAN", labels: { nodes: [{ name: "P2" }] } };
const data = ci ? { rateLimit: { cost: 1, remaining: 4998 }, open: { nodes: [{ number: 7, url: pr.url, commits: { nodes: [] } }] } }
  : { rateLimit: { cost: 1, remaining: 4999 }, open: { nodes: [pr] }, closed: { nodes: [] } };
process.stdout.write(JSON.stringify({ data }));
GH
chmod +x "$FGH/gh"
dash_build() { # <workspace> <log>: the setup build step, run the way the agent runs it
  ( cd "$1" && PATH="$FGH:$PATH" node "$1/references/pr-dashboard/build.mjs" ) >> "$2" 2>&1
}

# --- A. Fresh Add of 0.4.4 with defaults ---
A="$OUT/fresh"; [[ -d "$A" ]] && chmod -R u+w "$A"; rm -rf "$A"; mkdir -p "$A/x"
tar xzf "$T44" -C "$A/x"
instance "$A"
node "$OCJS" templates add "$A/x/package" --dry-run --json > "$A/add-dry-run.json" 2>&1; gate "0.4.4 add --dry-run (defaults)" $?
node "$OCJS" templates add "$A/x/package" --json > "$A/add.json" 2>&1; ADDRC=$?
if [[ $ADDRC -eq 0 ]]; then gate "0.4.4 add (defaults, offline)" 0
elif opening_limit "$A/add.json"; then echo "HOST LIMIT 0.4.4 add: files and config applied; the opening turn did not complete on the test model (Add then defers BOOTSTRAP.md)"
else gate "0.4.4 add (defaults, offline)" $ADDRC; fi
grep -q '"target": *"[^"]*/workspace-openclaw-contributor/BOOTSTRAP.md"' "$A/add-dry-run.json"; gate "0.4.4 Add plan writes BOOTSTRAP.md to the workspace" $?
node "$OCJS" agents list --json > "$A/agents.json" 2>&1
WSA="$(workspace_of "$A/agents.json" openclaw-contributor)"; [[ -z "$WSA" ]] && WSA="$OPENCLAW_STATE_DIR/workspace-openclaw-contributor"
echo "fresh workspace: $WSA"
[[ -f "$WSA/SOUL.md" && -f "$WSA/avatars/openclaw-contributor.svg" ]]; gate "0.4.4 workspace has SOUL and the avatar" $?
cmp -s "$WSA/avatars/catalog.png" "$A/x/package/assets/icon.png"; gate "0.4.4 workspace avatars/catalog.png equals assets/icon.png" $?
for f in references/proof.md references/setup-worktree.sh templates/runtime-output.md references/pr-watch.js references/sql/record-grant.sql templates/standing-grant.md references/pr-dashboard/build.mjs references/pr-dashboard/template.html references/pr-dashboard/prs.graphql references/pr-dashboard/ci.graphql references/pr-dashboard/refresh-trigger.js; do
  [[ -f "$WSA/$f" ]]; gate "workspace has $f" $?
done
grep -q "### Runtime output" "$WSA/references/contribution-loop.md"; gate "workspace loop has the Runtime output rule" $?
grep -q 'const addedAt = "";' "$WSA/references/pr-watch.js"; gate "workspace watcher has the addedAt line" $?
node "$OCJS" config get 'agents.entries.openclaw-contributor.tools' --json > "$A/tools.json" 2>&1
grep -q '"automations"' "$A/tools.json"; gate "Add grants the automations tool" $?
grep -q '"show_widget"' "$A/tools.json"; gate "Add grants the show_widget tool" $?
grep -q "## PR dashboard" "$WSA/AGENTS.md" && grep -q "pr-dashboard-refresh" "$WSA/SOUL.md"; gate "workspace AGENTS.md and SOUL.md carry the PR dashboard steps" $?
DBA="$HOME/openclaw-contributor.db"; rm -f "$DBA"
( cd "$WSA" && sqlite3 -bail "$DBA" ".read references/schema.sql" && sqlite3 -bail "$DBA" ".read references/sql/setup-check.sql" && sqlite3 -bail "$DBA" ".read references/sql/tracker.sql" ) > "$A/setup-check.log" 2>&1
cat "$WSA/tracker.md" >> "$A/setup-check.log"
grep -q "setup-check ok, schema version 3" "$A/setup-check.log"; gate "0.4.4 setup self-test (setup-check ok, schema version 3)" $?
( set -e
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.host' gateway
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.mode' ask
  chmod -R a-w "$WSA/references"
  node "$OCJS" exec-policy show --agent openclaw-contributor
) > "$A/owner-commands.log" 2>&1; gate "setup owner commands (exec host pin, ask mode, chmod, exec-policy show)" $?
node "$OCJS" config validate > "$A/config-validate.log" 2>&1; gate "config validate after the owner commands" $?
[[ ! -w "$WSA/references/sql/use-approval.sql" && ! -w "$WSA/references/setup-worktree.sh" && ! -w "$WSA/references/pr-dashboard/build.mjs" ]]; gate "references read-only (setup-worktree.sh and the dashboard builder included)" $?
# PR dashboard setup step 1, from the workspace, after references are read-only: settings.md from the template.
cp "$WSA/templates/settings.md" "$WSA/settings.md"
dash_build "$WSA" "$A/dashboard.log"; R1=$?
L1d="$(tail -1 "$A/dashboard.log")"
[[ $R1 -eq 0 && "$L1d" == "CHANGED rows=1 cost=2 remaining=4998" ]]; gate "dashboard step 1 builds in the workspace with read-only references ($L1d)" $?
[[ -s "$WSA/dashboard/widget.html" && -s "$WSA/dashboard/data.json" ]] && grep -q "const JOB='';" "$WSA/dashboard/widget.html"; gate "dashboard/widget.html and data.json written, no job id yet" $?
dash_build "$WSA" "$A/dashboard.log"; L2d="$(tail -1 "$A/dashboard.log")"
[[ "$L2d" == CHANGED* ]]; gate "not pinned yet: re-running step 1 still prints CHANGED ($L2d)" $?
( cd "$WSA" && node "$WSA/references/pr-dashboard/build.mjs" --mark-pinned ) >> "$A/dashboard.log" 2>&1; LPd="$(tail -1 "$A/dashboard.log")"
[[ "$LPd" == PINNED* && -s "$WSA/dashboard/pinned.txt" ]]; gate "step 2 records the pin with --mark-pinned ($LPd)" $?
dash_build "$WSA" "$A/dashboard.log"; L3d="$(tail -1 "$A/dashboard.log")"
[[ "$L3d" == UNCHANGED* ]]; gate "after the pin, re-running step 1 prints UNCHANGED ($L3d)" $?
printf '%s\n' "0f8a3c2e-1111-4222-8333-944455556666" > "$WSA/dashboard/jobid.txt"
dash_build "$WSA" "$A/dashboard.log"
grep -q "const JOB='';" "$WSA/dashboard/widget.html"; gate "Refresh button off by default: the job id stays out of the widget" $?
sed -i.bak 's/^- dashboard_refresh_button: off$/- dashboard_refresh_button: on/' "$WSA/settings.md" && rm -f "$WSA/settings.md.bak"
dash_build "$WSA" "$A/dashboard.log"
grep -q "const JOB='0f8a3c2e-1111-4222-8333-944455556666';" "$WSA/dashboard/widget.html" && [[ "$(tail -1 "$A/dashboard.log")" == UNCHANGED* ]]; gate "Refresh button on: the job id is in the widget, digest unchanged" $?
! grep -qE "$WSA|/Users/|/home/[a-z]|fetch\(|XMLHttpRequest|WebSocket|api\.github\.com|data\.read|workboard" "$WSA/dashboard/widget.html"; gate "built widget names no path and makes no network or data call" $?
# The refresh check, with the workspace line filled in, run the way the trigger runtime does.
node --input-type=module -e '
import { readFileSync } from "node:fs"; import { spawnSync } from "node:child_process";
const [ws, fgh] = process.argv.slice(1);
const src = readFileSync(ws + "/references/pr-dashboard/refresh-trigger.js", "utf8").replace("const workspace = \"\";", "const workspace = " + JSON.stringify(ws) + ";");
const AF = Object.getPrototypeOf(async function () {}).constructor;
const exec = async ({ command }) => { const [c, ...args] = command.split(" "); const p = spawnSync(c, args, { encoding: "utf8", env: { ...process.env, PATH: fgh + ":" + process.env.PATH } }); return { status: "completed", exitCode: p.status, aggregated: (p.stdout || "") + (p.stderr || "") }; };
const r = await new AF("exec", "trigger", src)(exec, { state: undefined });
console.log(JSON.stringify(r)); process.exit(r.fire === false && r.state.last.startsWith("UNCHANGED") ? 0 : 1);
' "$WSA" "$FGH" > "$A/refresh-check.log" 2>&1; gate "refresh check from the workspace: UNCHANGED starts no model turn" $?

# Commit identity and signing on a test checkout, with the BOOTSTRAP ssh block and the agent's checks.
R="$WSA/openclaw"; E="12345+test-user@users.noreply.github.com"
( set -e; git init -q -b main "$R"; printf 'x\n' > "$R/f"; git -C "$R" add f
  GIT_AUTHOR_NAME=base GIT_AUTHOR_EMAIL=base@example.invalid GIT_COMMITTER_NAME=base GIT_COMMITTER_EMAIL=base@example.invalid git -C "$R" commit -q --no-gpg-sign -m base ) > "$A/sign-init.log" 2>&1
mkdir -p "$HOME/.ssh"; ssh-keygen -q -t ed25519 -N "" -C "$E" -f "$HOME/.ssh/openclaw_signing" >/dev/null
git config --global user.email "private@example.invalid"; git config --global user.name "Global Name"
PUB="$HOME/.ssh/openclaw_signing.pub"
( set -e
  git -C "$R" config user.name "Test User"
  git -C "$R" config user.email "$E"
  git -C "$R" config gpg.format ssh
  git -C "$R" config user.signingkey "$PUB"
  git -C "$R" config commit.gpgsign true
  printf '%s %s\n' "$E" "$(cat "$PUB")" > "$R/.git/allowed_signers"
  git -C "$R" config gpg.ssh.allowedSignersFile "$R/.git/allowed_signers"
) > "$A/sign.log" 2>&1; gate "BOOTSTRAP ssh signing block runs" $?
C1="$(git -C "$R" commit-tree -S "$(git -C "$R" write-tree)" -m "signing test")"
L1="$(git -C "$R" log -1 --format='%G? %ae %ce' "$C1")"; echo "checkout: $L1" >> "$A/sign.log"
[[ "$L1" == "G $E $E" ]]; gate "checkout test commit prints G and the noreply address twice ($L1)" $?

# The packaged worktree script, run the way the agent runs it: one command from the workspace root,
# against a repository outside the workspace whose own config carries a private email.
X="$A/outside-repo"; ( set -e; git init -q -b main "$X"; git -C "$X" config user.email "private@example.invalid"; printf 'z\n' > "$X/z"; git -C "$X" add z; git -C "$X" commit -q --no-gpg-sign -m base ) >> "$A/sign.log" 2>&1
( cd "$WSA" && sh references/setup-worktree.sh --repo "$X" --worktree "$WSA/wt-demo" --start main --branch fix/demo --name "Test User" --email "$E" --signing ssh --key "$PUB" ) > "$A/setup-worktree.log" 2>&1
gate "workspace setup-worktree.sh runs in one command ($(tail -1 "$A/setup-worktree.log"))" $?
grep -q "setup-worktree ok: $WSA/wt-demo; test commit .* on no branch; G $E $E" "$A/setup-worktree.log"; gate "setup-worktree.sh self-check prints G and the noreply address twice" $?
printf 'y\n' > "$WSA/wt-demo/g"; git -C "$WSA/wt-demo" add g; git -C "$WSA/wt-demo" commit -q -m "fix: demo" >> "$A/sign.log" 2>&1
L4="$(git -C "$WSA/wt-demo" log --format='%G? %ae %ce' main..fix/demo)"; echo "script worktree: $L4" >> "$A/sign.log"
[[ "$L4" == "G $E $E" ]]; gate "pre-push author check passes in the script's worktree ($L4)" $?
[[ "$(git -C "$X" config --get user.email)" == "private@example.invalid" ]]; gate "the outside repo's own config is untouched" $?
( cd "$WSA" && sh references/setup-worktree.sh --repo "$X" --worktree "$WSA/wt-bad" --start main --branch fix/bad --name "Test User" --email "private@example.invalid" --signing ssh --key "$PUB" ) > "$A/setup-worktree-bad.log" 2>&1
[[ $? -ne 0 && ! -e "$WSA/wt-bad" ]]; gate "setup-worktree.sh refuses a private email and makes nothing" $?
git config --global --unset user.email; git config --global --unset user.name

# --- B. Upgrade in place from 0.4.3 with a live-shaped version 3 database ---
HOME="$REAL_HOME"
B="$OUT/upgrade-0.4.3"; [[ -d "$B" ]] && chmod -R u+w "$B"; rm -rf "$B"; mkdir -p "$B/xold" "$B/xnew"
tar xzf "$T43" -C "$B/xold"; tar xzf "$T44" -C "$B/xnew"
instance "$B"
node "$OCJS" templates add "$B/xold/package" --json > "$B/add-old.json" 2>&1; RC=$?
if [[ $RC -eq 0 ]]; then gate "0.4.3 add (defaults, offline)" 0
elif opening_limit "$B/add-old.json"; then echo "HOST LIMIT 0.4.3 add: files and config applied; the opening turn did not complete on the test model"
else gate "0.4.3 add (defaults, offline)" $RC; fi
node "$OCJS" agents list --json > "$B/agents.json" 2>&1
W="$(workspace_of "$B/agents.json" openclaw-contributor)"; [[ -z "$W" ]] && W="$OPENCLAW_STATE_DIR/workspace-openclaw-contributor"
DB="$HOME/openclaw-contributor.db"
if [[ -n "$SCHEMA" ]]; then
  ( sqlite3 -bail "$DB" ".read $SCHEMA" && sqlite3 "$DB" "PRAGMA user_version = 3;" ) > "$B/schema.log" 2>&1; gate "copy-shaped database from the migrated version 3 schema dump" $?
else
  ( cd "$W" && sqlite3 -bail "$DB" ".read references/schema.sql" ) > "$B/schema.log" 2>&1; gate "version 3 database from the 0.4.3 schema" $?
fi
( cd "$W" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" ) > "$B/setup-check-old.log" 2>&1
grep -q "setup-check ok, schema version 3" "$B/setup-check-old.log"; gate "0.4.3 setup self-test on it (version 3)" $?
# Rows shaped like the live agent's: 6 candidates, 5 contributions (three PRs open, one in review,
# one scoped), evidence, approvals, and 4 grants of which 2 are open, written through the 0.4.3 steps.
H() { printf '%040d' "$1" | tr '0' "$2"; }
( cd "$W"
  set -e
  s() { printf '%s' "$2" > db-input.json; sqlite3 -bail -json "$DB" ".read references/sql/$1.sql" > /dev/null; }
  t() { printf '"now":"2026-11-14T%s:00Z"' "$1"; }
  for i in 1 2 3 4 5 6; do
    s save-candidate '{"step":"save-candidate","url":"https://github.com/openclaw/openclaw/issues/'$i'","repo":"openclaw/openclaw","number":'$i',"title":"t'$i'","area":"core",'"$(t 10:0$i)"'}'
  done
  for i in 1 2 3 4 5; do
    s set-candidate '{"step":"set-candidate","candidate_id":'$i',"decision":"approved","reason":"ok",'"$(t 10:1$i)"'}'
    s save-contribution '{"step":"save-contribution","candidate_id":'$i',"slug":"c'$i'","branch":"fix/c'$i'","base_sha":"05aaca51d99",'"$(t 10:2$i)"'}'
  done
  s set-candidate '{"step":"set-candidate","candidate_id":6,"decision":"duplicate","reason":"fixed by a merged PR",'"$(t 10:30)"'}'
  for i in 1 2 3 4; do
    HD="$(H $i a)"
    s add-evidence '{"step":"add-evidence","contribution_id":'$i',"kind":"repro-red","result":"fail","commit_sha":"05aaca51d99",'"$(t 11:0$i)"'}'
    s add-evidence '{"step":"add-evidence","contribution_id":'$i',"kind":"fix-green","result":"pass","commit_sha":"'$HD'",'"$(t 11:1$i)"'}'
    s ask-approval '{"step":"ask-approval","candidate_id":'$i',"contribution_id":'$i',"action":"push","exact_step":"git -C wt-c'$i' push fork fix/c'$i'","head_sha":"'$HD'",'"$(t 11:2$i)"'}'
    A1=$((i * 3 - 2))
    s decide-approval '{"step":"decide-approval","approval_id":'$A1',"decision":"granted","owner_words":"yes (relayed by main)",'"$(t 11:3$i)"'}'
    s use-approval '{"step":"use-approval","approval_id":'$A1',"action":"push","exact_step":"git -C wt-c'$i' push fork fix/c'$i'","head_sha":"'$HD'",'"$(t 11:4$i)"'}'
    s approval-outcome '{"step":"approval-outcome","approval_id":'$A1',"outcome":"pushed"}'
    s set-status '{"step":"set-status","contribution_id":'$i',"status":"pr-open","note":"opened","pr_url":"https://github.com/openclaw/openclaw/pull/10'$i'","head_sha":"'$HD'",'"$(t 11:5$i)"'}'
    s record-grant '{"step":"record-grant","contribution_id":'$i',"actions":["push","edit-pr","request-review"],"scope":"s","stop_conditions":"c","owner_words":"I give the standing approval. (relayed)",'"$(t 12:0$i)"'}'
    s ask-approval '{"step":"ask-approval","candidate_id":'$i',"contribution_id":'$i',"action":"request-review","exact_step":"gh pr comment 10'$i' --repo openclaw/openclaw --body-file references/re-review.md","head_sha":"'$HD'","body_sha256":"'"$(shasum -a 256 references/re-review.md | cut -d' ' -f1)"'",'"$(t 12:1$i)"'}'
    s decide-approval '{"step":"decide-approval","approval_id":'$((A1 + 1))',"decision":"granted","grant_id":'$i',"owner_words":"standing grant '$i'",'"$(t 12:2$i)"'}'
    s ask-approval '{"step":"ask-approval","candidate_id":'$i',"contribution_id":'$i',"action":"push","exact_step":"git -C wt-c'$i' push fork fix/c'$i'","head_sha":"'"$(H $i b)"'",'"$(t 12:3$i)"'}'
  done
  s end-grant '{"step":"end-grant","grant_id":1,"end_reason":"target reached",'"$(t 13:01)"'}'
  s set-status '{"step":"set-status","contribution_id":1,"status":"in-review","note":"ready for maintainer look",'"$(t 13:02)"'}'
  s end-grant '{"step":"end-grant","grant_id":3,"end_reason":"owner ended it",'"$(t 13:03)"'}'
  s add-evidence '{"step":"add-evidence","contribution_id":2,"kind":"hosted-review","result":"info","commit_sha":"'"$(H 2 a)"'","note":"hosted round 1; rating 2/2/4; must-fix 0; labels status: needs proof",'"$(t 13:04)"'}'
) > "$B/rows.log" 2>&1; gate "live-shaped rows written through the 0.4.3 packaged steps" $?
# Settings like the live agent: relay, runner prefix, signing, exec mode full.
sed -e 's/^- approval_relay: .*/- approval_relay: main/' -e 's|^- runner_prefix: .*|- runner_prefix: runner run --|' \
    -e 's/^- commit_email: .*/- commit_email: 12345+test-user@users.noreply.github.com/' "$W/templates/settings.md" > "$W/settings.md"
printf 'local rules\n' > "$W/USER.md"
mkdir -p "$W/evidence/c2" && printf 'x\n' > "$W/evidence/c2/red.log"
chmod -R a-w "$W/references"
node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.mode' full >/dev/null
node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.exec.host' gateway >/dev/null
node "$OCJS" config get 'agents.entries.openclaw-contributor' --json > "$B/agent-config-before.json" 2>&1
RB="$(sqlite3 "$DB" "$ROWS")"; echo "rows before: $RB" > "$B/rows-summary.log"
DUMPB="$(sqlite3 "$DB" .dump | shasum -a 256 | cut -d' ' -f1)"
SLINES="$(wc -l < "$W/settings.md" | tr -d ' ')"
SB="$(head -n "$SLINES" "$W/settings.md" | shasum -a 256 | cut -d' ' -f1; shasum -a 256 "$W/USER.md" "$W/evidence/c2/red.log" | cut -d' ' -f1)"
P="$B/xnew/package"
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
gate "0.4.3 to 0.4.4 upgrade-in-place commands ran (README, migration line left out)" $?
# README "Then, for 0.4.4": settings lines and show_widget in tools.allow.
( set -e
  printf -- '\n## PR dashboard\n\n- dashboard: on\n- dashboard_note: <blank>\n- dashboard_author: <blank>\n- dashboard_org: openclaw\n- dashboard_refresh_button: off\n' >> "$W/settings.md"
  CUR="$(node "$OCJS" config get 'agents.entries.openclaw-contributor.tools.allow' --json)"
  NEW="$(node -e 'const l=JSON.parse(process.argv[1]); if(!l.includes("show_widget")) l.push("show_widget"); console.log(JSON.stringify(l))' "$CUR")"
  echo "tools.allow before: $CUR"; echo "tools.allow after: $NEW"
  node "$OCJS" config set 'agents.entries.openclaw-contributor.tools.allow' "$NEW" --strict-json
) > "$B/upgrade-044.log" 2>&1; gate "0.4.4 upgrade steps ran (settings lines, show_widget added to tools.allow)" $?
dash_build "$W" "$B/dashboard.log"; [[ "$(tail -1 "$B/dashboard.log")" == CHANGED* ]]; gate "dashboard builds in the upgraded workspace ($(tail -1 "$B/dashboard.log"))" $?
grep -q "setup-check ok, schema version 3" "$B/upgrade-steps.log"; gate "setup-check after upgrade (version 3)" $?
( cd "$W" && sqlite3 -bail "$DB" ".read references/sql/migrate-v2-to-v3.sql" ) > "$B/migrate-refused.log" 2>&1
[[ $? -ne 0 ]]; gate "the v2 to v3 migration refuses the version 3 database (README: leave it out)" $?
RA="$(sqlite3 "$DB" "$ROWS")"; echo "rows after: $RA" >> "$B/rows-summary.log"
DUMPA="$(sqlite3 "$DB" .dump | shasum -a 256 | cut -d' ' -f1)"
[[ "$RB" == "$RA" && "$RB" == 6,5,* ]]; gate "every DB row kept ($RA: candidates, contributions, evidence, approvals, status events, grants, open grants)" $?
[[ "$DUMPB" == "$DUMPA" ]]; gate "database content byte-identical after the upgrade (dump sha256)" $?
[[ "$(sqlite3 "$DB" "SELECT group_concat(id, ',') FROM grants WHERE ended_at IS NULL;")" == "2,4" ]]; gate "the two open standing grants stay open" $?
[[ "$(sqlite3 "$DB" "SELECT count(*) FROM approvals WHERE decision = 'pending';")" == "4" ]]; gate "pending requests stay pending" $?
# The in-flight PR keeps working under its grant after the upgrade, through the 0.4.4 steps.
( cd "$W" && set -e
  printf '%s' '{"step":"decide-approval","approval_id":6,"decision":"granted","grant_id":2,"owner_words":"standing grant 2","now":"2026-11-14T14:00:00Z"}' > db-input.json
  sqlite3 -bail -json "$DB" ".read references/sql/decide-approval.sql"
  printf '%s' '{"step":"use-approval","approval_id":6,"action":"push","exact_step":"git -C wt-c2 push fork fix/c2","head_sha":"'"$(H 2 b)"'","now":"2026-11-14T14:01:00Z"}' > db-input.json
  sqlite3 -bail -json "$DB" ".read references/sql/use-approval.sql"
) > "$B/grant-use.log" 2>&1; gate "a push under open grant 2 is granted and used after the upgrade" $?
( cd "$W" && printf '%s' '{"step":"decide-approval","approval_id":9,"decision":"granted","grant_id":3,"owner_words":"standing grant 3","now":"2026-11-14T14:02:00Z"}' > db-input.json && sqlite3 -bail -json "$DB" ".read references/sql/decide-approval.sql" ) > "$B/grant-ended.log" 2>&1
[[ $? -ne 0 ]]; gate "an ended grant still refuses a use after the upgrade" $?
SA="$(head -n "$SLINES" "$W/settings.md" | shasum -a 256 | cut -d' ' -f1; shasum -a 256 "$W/USER.md" "$W/evidence/c2/red.log" | cut -d' ' -f1)"
[[ "$SB" == "$SA" ]]; gate "settings.md (approval_relay, runner_prefix; only the dashboard lines appended), USER.md and evidence untouched" $?
grep -q '^- runner_prefix: runner run --$' "$W/settings.md" && grep -q '^- approval_relay: main$' "$W/settings.md"; gate "runner_prefix and approval_relay kept" $?
node "$OCJS" config get 'agents.entries.openclaw-contributor' --json > "$B/agent-config-after.json" 2>&1
node -e 'const a=require(process.argv[1]), b=require(process.argv[2]); const al=(a.tools&&a.tools.allow)||[], bl=(b.tools&&b.tools.allow)||[]; const ok=JSON.stringify([...al,"show_widget"])===JSON.stringify(bl); a.tools.allow=bl; process.exit(ok && JSON.stringify(a)===JSON.stringify(b) ? 0 : 1)' "$B/agent-config-before.json" "$B/agent-config-after.json"; gate "agent config unchanged by the upgrade except show_widget added (exec full, host gateway, automations kept)" $?
grep -q '"mode": *"full"' "$B/agent-config-after.json" && grep -q '"host": *"gateway"' "$B/agent-config-after.json" && grep -q '"automations"' "$B/agent-config-after.json" && grep -q '"show_widget"' "$B/agent-config-after.json"; gate "exec mode full, host gateway, automations and show_widget" $?
DIFFS=0
for f in AGENTS.md SOUL.md references templates docs avatars; do
  diff -r "$WSA/$f" "$W/$f" > "$B/diff-$f.log" 2>&1 || { DIFFS=1; echo "upgrade differs from fresh 0.4.4: $f (see diff-$f.log)"; }
done
[[ $DIFFS -eq 0 ]]; gate "upgraded packaged files equal a fresh 0.4.4 Add" $?
[[ ! -w "$W/references/sql/use-approval.sql" ]]; gate "references read-only again" $?
printf -- '- commit_name: Test User\n- signing_key: /absolute/path/key.pub\n' >> "$W/settings.md"
( cd "$W" && sqlite3 -bail "$DB" ".read references/sql/setup-check.sql" ) > "$B/setup-check-final.log" 2>&1
grep -q "setup-check ok, schema version 3" "$B/setup-check-final.log"; gate "setup-check after adding the new settings lines" $?
node "$OCJS" config validate > "$B/config-validate.log" 2>&1; gate "config validate after upgrade" $?
echo "isolated add and upgrade failed=$FAIL"
exit $FAIL

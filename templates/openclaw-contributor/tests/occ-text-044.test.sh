#!/bin/zsh
# 0.4.4: the PR dashboard ships, and its setup text is idempotent, generic and read only.
# Red on 0.4.3 (no dashboard, no show_widget, no settings keys), green on 0.4.4.
# Usage: occ-text-044.test.sh <package dir>
set -u
P="${1:?package dir}"; P="${P:A}"
A="workspace/AGENTS.md"
PASSES=0; FAILS=0
has() { if grep -qF -- "$3" "$P/$2" 2>/dev/null; then PASSES=$((PASSES + 1)); echo "PASS $1"; else FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 lacks: $3"; fi; }
lacks() { if grep -qE -- "$3" "$P/$2" 2>/dev/null; then FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 has: $3"; else PASSES=$((PASSES + 1)); echo "PASS $1"; fi; }
listed() { if grep -qF -- "source: $2" "$P/CLAW.md" && grep -qF -- "path: $2" "$P/CLAW.md" && [[ -f "$P/$2" ]]; then PASSES=$((PASSES + 1)); echo "PASS $1"; else FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 not shipped"; fi; }
count() { local n; n=$(grep -cF -- "$3" "$P/$2" 2>/dev/null); if [[ "$n" == "$4" ]]; then PASSES=$((PASSES + 1)); echo "PASS $1"; else FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 has $n of: $3 (want $4)"; fi; }
ok() { if eval "$2"; then PASSES=$((PASSES + 1)); echo "PASS $1"; else FAILS=$((FAILS + 1)); echo "FAIL $1"; fi; }

# 1. Files and tools
for f in build.mjs template.html prs.graphql ci.graphql refresh-trigger.js; do listed "ships references/pr-dashboard/$f" "references/pr-dashboard/$f"; done
has "Template grants show_widget" CLAW.md '      - show_widget'
has "Template still grants automations" CLAW.md '      - automations'
ok "no Python anywhere in the package" '[[ -z "$(find "$P" -name "*.py" -print -quit)" ]] && ! grep -rqE "python3?( |$)" "$P/references" "$P/workspace" "$P/CLAW.md" "$P/BOOTSTRAP.md"'
has "settings: dashboard on by default" templates/settings.md '- dashboard: on'
has "settings: dashboard_author defaults to the gh login" templates/settings.md '- dashboard_author: <blank>'
has "settings: dashboard_org defaults to openclaw" templates/settings.md '- dashboard_org: openclaw'
has "settings: dashboard_note for the opt-out" templates/settings.md '- dashboard_note: <blank>'

# 2. Setup steps in order, in CLAW.md and AGENTS.md
has "CLAW.md names the three setup steps" CLAW.md '(1) build the widget with `node <workspace>/references/pr-dashboard/build.mjs`, (2) pin `dashboard/widget.html` with `show_widget`'
has "CLAW.md: create the automation only if the list lacks it" CLAW.md '(3) create the one refresh automation (declarationKey `pr-dashboard-refresh`) if your automation list does not already have it'
has "AGENTS.md has the PR dashboard section" "$A" '## PR dashboard'
has "AGENTS.md: steps are safe to repeat" "$A" '### Set it up (setup, and safe to repeat)'
has "AGENTS.md: re-running never makes a second one" "$A" 'Re-running them updates the same widget and the same automation; they never make a second one.'
has "step 1 builds with one plain command" "$A" '1. Build. Run `node <workspace>/references/pr-dashboard/build.mjs`'
has "step 2 pins under a fixed name" "$A" '2. Pin. Read `dashboard/widget.html` to the end. Call `show_widget` with `name` `openclaw-prs`'
has "step 2: same name replaces in place" "$A" 'The same `name` replaces the widget in place.'
has "step 2: byte for byte" "$A" 'the exact, complete file, byte for byte'
has "step 2: record the pin only when pinned" "$A" 'When the tool result says the widget is pinned, run `node <workspace>/references/pr-dashboard/build.mjs --mark-pinned`'
has "step 2: a failed pin is not marked" "$A" 'If it fails, do not mark it pinned'
has "refresh turn records the pin" "$A" '4. Only if show_widget says the widget is pinned, run: node <workspace>/references/pr-dashboard/build.mjs --mark-pinned .'
has "CHANGED means differs from the last pin" "$A" '`CHANGED ...` (the widget differs from the last one you pinned)'
has "step 2: no network origins" "$A" 'Never add `netOrigins` or any other tool.'
has "step 3 lists before adding" "$A" "3. Refresh automation. Run the \`automations\` tool's \`list\` action first."
has "step 3: found one, do not add another" "$A" 'Found one: do not add another.'
has "step 3: update in place" "$A" 'update that automation in place'
has "step 3: duplicates are removed" "$A" 'remove the others, and tell the owner'
has "step 3: job id file" "$A" 'Write its id, and nothing else, to `dashboard/jobid.txt`.'
has "setup needs a Control UI turn" "$A" 'Do this in an interactive turn in the Control UI'
has "no show_widget: set nothing up, tell the owner" "$A" 'If `show_widget` is not in your tools in this turn, do not set anything up'
has "step 3: add refused, stop" "$A" 'If `add` refuses, tell the owner the exact error and stop here.'
has "Refresh button on: re-pin with the capability" "$A" 'If `dashboard_refresh_button` is `on`, do steps 1 and 2 again now'
has "Refresh button: owner told about repeated grants" "$A" 'in ask mode it asks again after every change to the table'
has "capability only when the button is on" "$A" 'Only if `dashboard_refresh_button` is `on` and `dashboard/jobid.txt` exists'
has "read the widget to the end" "$A" 'read it to the end. If a read stops before the end of the file, continue with the next offset'
has "workspace path rule" "$A" 'It refuses a workspace path with spaces or shell characters'
has "settings: refresh button off by default" templates/settings.md '- dashboard_refresh_button: off'
has "README explains the repeated grant" README.md 'in ask mode the dashboard asks you to allow it again after every change'
has "automation: declarationKey" "$A" '`declarationKey`: `pr-dashboard-refresh`.'
has "automation: every 15 minutes" "$A" '`{"kind": "every", "everyMs": 900000}` (15 minutes). Not shorter.'
has "automation: watch hours" "$A" '`activeHours`: from `watch_hours` and `time_zone` in settings.md'
has "automation: own session, no delivery" "$A" '`sessionTarget`: `session:<your session key>`, from session_status. `delivery`: `{"mode": "none"}`.'
has "automation: packaged trigger" "$A" '`trigger`: `{"script": <the text of references/pr-dashboard/refresh-trigger.js>}`'
has "automation: UNCHANGED starts no model turn" "$A" 'starts no model turn on `UNCHANGED`'
has "automation: narrow tool list" "$A" '"toolsAllow": ["exec", "read", "write", "show_widget"]'
has "automation turn: ERROR leaves the widget" "$A" 'If its last line starts with ERROR, stop: reply with one line naming the error and do not touch the widget.'
has "automation turn: capability only with the button on" "$A" 'Only if settings.md has dashboard_refresh_button: on, also pass capabilities {"tools": ["cron.trigger:<the id in dashboard/jobid.txt>"]}'
has "trigger ignores the exit code note" references/pr-dashboard/refresh-trigger.js 'filter((l) => /^(CHANGED|UNCHANGED|ERROR)\b/.test(l)).pop()'
has "automation turn: NO_REPLY" "$A" '5. Reply with exactly NO_REPLY.'
has "short.json is agent-maintained" "$A" 'When a PR you opened is verified on GitHub (step 11), add its line'
lacks "no forced run in the setup" "$A" 'runMode'
has "process step 11 writes the summary" "$A" 'add its one-line summary to `dashboard/short.json` (PR dashboard)'
has "boundary allows exactly one dashboard automation and widget" CLAW.md 'also exactly one PR dashboard refresh automation (declarationKey `pr-dashboard-refresh`)'
has "boundary: the dashboard is read only" CLAW.md 'The PR dashboard is read only. Never add a button, link or call to it that writes to GitHub'
has "loop allows the builder without an approval row" references/contribution-loop.md '(and the same with `--mark-pinned`), the read-only PR dashboard builder'
has "BOOTSTRAP runs the dashboard setup" BOOTSTRAP.md 'Follow AGENTS.md, "PR dashboard", "Set it up": build, pin, then the one refresh automation.'
has "BOOTSTRAP check: exactly one automation" BOOTSTRAP.md 'shows exactly one `pr-dashboard-refresh` automation'
has "BOOTSTRAP asks on or off" BOOTSTRAP.md '**PR dashboard** (`dashboard`): optional, choose on or off, default on.'
has "BOOTSTRAP upgrade from 0.4.3" BOOTSTRAP.md '- From 0.4.3 (version 3): no database step.'

# 3. Owner docs
has "README has the owner section" README.md '## PR dashboard'
has "README: re-running setup adds nothing" README.md 'Running setup again updates the same widget and automation; it never adds a second one.'
has "README: upgrade adds show_widget" README.md 'Give the agent the `show_widget` tool'
has "README: sandboxOrigin is optional owner config" README.md 'Setup never sets it.'
lacks "no sandboxOrigin value anywhere" README.md 'sandboxOrigin[^`]*https?://'
has "CHANGELOG has 0.4.4" CHANGELOG.md '## 0.4.4'
ok "package.json is 0.4.4" '[[ "$(node -p "require(\"$P/package.json\").version")" == "0.4.4" ]]'

# 4. Widget template and trigger: read only, generic
T="references/pr-dashboard/template.html"
count "template has the data placeholder once" "$T" '<script type="application/json" id="d">__DATA__</script>' 1
count "template checks the data CRC" "$T" "const CRC=Number('__CRC__');" 1
count "template has the job placeholder once" "$T" "const JOB='__JOBID__';" 1
lacks "template has no workboard read" "$T" 'workboard|data\.read|boardId'
lacks "template has no network calls" "$T" 'fetch\(|XMLHttpRequest|WebSocket|EventSource|sendBeacon|api\.github\.com'
lacks "template sends no prompts or actions" "$T" 'prompt\.send|sendPrompt|action\.run|state\.emit'
lacks "template has no personal or host names" "$T" 'etzelm|mini|studio|/Users/|/home/'
lacks "template has no em dash" "$T" $'\xe2\x80\x94'
lacks "builder has no personal names or paths" references/pr-dashboard/build.mjs 'etzelm|/Users/|/home/'
has "builder retries 3 times" references/pr-dashboard/build.mjs 'for (let i = 0; i < 3; i++)'
has "builder respects the check budget" references/pr-dashboard/build.mjs 'const BUDGET_MS = 25000;'
has "builder has the mark-pinned mode" references/pr-dashboard/build.mjs 'if (argv.includes("--mark-pinned")) return markPinned(out);'
lacks "builder never writes to GitHub" references/pr-dashboard/build.mjs '"-X"|--method|mutation|--input'
lacks "GraphQL files are queries only" references/pr-dashboard/prs.graphql 'mutation'
lacks "CI query is read only" references/pr-dashboard/ci.graphql 'mutation'

echo "passed=$PASSES failed=$FAILS"
[[ $FAILS -eq 0 ]]

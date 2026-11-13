#!/bin/zsh
# 0.3.0 package checks that need no database: step list, schema guards,
# the pinned Chrome DevTools MCP server and its tool policy, site notes,
# feed sources, and the vendor-name ban.
# Usage: jac-package.test.sh <package dir>
set -u
PKG="${1:?package dir}"; PKG="${PKG:A}"
REGEX="${0:A:h}/../scripts/vendor-names.regex"
FAILS=0; PASSES=0
ok() { PASSES=$((PASSES + 1)); echo "PASS $1"; }
bad() { FAILS=$((FAILS + 1)); echo "FAIL $1 :: ${2:-}"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi }
CLAW="$PKG/CLAW.md"
FM="$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$CLAW")"

# Steps: every SQL step is shipped, documented, and guarded for version 3.
for f in "$PKG"/references/sql/*.sql; do
  s="${f:t:r}"
  check "CLAW.md ships $s" '[[ "$FM" == *"source: references/sql/$s.sql"* ]]'
  check "database.md lists $s" 'grep -q "\`$s\`" "$PKG/references/database.md"'
  case "$s" in
    migrate-v1-to-v2) check "$s guards version 1" 'grep -q "CHECK (v = 1)" "$f"' ;;
    migrate-v2-to-v3) check "$s guards version 2" 'grep -q "CHECK (v = 2)" "$f"' ;;
    *) check "$s guards version 3" 'grep -q "CHECK (v = 3)" "$f"' ;;
  esac
done
for s in save-prefiltered ranked-queue save-question open-questions mark-answered migrate-v2-to-v3; do
  check "new step $s exists" '[[ -f "$PKG/references/sql/$s.sql" ]]'
done
check "schema.sql sets version 3" 'grep -q "PRAGMA user_version = 3;" "$PKG/references/schema.sql"'

# Chrome DevTools MCP: pinned, JS evaluation off, minimal tool set.
check "mcpServers declares jac-chrome" '[[ "$FM" == *"jac-chrome:"* ]]'
check "server is pinned to chrome-devtools-mcp@1.12.0" '[[ "$FM" == *"chrome-devtools-mcp@1.12.0"* ]]'
for flag in --no-javascript-evaluation --no-file-navigations --no-usage-statistics --no-performance-crux --redact-network-headers "--browserUrl=http://127.0.0.1:9333"; do
  check "server flag $flag" '[[ "$FM" == *"- $flag"* ]]'
done
for flag in --autoConnect --allowUnrestrictedPaths --allow-unrestricted-paths --experimentalDevtools --experimentalVision --categoryExtensions --categoryExperimentalWebmcp --categoryExperimentalThirdParty --categoryPwa --memoryDebugging --filesystemRoot --filesystem-root; do
  check "server flag $flag is absent" '[[ "$FM" != *"$flag"* ]]'
done
# Upload root: exactly one dedicated folder, resolved by the Gateway from its HOME.
WSARG='--workspace=${HOME}/job-application-coordinator-files'
WSLINES=(${(f)"$(print -r -- "$FM" | grep -e '--workspace')"})
check "server has exactly one --workspace arg" '(( ${#WSLINES} == 1 ))' "${#WSLINES}"
check "--workspace is the dedicated resume folder" '[[ "$FM" == *"      - $WSARG"* ]]'
check "server sets no TMPDIR and no env" '[[ "$FM" != *TMPDIR* ]] && ! print -r -- "$FM" | grep -qE "^    env:"'
INCLUDE=(${(f)"$(print -r -- "$FM" | awk '/^ *include:/ {f=1; next} f && /^ *- / {sub(/^ *- */, ""); print; next} f {exit}')"})
ALSO=(${(f)"$(print -r -- "$FM" | grep -oE 'jac-chrome__[a-z_]+' | sort -u)"})
DENY=(${(f)"$(print -r -- "$FM" | awk '/^    deny:/ {f=1; next} f && /^      - / {sub(/^ *- */, ""); print; next} f {exit}')"})
check "toolFilter include is not empty" '(( ${#INCLUDE} >= 10 ))' "${#INCLUDE}"
RISKY=(evaluate_script lighthouse_audit performance_start_trace performance_stop_trace performance_analyze_insight emulate resize_page click_at drag install_extension uninstall_extension list_extensions reload_extension trigger_extension_action list_webmcp_tools execute_webmcp_tool install_pwa uninstall_pwa launch_pwa get_os_app_state take_heapsnapshot screencast_start screencast_stop open_devtools get_devtools_comments resolve_devtools_comment reveal_in_devtools get_console_message list_console_messages get_css_styles get_tab_id)
for t in $RISKY; do
  check "include leaves out $t" '(( ${INCLUDE[(Ie)$t]} == 0 ))'
  check "agent denies jac-chrome__$t" '(( ${DENY[(Ie)jac-chrome__$t]} > 0 ))'
done
for t in $INCLUDE; do
  check "include $t is also allowed for the agent" '[[ "$FM" == *"      - jac-chrome__$t"* ]]'
done
ALLOWED=(${(f)"$(print -r -- "$FM" | awk '/^    alsoAllow:/ {f=1; next} f && /^      - / {sub(/^ *- */, ""); print; next} f {exit}' | grep '^jac-chrome__' | sed 's/^jac-chrome__//')"})
for t in $ALLOWED; do
  check "allowed jac-chrome__$t is in the server include" '(( ${INCLUDE[(Ie)$t]} > 0 ))'
done
check "browser tool stays allowed (fallback driver)" '[[ "$FM" == *"      - browser"* ]]'
check "settings.md has browser_driver" 'grep -q "^- browser_driver: browser$" "$PKG/templates/settings.md"'

# Resume copy for the MCP driver: one persistent folder, copied once at setup.
RDIR='~/job-application-coordinator-files'
check "no /tmp anywhere in the package" '! grep -rqI "/tmp" "$PKG" && ! grep -rq "tmpdir()" "$PKG"' "$(grep -rnI /tmp "$PKG" | head -3)"
check "BOOTSTRAP creates the folder and copies the resume once" 'grep -qF "mkdir -p $RDIR && cp \"<resume file>\" $RDIR/resume.pdf" "$PKG/BOOTSTRAP.md"'
for f in README.md templates/profile.md references/apply-mechanics.md workspace/AGENTS.md CHANGELOG.md; do
  check "$f names the resume folder" 'grep -qF "job-application-coordinator-files" "$PKG/$f"'
done
check "no copy-again-after-restart text" '! grep -rqiE "again whenever|rerun the copy|run the same command again|clears .*on restart|again after (a )?restart|/tmp is cleared" "$PKG"' "$(grep -rniE "again whenever|rerun the copy|run the same command again|clears .*on restart|again after (a )?restart|/tmp is cleared" "$PKG" | head -3)"
check "SOUL: only upload_file gets a file path" 'grep -q "never pass a file path to any tool except \`upload_file\`" "$CLAW"'
check "upload-failed rules kept for the MCP driver" 'grep -q "upload-failed rules" "$PKG/references/apply-mechanics.md"'
check "docs say the folder holds only the resume" 'grep -qi "only your resume\|only the resume" "$PKG/README.md" && grep -qi "only the resume\|nothing else" "$PKG/BOOTSTRAP.md"'
# Site notes: shipped as a workspace file and a template, placeholders only.
check "CLAW.md ships site-notes.md to the workspace" '[[ "$FM" == *"path: site-notes.md"* ]]'
check "templates/site-notes.md exists" '[[ -f "$PKG/templates/site-notes.md" ]]'
check "site-notes template uses only example hosts" '! grep -oE "https?://[^ )>]+" "$PKG/templates/site-notes.md" | grep -vE "^https?://([a-z0-9-]+\.)*example\.(com|org|net)(/|$)" | grep -q .'
check "SOUL forbids writing site-notes.md" 'grep -q "site-notes.md" "$CLAW" && grep -qi "never write.*site-notes.md\|site-notes.md.*never" "$CLAW"'
# Feeds: sources.md accepts them, examples use example hosts only.
check "sources template accepts feeds" 'grep -qi "feed" "$PKG/templates/sources.md"'
check "sources template uses only example hosts" '! grep -oE "https?://[^ )>]+" "$PKG/templates/sources.md" | grep -vE "^https?://([a-z0-9-]+\.)*example\.(com|org|net)(/|$)" | grep -q .'
# Liability: no job site, ATS or vendor names anywhere in the package.
HITS="$(grep -rniIE -f "$REGEX" "$PKG" | head -5)"
check "no job-site or vendor names" '[[ -z "$HITS" ]]' "$HITS"
echo "passed=$PASSES failed=$FAILS"
[[ $FAILS -eq 0 ]]

#!/bin/zsh
# 0.4.6: design choices the evidence can settle are decided, built and proven, not handed to maintainers.
# Red on 0.4.5 (no implementation-request rule, PR body asks maintainers to decide, a design finding
# stops the review loop, needs-product-decision stops at once), green on 0.4.6.
# Usage: occ-text-046.test.sh <package dir>
set -u
P="${1:?package dir}"; P="${P:A}"
S="CLAW.md"; A="workspace/AGENTS.md"; L="references/contribution-loop.md"
PASSES=0; FAILS=0
has() { if grep -qF -- "$3" "$P/$2" 2>/dev/null; then PASSES=$((PASSES + 1)); echo "PASS $1"; else FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 lacks: $3"; fi; }
lacks() { if grep -qE -- "$3" "$P/$2" 2>/dev/null; then FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 has: $3"; else PASSES=$((PASSES + 1)); echo "PASS $1"; fi; }
ok() { if eval "$2"; then PASSES=$((PASSES + 1)); echo "PASS $1"; else FAILS=$((FAILS + 1)); echo "FAIL $1"; fi; }
GATES='CI or SecOps approval, dependency sign-off, an SDK or surface budget raise, credit, or anything that needs an outward post'

# 1. CLAW.md: implementation requests
has "implementation request gets a prototype" "$S" '- When the owner explicitly asks for an implementation (an RFC, a design, a stalled stack), build a high-fidelity prototype that works end to end on top of the existing work'
has "no list of questions for maintainers" "$S" 'Do not return a list of questions for maintainers'
has "each choice gets one line" "$S" 'Record each in one line: the choice, the evidence, and how to reverse it.'
has "public text says recommendations" "$S" 'Public text calls those answers recommendations pending acceptance.'
ok "implementation bullet sits before the smallest-fix bullet" '[[ $(grep -n "^- When the owner explicitly asks for an implementation" "$P/$S" | cut -d: -f1) -lt $(grep -n "^- Make the smallest complete fix" "$P/$S" | cut -d: -f1) ]]'

# 2. CLAW.md: Decisions table and gates-only list
has "Decisions table in the PR body" "$S" 'the PR body lists them in a `Decisions` table (choice | evidence | how to reverse)'
has "Needs a maintainer holds only gates" "$S" "The body's \`Needs a maintainer\` list holds only what we cannot do or decide: $GATES, one short line each."
lacks "old maintainer-decision line is gone" "$S" 'A decision maintainers need to make goes in the PR body'
has "stop list points to the decide-first pass" "$S" 'stop only if the label stays on that new head (workspace/AGENTS.md step 12)'

# 3. AGENTS.md steps 9 and 12
has "step 9: design finding is not a stop" "$A" 'A finding that asks for a design or product choice is not a stop: decide it with evidence, build it, prove it'
has "step 9: stop early only for gates" "$A" "Stop early only for a gate we cannot clear ($GATES)"
lacks "step 9: no maintainer-decision stop" "$A" 'is met, a maintainer decision is needed, or'
has "step 12: decide-and-re-review pass" "$A" 'On `clawsweeper:needs-product-decision`, first turn each open choice the evidence can settle into a built and proven `Decisions` row and request one re-review; stop only if the label stays on that new head'

# 4. contribution-loop.md
has "loop step 9: design finding decided" "$L" '6. A finding that asks for a design or product choice is not a stop'
lacks "loop step 9: old stop text gone" "$L" 'A finding that needs a maintainer decision \(product direction'
has "loop step 10: Decisions table" "$L" 'Add a `Decisions` table with one row per design choice the evidence settled (choice | evidence | how to reverse)'
has "loop step 10: gates-only list" "$L" "a short \`Needs a maintainer\` list that holds only what we cannot do or decide: $GATES"
lacks "loop step 10: old decision lines gone" "$L" 'Put any decision maintainers must make'
has "needs-product-decision: one pass first" "$L" 'It gets one decide-and-re-review pass before it is a stop'
has "needs-product-decision: stop only if it stays" "$L" 'Stop only if the label stays on that new head'
lacks "stop rules: no plain maintainer-decision finding" "$L" 'or a finding needs a maintainer decision\.'

# 5. Standing grant, README
has "grant request: label stops only after the pass" templates/standing-grant.md 'the `clawsweeper:needs-product-decision` label, if it stays after one pass'
lacks "grant request: old bare label line gone" templates/standing-grant.md '^- needs-product-decision: the `clawsweeper:needs-product-decision` label\.$'
has "README: label gets one pass" README.md 'The `clawsweeper:needs-product-decision` label first gets one pass'
has "README: Decisions table" README.md 'The PR body lists each in a `Decisions` table (choice, evidence, how to reverse).'
has "README: gates-only list" README.md "Its \`Needs a maintainer\` list holds only gates it cannot clear: $GATES."

# 6. No PR-body template still asks maintainers open questions
ok "no Open questions section ships" '! grep -rqi "^#* *open questions" "$P/templates" "$P/examples" "$P/references"'

# 7. Version and text hygiene
ok "package is 0.4.6 or a later 0.4.x" '[[ "$(node -p "require(\"$P/package.json\").version")" == 0.4.<6-> ]]'
has "CHANGELOG has 0.4.6 with an upgrade note" CHANGELOG.md 'Upgrade from 0.4.5:'
ok "no em dashes in the changed text" '! LC_ALL=C grep -q "$(printf '"'"'\342\200\224'"'"')" "$P/$S" "$P/$A" "$P/$L" "$P/README.md" "$P/CHANGELOG.md" "$P/templates/standing-grant.md"'
ok "no PR or issue numbers in the 0.4.6 CHANGELOG entry" '! awk "/^## 0\\.4\\.6/{f=1;next} /^## /{f=0} f" "$P/CHANGELOG.md" | grep -qiE "#[0-9]{3,}|pull/[0-9]|issues/[0-9]|/Users/"'

echo "passed=$PASSES failed=$FAILS"
[[ $FAILS -eq 0 ]]

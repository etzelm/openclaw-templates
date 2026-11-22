#!/bin/zsh
# 0.4.3: the loop text carries the rules from live use of 0.4.2.
# Red on 0.4.2 (proof packaging, watcher baseline, exact stops, merged-fix duplicate, worktree script,
# no stash, fresh base and interactive relay are missing), green on 0.4.3.
# Usage: occ-text-043.test.sh <package dir>
set -u
P="${1:?package dir}"; P="${P:A}"
L="$P/references/contribution-loop.md"
PASSES=0; FAILS=0
has() { if grep -qF -- "$3" "$P/$2" 2>/dev/null; then PASSES=$((PASSES + 1)); echo "PASS $1"; else FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 lacks: $3"; fi; }
lacks() { if grep -qE -- "$3" "$P/$2" 2>/dev/null; then FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 has: $3"; else PASSES=$((PASSES + 1)); echo "PASS $1"; fi; }
listed() { if grep -qF -- "source: $2" "$P/CLAW.md" && [[ -f "$P/$2" ]]; then PASSES=$((PASSES + 1)); echo "PASS $1"; else FAILS=$((FAILS + 1)); echo "FAIL $1 :: $2 not shipped"; fi; }

# 1. Proof packaging
listed "proof guide ships" references/proof.md
listed "runtime output layout ships" templates/runtime-output.md
has "body gets a Runtime output heading" references/contribution-loop.md '### Runtime output'
has "layout has the Runtime output heading" templates/runtime-output.md '### Runtime output'
has "proof needs the command and both SHAs" references/proof.md 'The base SHA and the head SHA'
has "proof needs raw output in fenced blocks" references/proof.md 'in a fenced code block, redacted, not paraphrased'
has "long logs go to proof-assets" references/proof.md 'proof-assets/<slug>'
has "proof is planned at scope time" templates/scope-proposal.md 'Runtime output:'
# 0.4.4 replaced the 0.4.3 stub-plus-request fallback with a skip at pick time (occ-text-044.test.sh).
has "scope names live accounts the owner lacks" templates/scope-proposal.md 'Every account, subscription, device or channel login must be in proof_accounts.'
has "self-check question before the push gate" references/proof.md 'Does the body contain the actual output a reviewer can inspect?'
has "push gate requires the self-check" references/contribution-loop.md 'proof-check.md` must exist for this head'
has "runtime proof has its own exec lane" references/contribution-loop.md 'The runtime proof commands written in the approved scope.md'
has "runtime proof never touches the owner's Gateway" references/proof.md "Never the owner's state folder, config, port, sessions or channel accounts."
has "base run happens at the base" references/contribution-loop.md 'Base runtime run: now, while the checkout is still exactly the base'
has "head run happens after the last commit, any review route" references/contribution-loop.md '### Head runtime run'
has "proof run isolates the config too" references/proof.md 'OPENCLAW_CONFIG_PATH'
has "every proof command pins the proof port" references/proof.md 'OPENCLAW_GATEWAY_PORT=<port>'
has "prefix unsets the Gateway URL and credentials" references/proof.md '-u OPENCLAW_GATEWAY_URL -u OPENCLAW_GATEWAY_TOKEN -u OPENCLAW_GATEWAY_PASSWORD'
has "scope slots carry the prefix" templates/scope-proposal.md 'OPENCLAW_GATEWAY_PORT=N'
has "leftover check uses the port" references/proof.md 'lsof -nP -iTCP:<port> -sTCP:LISTEN'
has "self-check is bound to head and body hash" references/proof.md 'A check for another head or body hash does not count.'
has "text checks do not reword log lines" references/upstream-text.md 'Never retype, reword or drop the log line'
has "owner sees the output in the open-pr request" templates/approval-request.md "paste the body's \`### Runtime output\` section here"
has "proof branch worktree uses the script" references/contribution-loop.md 'sh references/setup-worktree.sh --repo <checkout> --worktree "<workspace>/assets-<slug>"'
listed "filled runtime output example ships" examples/runtime-output.md
# 2. Watcher baseline and busy-session wake
has "watcher has the addedAt line" references/pr-watch.js 'const addedAt = "";'
has "loop fills addedAt" references/contribution-loop.md 'on the `const addedAt` line'
has "busy session wake waits for the turn" references/contribution-loop.md 'the wake waits until that turn ends'
has "forced run list stays empty until then" references/contribution-loop.md 'runs list stays empty for that run'
# 3. Stop conditions
has "stop: needs-maintainer-decision" references/contribution-loop.md '**needs-maintainer-decision**'
has "stop: needs-product-decision" references/contribution-loop.md '**needs-product-decision**'
# 0.4.6: the label gets one decide-and-re-review pass before it is a stop (occ-text-046.test.sh).
has "needs-product-decision: decide and re-review first" references/contribution-loop.md 'It gets one decide-and-re-review pass before it is a stop'
lacks "needs-product-decision is not an immediate stop" references/contribution-loop.md 'the `clawsweeper:needs-product-decision` label\. `set-status` to `blocked-maintainer-decision`\.'
has "a human reply is a pause, not a stop" references/contribution-loop.md 'A human or maintainer reply is not a stop: it is a pause'
has "pause keeps the grant and the watcher" references/contribution-loop.md 'keep the grant and the watcher'
lacks "maintainer-decision stop is only the labels" references/contribution-loop.md 'any other label that says a maintainer decision is needed'
has "stop: scope growth" references/contribution-loop.md '**Scope growth**'
has "stop: 4 rounds without progress" references/contribution-loop.md '**4 hosted rounds without progress**'
has "security-review-required is not a stop" references/contribution-loop.md 'Never post that command'
has "allow command named" references/contribution-loop.md '/allow-security-sensitive-change'
has "grant request: a human comment is a pause" templates/standing-grant.md 'A person or maintainer comments or reviews on the PR. I never reply'
lacks "grant request: no human-reply stop" templates/standing-grant.md 'A human or maintainer reply on the PR'
# 4. Merged fix without a closing keyword
has "duplicate: merged fix without closing keyword" references/contribution-loop.md 'already fixed by a merged PR that never linked it with a closing keyword'
# 5. Worktree setup script
listed "setup-worktree.sh ships" references/setup-worktree.sh
has "loop uses the script" references/contribution-loop.md 'sh references/setup-worktree.sh'
has "README explains the runtime limit" README.md 'Some runtimes do not let the agent run `git config`'
has "settings has commit_name" templates/settings.md '- commit_name:'
has "settings has signing_key" templates/settings.md '- signing_key:'
# 6. No stash
lacks "loop never tells the agent to stash" references/contribution-loop.md 'stash (push|pop)'
has "mutation check uses git apply -R" references/contribution-loop.md 'apply -R'
has "stash is forbidden" references/contribution-loop.md '`git stash` in any form'
# 7. Fresh base
has "fresh base for check:changed" references/contribution-loop.md '### Fresh base for changed-file gates'
has "stale baseline symptom named" references/contribution-loop.md 'The stale baseline symptom'
# 8. Relays
has "relays come from an interactive turn" references/contribution-loop.md 'Relays come from an interactive turn'
has "upstream issue named" references/contribution-loop.md 'openclaw/openclaw#199278'
# Version
# 0.4.4: the version pin accepts later 0.4.x releases, which keep every rule above.
if grep -qE '"version": "0\.4\.([3-9]|[1-9][0-9])"' "$P/package.json"; then PASSES=$((PASSES + 1)); echo "PASS package is 0.4.3 or a later 0.4.x"; else FAILS=$((FAILS + 1)); echo "FAIL package is 0.4.3 or a later 0.4.x"; fi
has "changelog has 0.4.3 with an upgrade note" CHANGELOG.md 'Upgrade from 0.4.2:'

echo "passed=$PASSES failed=$FAILS"
[[ $FAILS -eq 0 ]]

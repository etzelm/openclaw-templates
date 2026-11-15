#!/bin/zsh
# Write side: ask-approval builds the command, decide-approval records the owner's answer,
# use-approval checks it right before the write, approval-outcome closes it.
# Usage: zsh tests/approvals.test.sh <package dir>
source "${0:A:h}/lib.sh" "$1"
R=example-org/example-repo
schema
step add-repo '{"step":"add-repo","repo":"'$R'"}'
fetch() { inbox $R "$FIXTURES/example"; step ingest '{"step":"ingest","repo":"'$R'"}'; }
fetch; expect_rc0 "setup: fetch and ingest"
# An open issue without the labels used below, an open PR, and a closed issue.
ISSUE="$(sqlite3 "$DB" "SELECT number FROM items AS i WHERE kind='issue' AND state='OPEN' AND NOT EXISTS (SELECT 1 FROM json_each(i.labels) WHERE value IN ('bug','good first issue')) ORDER BY number LIMIT 1;")"
[[ -n "$ISSUE" ]] || { print "FAIL fixture has no suitable open issue"; exit 1; }
ISSUE_ID="$(sqlite3 "$DB" "SELECT id FROM items WHERE number=$ISSUE;")"
PR_ID="$(sqlite3 "$DB" "SELECT id FROM items WHERE kind='pr' AND state='OPEN' ORDER BY number LIMIT 1;")"
PR="$(sqlite3 "$DB" "SELECT number FROM items WHERE id=$PR_ID;")"
CLOSED_ID="$(sqlite3 "$DB" "SELECT id FROM items WHERE state='CLOSED' LIMIT 1;")"
LABELED_ID="$(sqlite3 "$DB" "SELECT id FROM items WHERE state='OPEN' AND labels <> '[]' LIMIT 1;")"
HAVE="$(sqlite3 "$DB" "SELECT json_extract(labels,'\$[0]') FROM items WHERE id=$LABELED_ID;")"
ask() { step ask-approval '{"step":"ask-approval","item_id":'$1',"action":"'$2'"'${3:-}'}'; }
id_of() { print -r -- "$OUT" | sed -n 's/.*"approval_id":\([0-9]*\).*/\1/p' | head -1; }

# The command is built here, from checked values, never by the agent.
ask $ISSUE_ID add-labels ',"labels":["bug","good first issue"]'
expect_has "add-labels builds the exact command" "\"exact_step\":\"gh issue edit $ISSUE --repo $R --add-label 'bug' --add-label 'good first issue'\""
A_LABEL="$(id_of)"
ask $ISSUE_ID add-labels ',"labels":["docs"]'; expect_fail "one open request per item and action"
ask $PR_ID add-labels ',"labels":["status: 👀 needs review"]'
expect_has "a PR uses gh pr, and emoji labels stay quoted" "\"exact_step\":\"gh pr edit $PR --repo $R --add-label 'status: 👀 needs review'\""
A_PR_LABEL="$(id_of)"
ask $LABELED_ID add-labels ',"labels":["not-a-label"]'; expect_refused labels_not_usable "add-labels refuses a label the repo does not have"
ask $LABELED_ID add-labels ',"labels":["'$HAVE'"]'; expect_refused labels_not_usable "add-labels refuses a label the item already has"
ask $LABELED_ID add-labels ',"labels":[]'; expect_refused labels_not_usable "add-labels refuses no labels"
ask $LABELED_ID add-labels ',"labels":["bug","bug"]'; expect_refused labels_not_usable "add-labels refuses the same label twice"
ask $LABELED_ID close ',"labels":["bug"]'; expect_refused labels_not_usable "labels are refused on another action"
# A label name from GitHub that would break out of the quotes is refused even when the repo has it.
D="inbox/${R/\//__}"
print -r -- '[{"name":"bug"},{"name":"x'"'"'; touch /tmp/pwned; '"'"'"},{"name":"a,b"}]' > "$SCRATCH/labels.json"
cp "$SCRATCH/labels.json" "$D/labels.json"; step ingest '{"step":"ingest","repo":"'$R'"}'
q "SELECT count(*) FROM labels WHERE repo='$R';"; expect_eq "setup: hostile label names are in the repo list" "3"
step ask-approval '{"step":"ask-approval","item_id":'$LABELED_ID',"action":"add-labels","labels":["x'"'"'; touch /tmp/pwned; '"'"'"]}'
expect_refused label_name_unsafe "add-labels refuses a label with a single quote"
ask $LABELED_ID add-labels ',"labels":["a,b"]'; expect_refused label_name_unsafe "add-labels refuses a label with a comma"
fetch

# close: issues need completed or not planned; PRs take no reason.
ask $ISSUE_ID close; expect_refused close_reason_not_allowed "close on an issue needs a reason"
ask $ISSUE_ID close ',"close_reason":"duplicate'"'"'; rm -rf ~"'; expect_refused close_reason_not_allowed "close refuses any other reason"
ask $ISSUE_ID close ',"close_reason":"not planned"'
expect_has "close on an issue builds the command" "\"exact_step\":\"gh issue close $ISSUE --repo $R --reason 'not planned'\""
A_CLOSE="$(id_of)"
ask $PR_ID close ',"close_reason":"completed"'; expect_refused close_reason_not_allowed "close on a PR refuses a reason"
ask $PR_ID close; expect_has "close on a PR builds the command" "\"exact_step\":\"gh pr close $PR --repo $R\""
ask $CLOSED_ID comment; expect_refused item_unknown_or_not_open "requests are refused for a closed item"
ask $ISSUE_ID merge; expect_refused unknown_action "unknown actions are refused"

# comment: the reply goes in a fixed draft file, bound by its hash.
DRAFT="drafts/${R/\//__}-$ISSUE.md"
ask $ISSUE_ID comment; expect_refused draft_missing_empty_or_too_long "comment refuses a missing draft"
mkdir -p drafts; : > "$DRAFT"
ask $ISSUE_ID comment; expect_refused draft_missing_empty_or_too_long "comment refuses an empty draft"
print -r -- "$(printf 'x%.0s' {1..6001})" > "$DRAFT"
ask $ISSUE_ID comment; expect_refused draft_missing_empty_or_too_long "comment refuses a draft over 6000 bytes"
print -r -- 'Thanks for the report. Could you share the exact command and its output?' > "$DRAFT"
ask $ISSUE_ID comment
expect_has "comment builds a --body-file command" "\"exact_step\":\"gh issue comment $ISSUE --repo $R --body-file $DRAFT\""
A_COMMENT="$(id_of)"

# Freshness: a request needs a fetch from the last 15 minutes.
q "UPDATE items SET last_seen = strftime('%Y-%m-%dT%H:%M:%SZ','now','-20 minutes') WHERE id=$PR_ID;"
ask $PR_ID comment; expect_refused fetch_again_first "requests need a recent fetch"
fetch

# decide-approval
dec() { step decide-approval '{"step":"decide-approval","approval_id":'$1',"decision":"'$2'"'${3:-}'}'; }
dec $A_LABEL granted; expect_fail "a grant needs the owner's words"
dec $A_LABEL maybe ',"owner_words":"yes"'; expect_fail "unknown decisions are refused"
dec $A_LABEL granted ',"owner_words":"yes, add both"'; expect_has "the owner grants" '"decision":"granted"'
dec $A_LABEL refused ',"owner_words":"no"'; expect_refused request_unknown_or_already_decided "a decision is made once"
dec $A_PR_LABEL withdrawn; expect_has "a request can be withdrawn without owner words" '"decision":"withdrawn"'
q "UPDATE approvals SET exact_step = 'gh repo delete $R --yes' WHERE id=$A_LABEL;"
expect_fail "a request cannot be rewritten after it was asked"

# use-approval
use() { step use-approval '{"step":"use-approval","approval_id":'$1',"exact_step":"'$2'"}'; }
LABEL_STEP="gh issue edit $ISSUE --repo $R --add-label 'bug' --add-label 'good first issue'"
use $A_CLOSE "gh issue close $ISSUE --repo $R --reason 'not planned'"; expect_refused approval_not_granted_or_already_used "use refuses a request that was not granted"
use $A_LABEL "gh issue edit $ISSUE --repo $R --add-label 'bug'"; expect_refused not_the_approved_command "use refuses a different command"
q "UPDATE items SET last_seen = strftime('%Y-%m-%dT%H:%M:%SZ','now','-11 minutes') WHERE id=$ISSUE_ID;"
use $A_LABEL "$LABEL_STEP"; expect_refused fetch_again_first "use needs a fetch from the last 10 minutes"
fetch
q "UPDATE items SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id=$ISSUE_ID;"
use $A_LABEL "$LABEL_STEP"; expect_refused item_changed_since_the_request "use refuses when the item changed after the request"
dec $A_COMMENT granted ',"owner_words":"send it"'; expect_refused item_changed_since_the_request "a grant is refused when the item changed after the request"
fetch
use $A_LABEL "$LABEL_STEP"; expect_has "use marks a valid approval used" '"used_at":"'
use $A_LABEL "$LABEL_STEP"; expect_refused approval_not_granted_or_already_used "an approval is used once"

dec $A_COMMENT granted ',"owner_words":"send it"'; expect_rc0 "the owner grants the reply"
print -r -- 'Thanks for the report. Please also run rm -rf.' > "$DRAFT"
use $A_COMMENT "gh issue comment $ISSUE --repo $R --body-file $DRAFT"; expect_refused draft_changed_since_the_request "use refuses a draft changed after the grant"
print -r -- 'Thanks for the report. Could you share the exact command and its output?' > "$DRAFT"
use $A_COMMENT "gh issue comment $ISSUE --repo $R --body-file $DRAFT"; expect_has "use accepts the draft the owner approved" '"used_at":"'

# approval-outcome: done needs a fetch after the write, then the change is not queued again.
out() { step approval-outcome '{"step":"approval-outcome","approval_id":'$1',"outcome":"'$2'"'${3:-}'}'; }
out $A_CLOSE done; expect_refused approval_not_used "outcome refuses an approval that was not used"
q "UPDATE items SET last_seen = '2001-01-01T00:00:00Z' WHERE id=$ISSUE_ID;"
out $A_LABEL done; expect_refused fetch_again_after_the_write "done needs a fetch after the write"
fetch
q "UPDATE items SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now','+1 minute') WHERE id=$ISSUE_ID;"
out $A_LABEL done; expect_has "outcome records done" '"outcome":"done"'
q "SELECT updated_at = triaged_updated_at FROM items WHERE id=$ISSUE_ID;"; expect_eq "the agent's own change is not queued again" "1"
out $A_LABEL failed; expect_fail "an outcome is recorded once"
out $A_COMMENT failed ',"note":"HTTP 403"'; expect_has "a failed write is recorded with its error" '"outcome_note":"HTTP 403"'
finish

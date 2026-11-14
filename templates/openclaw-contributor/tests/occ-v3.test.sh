#!/bin/zsh
# 0.4.2, schema version 3: standing grants and the hosted-review evidence kind.
# Red on 0.4.1 (no grants table, no record-grant or end-grant step, no v2 to v3 migration), green on 0.4.2.
# Usage: occ-v3.test.sh <package dir>
FIX1="${0:A:h}/fixtures/schema-v1.sql"
FIX2="${0:A:h}/fixtures/schema-v2.sql"
source "${0:A:h}/lib.sh" "$1"
N='"now":"2026-11-14T18:00:00Z"'
H1="$(printf 'a%.0s' {1..64})"
RRH="$(shasum -a 256 "$PKG/references/re-review.md" | cut -d' ' -f1)"
HEAD1="c02af35c87d5ee62bf24c39c48eb85a702bbace4"
HEAD2="d70099712cd76eb00115658f9e4a837da54f2388"
counts() { sqlite3 "$1" "SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events);"; }

# --- Upgrade: a v2 database shaped like a live 0.4.0 one with an open PR ---
V2="$SCRATCH/data/v2.db"
sqlite3 -bail "$V2" ".read $FIX2" >/dev/null 2>&1 || { echo "FAIL v2 fixture"; exit 1; }
sqlite3 -bail "$V2" "
INSERT INTO candidates (repo, number, url, title, decision, first_seen, updated_at) VALUES ('openclaw/openclaw', 1, 'https://github.com/openclaw/openclaw/issues/1', 'old', 'approved', 'x', 'x');
INSERT INTO candidates (repo, number, url, title, decision, first_seen, updated_at) VALUES ('openclaw/openclaw', 2, 'https://github.com/openclaw/openclaw/issues/2', 'leak', 'approved', 'x', 'x');
INSERT INTO contributions (candidate_id, slug, branch, status, created_at, updated_at, note) VALUES (1, 'thinking-off', 'fix/t', 'scope-approved', 'x', 'x', 'n');
INSERT INTO contributions (candidate_id, slug, branch, status, created_at, updated_at, note) VALUES (2, 'namespace-retention', 'fix/plugin-namespace-retention', 'scope-approved', 'x', 'x', 'n');
UPDATE contributions SET status = 'pr-open', note = 'opened', head_sha = '$HEAD1', pr_url = 'https://github.com/openclaw/openclaw/pull/2' WHERE id = 2;
INSERT INTO evidence (contribution_id, kind, result, recorded_at) VALUES (2, 'repro-red', 'fail', 'x');
INSERT INTO evidence (contribution_id, kind, result, recorded_at, note) VALUES (2, 'local-review', 'pass', 'x', 'round 2');
INSERT INTO evidence (contribution_id, kind, result, recorded_at, note) VALUES (2, 'ci-classification', 'info', 'x', 'action_required');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at, decision, owner_words, decided_at) VALUES (2, 2, 'push', 'git -C wt push fork fix/p', '$HEAD2', 'x', 'withdrawn', 'head replaced', 'x');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at, decision, owner_words, decided_at, used_at, outcome) VALUES (2, 2, 'push', 'git -C wt push fork fix/p', '$HEAD1', 'x', 'granted', 'push signed', 'x', 'x', 'pushed');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, body_sha256, asked_at, decision, owner_words, decided_at, used_at, outcome) VALUES (2, 2, 'open-pr', 'gh pr create --body-file p.md', '$HEAD1', '$H1', 'x', 'granted', 'yes', 'x', 'x', 'https://github.com/openclaw/openclaw/pull/2');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at) VALUES (1, 1, 'push', 'git push fork x', 'abc1234', 'x');
" || { echo "FAIL v2 rows"; exit 1; }
BEFORE="$(counts "$V2")"
step "$V2" ask-approval '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git push","head_sha":"'$HEAD1'",'$N'}'
expect_fail "0.4.2 steps refuse a version 2 database before the upgrade"
OUT="$(sqlite3 -bail "$V2" ".read references/sql/migrate-v2-to-v3.sql" 2>&1)"; RC=$?
expect_has "migrate v2 to v3 runs" "migrate ok, schema version 3, approvals kept: 4, evidence kept: 3"
AFTER="$(counts "$V2")"
OUT="$BEFORE -> $AFTER"; RC=0
[[ "$BEFORE" == "$AFTER" && -n "$AFTER" ]] && ok "v3 migration keeps every row ($AFTER)" || bad "v3 migration keeps every row"
OUT="$(sqlite3 "$V2" "SELECT group_concat(id||':'||decision||':'||(used_at IS NOT NULL)||':'||coalesce(grant_id,'-'), ' ') FROM approvals;")"; RC=0
[[ "$OUT" == "1:withdrawn:0:- 2:granted:1:- 3:granted:1:- 4:pending:0:-" ]] && ok "decisions kept, pending stays pending, no grant ids" || bad "decisions kept, pending stays pending"
OUT="$(sqlite3 "$V2" "SELECT group_concat(kind, ',') FROM evidence ORDER BY id;")"; RC=0
[[ "$OUT" == "repro-red,local-review,ci-classification" ]] && ok "evidence rows kept in order" || bad "evidence rows kept in order"
OUT="$(sqlite3 "$V2" "SELECT count(*) FROM sqlite_master WHERE name IN ('approvals_contribution','approvals_decided_once','approvals_used_once','contributions_status_event','contributions_insert_event','evidence_contribution','grants_one_open','grants_actions_known','grants_ended_once','approvals_grant_scope','approvals_grant_one_review_per_head','approvals_grant_on_insert');")"; RC=0
[[ "$OUT" == "12" ]] && ok "indexes and triggers present after the v3 migration" || bad "indexes and triggers present after the v3 migration"
OUT="$(sqlite3 "$V2" "UPDATE approvals SET used_at = 'y' WHERE id = 2;" 2>&1)"; RC=$?
expect_fail "used-once trigger survives the v3 migration"
OUT="$(sqlite3 "$V2" "PRAGMA foreign_key_check;" 2>&1)"; RC=0
[[ -z "$OUT" ]] && ok "no foreign key problems after the v3 migration" || bad "no foreign key problems after the v3 migration"
OUT="$(sqlite3 -bail "$V2" ".read references/sql/setup-check.sql" 2>&1)"; RC=$?
expect_has "setup-check passes on the migrated database" "setup-check ok, schema version 3"
OUT="$(sqlite3 -bail "$V2" ".read references/sql/migrate-v2-to-v3.sql" 2>&1)"; RC=$?
expect_fail "v3 migration refuses a version 3 database"
OUT="$(sqlite3 "$V2" "PRAGMA user_version;")"; RC=0
[[ "$OUT" == "3" ]] && ok "still version 3 after the refused rerun" || bad "still version 3 after the refused rerun"
OUT="$(counts "$V2")"; RC=0
[[ "$OUT" == "$AFTER" ]] && ok "setup-check and the refused rerun leave no rows" || bad "setup-check and the refused rerun leave no rows"

# --- Upgrade chain from 0.3.x: v1, then v2, then v3 ---
V1="$SCRATCH/data/v1.db"
sqlite3 -bail "$V1" ".read $FIX1" >/dev/null 2>&1
sqlite3 -bail "$V1" "INSERT INTO candidates (repo, url, title, decision, first_seen, updated_at) VALUES ('openclaw/openclaw', 'board:c', 't', 'approved', 'x', 'x');
INSERT INTO contributions (candidate_id, slug, branch, status, created_at, updated_at) VALUES (1, 's', 'b', 'scope-approved', 'x', 'x');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at) VALUES (1, 1, 'push', 'git push', 'abc1234', 'x');"
OUT="$(sqlite3 -bail "$V1" ".read references/sql/migrate-v2-to-v3.sql" 2>&1)"; RC=$?
expect_fail "v3 migration refuses a version 1 database"
OUT="$(sqlite3 -bail "$V1" ".read references/sql/migrate-v1-to-v2.sql" 2>&1)"; RC=$?
expect_has "v1 to v2 still runs" "migrate ok, schema version 2"
OUT="$(sqlite3 -bail "$V1" ".read references/sql/migrate-v2-to-v3.sql" 2>&1)"; RC=$?
expect_has "then v2 to v3" "migrate ok, schema version 3, approvals kept: 1"

# --- Standing grants on the migrated live-shaped database ---
DB="$V2"
step "$DB" record-grant '{"step":"record-grant","contribution_id":1,"actions":["push"],"scope":"s","stop_conditions":"c","owner_words":"yes",'$N'}'
expect_fail "record-grant refuses a contribution without a PR"
step "$DB" record-grant '{"step":"record-grant","contribution_id":2,"actions":["push","force-push"],"scope":"s","stop_conditions":"c","owner_words":"yes",'$N'}'
expect_fail "record-grant refuses force-push"
step "$DB" record-grant '{"step":"record-grant","contribution_id":2,"actions":["comment"],"scope":"s","stop_conditions":"c","owner_words":"yes",'$N'}'
expect_fail "record-grant refuses comment"
step "$DB" record-grant '{"step":"record-grant","contribution_id":2,"actions":[],"scope":"s","stop_conditions":"c","owner_words":"yes",'$N'}'
expect_fail "record-grant refuses an empty action list"
step "$DB" record-grant '{"step":"record-grant","contribution_id":2,"actions":["push"],"scope":"s","stop_conditions":"c","owner_words":"  ",'$N'}'
expect_fail "record-grant refuses empty owner_words"
step "$DB" record-grant '{"step":"record-grant","contribution_id":2,"actions":["push"],"scope":"s",'$N',"owner_words":"yes"}'
expect_fail "record-grant refuses missing stop conditions"
step "$DB" record-grant '{"step":"record-grant","contribution_id":2,"actions":["push","edit-pr","request-review"],"scope":"signed pushes, body edits, one re-review per head, PR 2 only","stop_conditions":"human reply, other comment, close, scope growth, decision label, 4 hosted rounds without progress","owner_words":"\"I give the standing approval.\" (relayed by main, session S, 2026-11-14T17:26Z)",'$N'}'
expect_has "record-grant records the grant with the PR url" '"pr_url":"https://github.com/openclaw/openclaw/pull/2"'
G="$(sqlite3 "$DB" 'SELECT max(id) FROM grants;')"
step "$DB" record-grant '{"step":"record-grant","contribution_id":2,"actions":["push"],"scope":"s","stop_conditions":"c","owner_words":"yes",'$N'}'
expect_fail "a second open grant for the same contribution is refused"

ask() { step "$DB" ask-approval "$1"; A="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"; }
PUSH='git -C wt-namespace-retention push fork fix/plugin-namespace-retention'
grant_fails() { # <label> <ask json>: asked, then refused under the grant, then withdrawn
  ask "$2"
  step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"grant",'$N'}'
  expect_fail "$1"
  step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"withdrawn","owner_words":"test",'$N'}'
}
grant_fails "grant refuses a force-push dressed as push" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"'"$PUSH"' --force","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses push -f" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git -C wt push -f fork fix/plugin-namespace-retention","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses a + refspec" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git -C wt push fork +'$HEAD2':refs/heads/fix/plugin-namespace-retention","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses a delete refspec" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git -C wt push fork :fix/plugin-namespace-retention","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses pushing the branch onto another remote branch" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git -C wt push fork fix/plugin-namespace-retention:main","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses a PR edit without --repo openclaw/openclaw" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"edit-pr","exact_step":"gh pr edit 2 --body-file p.md","head_sha":"'$HEAD2'","body_sha256":"'$H1'",'$N'}'
grant_fails "grant refuses a push to origin" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git -C wt push origin fix/plugin-namespace-retention","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses a second refspec" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git -C wt push fork other:refs/heads/x fix/plugin-namespace-retention","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses a push of another branch" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git -C wt push fork main","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses a chained command" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"'"$PUSH"' && gh pr merge 2","head_sha":"'$HEAD2'",'$N'}'
grant_fails "grant refuses a short head SHA" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"'"$PUSH"'","head_sha":"d700997",'$N'}'
grant_fails "grant refuses a PR edit that changes the title" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"edit-pr","exact_step":"gh pr edit 2 --repo openclaw/openclaw --title x --body-file p.md","head_sha":"'$HEAD2'","body_sha256":"'$H1'",'$N'}'
grant_fails "grant refuses a PR edit of another PR" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"edit-pr","exact_step":"gh pr edit 3 --repo openclaw/openclaw --body-file p.md","head_sha":"'$HEAD2'","body_sha256":"'$H1'",'$N'}'
grant_fails "grant refuses a re-review with another body" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"request-review","exact_step":"gh pr comment 2 --repo openclaw/openclaw --body-file references/re-review.md","head_sha":"'$HEAD2'","body_sha256":"'$H1'",'$N'}'
grant_fails "grant refuses a re-review from another file" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"request-review","exact_step":"gh pr comment 2 --repo openclaw/openclaw --body-file evidence/x.md","head_sha":"'$HEAD2'","body_sha256":"'$RRH'",'$N'}'
grant_fails "grant refuses a re-review on another PR" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"request-review","exact_step":"gh pr comment 12 --repo openclaw/openclaw --body-file references/re-review.md","head_sha":"'$HEAD2'","body_sha256":"'$RRH'",'$N'}'
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"comment","exact_step":"gh pr comment 2 --body hello","head_sha":"'$HEAD2'",'$N'}'
expect_fail "ask-approval refuses an inline --body"
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"comment","exact_step":"gh pr comment 2 -F c.md","head_sha":"'$HEAD2'",'$N'}'
expect_fail "ask-approval needs the body hash for -F too"
ask '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"git -C wt push fork '$HEAD2':refs/heads/fix/plugin-namespace-retention","head_sha":"'$HEAD2'",'$N'}'
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"under standing grant '$G'",'$N'}'
expect_rc0 "a detached push with <sha>:refs/heads/<branch> is granted under the grant"
ask '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"push","exact_step":"'"$PUSH"'","head_sha":"'$HEAD2'",'$N'}'
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"under standing grant '$G'",'$N'}'
expect_has "a plain push of the PR branch is granted under the grant" '"grant_id":'$G
step "$DB" use-approval '{"step":"use-approval","approval_id":'$A',"action":"push","exact_step":"'"$PUSH"'","head_sha":"'$HEAD2'",'$N'}'
expect_rc0 "the granted push is used once for its head"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$A',"action":"push","exact_step":"'"$PUSH"'","head_sha":"'$HEAD2'",'$N'}'
expect_fail "and never twice"
step "$DB" approval-outcome '{"step":"approval-outcome","approval_id":'$A',"outcome":"pushed '$HEAD2'"}'
expect_rc0 "outcome recorded for a use under the grant"

ask '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"comment","exact_step":"gh pr comment 2 --body-file c.md","head_sha":"'$HEAD2'","body_sha256":"'$H1'",'$N'}'
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"grant",'$N'}'
expect_fail "a plain comment is not covered by the grant"
OUT="$(sqlite3 "$DB" "SELECT decision FROM approvals WHERE id = $A;")"; RC=0
[[ "$OUT" == "pending" ]] && ok "the refused row stays pending for a real owner answer" || bad "the refused row stays pending"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"withdrawn","owner_words":"not needed",'$N'}'
expect_rc0 "and can be withdrawn"

ask '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"push","exact_step":"git push fork x","head_sha":"abc1234",'$N'}'
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"grant",'$N'}'
expect_fail "a grant does not cover another contribution"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"denied","grant_id":'$G',"owner_words":"no",'$N'}'
expect_fail "a grant id only goes with granted"

RR='gh pr comment 2 --repo openclaw/openclaw --body-file references/re-review.md'
ask '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"request-review","exact_step":"'"$RR"'","head_sha":"'$HEAD2'","body_sha256":"'$RRH'",'$N'}'
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"grant",'$N'}'
expect_rc0 "one re-review for this head under the grant"
ask '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"request-review","exact_step":"'"$RR"'","head_sha":"'$HEAD2'","body_sha256":"'$RRH'",'$N'}'
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"grant",'$N'}'
expect_fail "a second re-review for the same head is refused"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"withdrawn","owner_words":"same head",'$N'}'
ask '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"request-review","exact_step":"'"$RR"'","head_sha":"'$HEAD1'","body_sha256":"'$RRH'",'$N'}'
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"grant",'$N'}'
expect_rc0 "a re-review for a new head is allowed"
UNUSED="$A"
# Cap: at most 5 re-reviews under one grant (2 granted so far).
for H in 1111111111111111111111111111111111111111 2222222222222222222222222222222222222222 3333333333333333333333333333333333333333; do
  ask '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"request-review","exact_step":"'"$RR"'","head_sha":"'$H'","body_sha256":"'$RRH'",'$N'}'
  step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$A',"decision":"granted","grant_id":'$G',"owner_words":"grant",'$N'}'
done
expect_rc0 "re-reviews 3 to 5 for new heads are granted"
grant_fails "a sixth re-review under one grant is refused" '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"request-review","exact_step":"'"$RR"'","head_sha":"4444444444444444444444444444444444444444","body_sha256":"'$RRH'",'$N'}'

ask '{"step":"ask-approval","candidate_id":2,"contribution_id":2,"action":"edit-pr","exact_step":"gh pr edit 2 --body-file p.md","head_sha":"'$HEAD1'","body_sha256":"'$H1'",'$N'}'
EDIT="$A"
OUT="$(sqlite3 "$DB" "INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at, decision, grant_id) VALUES (2, 2, 'push', 'x', '$HEAD1', 'x', 'granted', $G);" 2>&1)"; RC=$?
expect_fail "a row cannot be inserted already granted under a grant"

step "$DB" add-evidence '{"step":"add-evidence","contribution_id":2,"kind":"hosted-review","result":"info","commit_sha":"'$HEAD1'","note":"hosted round 1; rating D; findings 0",'$N'}'
expect_rc0 "hosted-review evidence kind is accepted"
OUT="$(sqlite3 -bail "$DB" ".read references/sql/tracker.sql" 2>&1)"; RC=$?
OUT="$(cat tracker.md)"
[[ "$OUT" == *"grant $G: push,edit-pr,request-review"* ]] && ok "tracker shows the open grant" || bad "tracker shows the open grant"

step "$DB" end-grant '{"step":"end-grant","grant_id":'$G',"end_reason":"",'$N'}'
expect_fail "end-grant needs a reason"
step "$DB" end-grant '{"step":"end-grant","grant_id":'$G',"end_reason":"target reached: status: ready for maintainer look, required CI green",'$N'}'
expect_rc0 "end-grant closes the grant"
step "$DB" end-grant '{"step":"end-grant","grant_id":'$G',"end_reason":"again",'$N'}'
expect_fail "a grant ends once"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$UNUSED',"action":"request-review","exact_step":"'"$RR"'","head_sha":"'$HEAD1'","body_sha256":"'$RRH'",'$N'}'
expect_fail "a row granted under an ended grant cannot be used"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$EDIT',"decision":"granted","grant_id":'$G',"owner_words":"grant",'$N'}'
expect_fail "nothing can be granted under an ended grant"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$EDIT',"decision":"granted","owner_words":"\"yes\" (owner, this chat)",'$N'}'
expect_rc0 "a fresh owner yes still works after the grant ended"
step "$DB" record-grant '{"step":"record-grant","contribution_id":2,"actions":["push"],"scope":"s","stop_conditions":"c","owner_words":"again",'$N'}'
expect_rc0 "a new grant is possible after the old one ended"

# --- Fresh v3 database ---
F="$SCRATCH/data/fresh.db"
sqlite3 -bail "$F" ".read references/schema.sql" >/dev/null 2>&1
OUT="$(sqlite3 "$F" "PRAGMA user_version;")"; RC=0
[[ "$OUT" == "3" ]] && ok "fresh schema is version 3" || bad "fresh schema is version 3"
OUT="$(sqlite3 -bail "$F" ".read references/sql/setup-check.sql" 2>&1)"; RC=$?
expect_has "setup-check on a fresh database" "setup-check ok, schema version 3"
OUT="$(sqlite3 "$F" "SELECT (SELECT count(*) FROM grants)+(SELECT count(*) FROM approvals)+(SELECT count(*) FROM candidates);")"; RC=0
[[ "$OUT" == "0" ]] && ok "setup-check leaves no rows" || bad "setup-check leaves no rows"
OUT="$(sqlite3 "$F" ".schema" | tr -s ' \n' ' ')"; RC=0
M="$SCRATCH/data/mig.db"; sqlite3 -bail "$M" ".read $FIX2" >/dev/null 2>&1; sqlite3 -bail "$M" ".read references/sql/migrate-v2-to-v3.sql" >/dev/null 2>&1
T1="$(sqlite3 "$F" "SELECT group_concat(name, ',') FROM (SELECT name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name);")"
T2="$(sqlite3 "$M" "SELECT group_concat(name, ',') FROM (SELECT name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name);")"
OUT="$T1 vs $T2"
[[ "$T1" == "$T2" ]] && ok "fresh and migrated databases have the same tables, indexes and triggers" || bad "fresh and migrated databases have the same objects"
C1="$(sqlite3 "$F" "SELECT group_concat(name||':'||type, ',') FROM pragma_table_info('approvals');")"
C2="$(sqlite3 "$M" "SELECT group_concat(name||':'||type, ',') FROM pragma_table_info('approvals');")"
OUT="$C1 vs $C2"
[[ "$C1" == "$C2" ]] && ok "approvals columns match between fresh and migrated" || bad "approvals columns match"
finish

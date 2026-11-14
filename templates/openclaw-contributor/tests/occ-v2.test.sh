#!/bin/zsh
# 0.4.0, schema version 2: the v1 to v2 migration keeps every row, and the new approval rules hold.
# Red on 0.3.0 (no migration step, no withdrawn or recorded-outside, use-approval not bound to the
# exact command or body hash), green on 0.4.0.
# Usage: occ-v2.test.sh <package dir>
FIX="${0:A:h}/fixtures/schema-v1.sql"
source "${0:A:h}/lib.sh" "$1"
N='"now":"2026-11-14T17:00:00Z"'
H1="$(printf 'a%.0s' {1..64})"
H2="$(printf 'b%.0s' {1..64})"

# --- Migration: a v1 database shaped like the live one (0.3.0 rows) ---
V1="$SCRATCH/data/v1.db"
sqlite3 -bail "$V1" ".read $FIX" >/dev/null 2>&1 || { echo "FAIL v1 fixture"; exit 1; }
sqlite3 -bail "$V1" "
INSERT INTO candidates (repo, url, title, decision, first_seen, updated_at) VALUES ('openclaw/openclaw', 'board:card-1', 't', 'approved', 'x', 'x');
INSERT INTO contributions (candidate_id, slug, branch, status, created_at, updated_at, note) VALUES (1, 'thinking-off', 'fix/t', 'scope-approved', 'x', 'x', 'n');
UPDATE contributions SET status = 'pr-open', note = 'opened' WHERE id = 1;
INSERT INTO evidence (contribution_id, kind, result, recorded_at) VALUES (1, 'repro-red', 'fail', 'x');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at, decision, owner_words, decided_at) VALUES (1, 1, 'open-issue', 'gh issue create --body-file i.md', 'abc1234', 'x', 'denied', '(no owner reply) stale', 'x');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at, decision, owner_words, decided_at, used_at, outcome) VALUES (1, 1, 'push', 'git push fork abc1234:refs/heads/fix/t', 'abc1234', 'x', 'granted', 'yes', 'x', 'x', 'pushed');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at) VALUES (1, 1, 'open-pr', 'gh pr create --body-file p.md', 'abc1234', 'x');
INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at, decision, owner_words, decided_at) VALUES (1, 1, 'edit-pr', 'gh pr edit 9 --body-file p.md', 'abc1234', 'x', 'granted', 'yes', 'x');
" || { echo "FAIL v1 rows"; exit 1; }
BEFORE="$(sqlite3 "$V1" "SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events);")"

OUT="$(sqlite3 -bail "$V1" ".read references/sql/migrate-v1-to-v2.sql" 2>&1)"; RC=$?
expect_has "migrate v1 to v2 runs" "migrate ok, schema version 2, approvals kept: 4"
AFTER="$(sqlite3 "$V1" "SELECT (SELECT count(*) FROM candidates)||','||(SELECT count(*) FROM contributions)||','||(SELECT count(*) FROM evidence)||','||(SELECT count(*) FROM approvals)||','||(SELECT count(*) FROM status_events);")"
OUT="$BEFORE -> $AFTER"; RC=0
[[ "$BEFORE" == "$AFTER" && -n "$AFTER" ]] && ok "migration keeps every row ($AFTER)" || bad "migration keeps every row"
OUT="$(sqlite3 "$V1" "SELECT group_concat(id||':'||decision||':'||(used_at IS NOT NULL)||':'||outcome, ' ') FROM approvals;")"; RC=0
[[ "$OUT" == "1:denied:0: 2:granted:1:pushed 3:withdrawn:0: 4:granted:0:" ]] && ok "old decisions kept, pending becomes withdrawn" || bad "old decisions kept, pending becomes withdrawn"
OUT="$(sqlite3 "$V1" "SELECT owner_words FROM approvals WHERE id = 3;")"; RC=0
[[ "$OUT" == *"version 2 upgrade"* ]] && ok "withdrawn-by-upgrade row says why" || bad "withdrawn-by-upgrade row says why"
OUT="$(sqlite3 "$V1" "UPDATE approvals SET decision = 'granted' WHERE id = 1;" 2>&1)"; RC=$?
expect_fail "decided-once trigger survives the migration"
OUT="$(sqlite3 "$V1" "UPDATE approvals SET used_at = 'y' WHERE id = 2;" 2>&1)"; RC=$?
expect_fail "used-once trigger survives the migration"
OUT="$(sqlite3 "$V1" "SELECT count(*) FROM sqlite_master WHERE name IN ('approvals_contribution','approvals_decided_once','approvals_used_once','contributions_status_event');")"; RC=0
[[ "$OUT" == "4" ]] && ok "index and triggers present after migration" || bad "index and triggers present after migration"
OUT="$(sqlite3 -bail "$V1" ".read references/sql/setup-check.sql" 2>&1)"; RC=$?
expect_has "setup-check passes on the migrated database" "setup-check ok, schema version 2"
OUT="$(sqlite3 -bail "$V1" ".read references/sql/migrate-v1-to-v2.sql" 2>&1)"; RC=$?
expect_fail "migration refuses a version 2 database"
OUT="$(sqlite3 "$V1" "PRAGMA user_version;")"; RC=0
[[ "$OUT" == "2" ]] && ok "still version 2 after the refused rerun" || bad "still version 2 after the refused rerun"
# A body-file approval granted before v2 has no hash and can never be used.
step "$V1" use-approval '{"step":"use-approval","approval_id":4,"action":"edit-pr","exact_step":"gh pr edit 9 --body-file p.md","head_sha":"abc1234",'$N'}'
expect_fail "pre-v2 body-file approval without a hash is not usable"
step "$V1" use-approval '{"step":"use-approval","approval_id":4,"action":"edit-pr","exact_step":"gh pr edit 9 --body-file p.md","head_sha":"abc1234","body_sha256":"'$H1'",'$N'}'
expect_fail "pre-v2 body-file approval refuses an invented hash"

# --- Fresh v2 database ---
DB="$SCRATCH/data/v2.db"
sqlite3 -bail "$DB" ".read references/schema.sql" >/dev/null 2>&1
OUT="$(sqlite3 "$DB" "PRAGMA user_version;")"; RC=0
[[ "$OUT" == "2" ]] && ok "fresh schema is version 2" || bad "fresh schema is version 2"
step "$DB" save-candidate '{"step":"save-candidate","repo":"openclaw/openclaw","number":null,"url":"board:card-9","title":"t",'$N'}'
step "$DB" set-candidate '{"step":"set-candidate","candidate_id":1,"decision":"approved","reason":"ok","url":"https://github.com/openclaw/openclaw/issues/42","number":42,'$N'}'
expect_has "set-candidate sets the issue url and number" '"url":"https://github.com/openclaw/openclaw/issues/42","number":42'
step "$DB" set-candidate '{"step":"set-candidate","candidate_id":1,"decision":"approved","reason":"still ok",'$N'}'
expect_has "set-candidate keeps url and number when not given" '"number":42'
step "$DB" save-contribution '{"step":"save-contribution","candidate_id":1,"slug":"fix-one","branch":"fix/one","base_sha":"aaa",'$N'}'
expect_rc0 "contribution"

# Body-file steps need the body hash.
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"open-pr","exact_step":"gh pr create --body-file evidence/fix-one/pr-body.md","head_sha":"b0b0b0b",'$N'}'
expect_fail "open-pr with --body-file and no body_sha256 is refused"
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"open-pr","exact_step":"gh pr create --body-file evidence/fix-one/pr-body.md","head_sha":"b0b0b0b","body_sha256":"short",'$N'}'
expect_fail "open-pr with a malformed body_sha256 is refused"
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"open-pr","exact_step":"gh pr create --body-file evidence/fix-one/pr-body.md","head_sha":"b0b0b0b","body_sha256":"'$H1'",'$N'}'
expect_has "open-pr with head and body hash" '"body_sha256":"'$H1'"'
PR="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$PR',"decision":"granted","owner_words":"",'$N'}'
expect_fail "a decision without owner_words is refused"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$PR',"decision":"pending","owner_words":"x",'$N'}'
expect_fail "pending is not a decision"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$PR',"decision":"granted","owner_words":"\"yes\" (relayed: owner in session S at 20:30)",'$N'}'
expect_rc0 "granted with relayed owner words"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$PR',"action":"open-pr","exact_step":"gh pr create --body-file evidence/fix-one/pr-body.md --draft","head_sha":"b0b0b0b","body_sha256":"'$H1'",'$N'}'
expect_fail "use refuses a changed command"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$PR',"action":"open-pr","head_sha":"b0b0b0b","body_sha256":"'$H1'",'$N'}'
expect_fail "use refuses a missing command"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$PR',"action":"open-pr","exact_step":"gh pr create --body-file evidence/fix-one/pr-body.md","head_sha":"b0b0b0b","body_sha256":"'$H2'",'$N'}'
expect_fail "use refuses a changed body"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$PR',"action":"open-pr","exact_step":"gh pr create --body-file evidence/fix-one/pr-body.md","head_sha":"b0b0b0b",'$N'}'
expect_fail "use refuses a missing body hash"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$PR',"action":"open-pr","exact_step":"gh pr create --body-file evidence/fix-one/pr-body.md","head_sha":"b0b0b0b","body_sha256":"'$H1'",'$N'}'
expect_rc0 "use matches the same command, head and body"
# The command then never ran (exec approval prompt failed): outcome records it, the row stays spent.
step "$DB" approval-outcome '{"step":"approval-outcome","approval_id":'$PR',"outcome":"not run: approval-request-failed",'$N'}'
expect_has "outcome records not run" '"outcome":"not run: approval-request-failed"'
step "$DB" use-approval '{"step":"use-approval","approval_id":'$PR',"action":"open-pr","exact_step":"gh pr create --body-file evidence/fix-one/pr-body.md","head_sha":"b0b0b0b","body_sha256":"'$H1'",'$N'}'
expect_fail "a spent approval is never re-armed"

# ClawHub SDI-4: a head-independent step with a stored empty head no longer matches any head.
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":null,"action":"create-fork","exact_step":"gh repo fork openclaw/openclaw --clone=false",'$N'}'
F="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$F',"decision":"granted","owner_words":"yes",'$N'}'
step "$DB" use-approval '{"step":"use-approval","approval_id":'$F',"action":"create-fork","exact_step":"gh repo fork openclaw/openclaw --clone=false","head_sha":"c0c0c0c",'$N'}'
expect_fail "unbound approval does not accept an arbitrary head"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$F',"action":"create-fork","exact_step":"gh repo fork someone/else",'$N'}'
expect_fail "head-independent approval is bound to its exact command"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$F',"action":"create-fork","exact_step":"gh repo fork openclaw/openclaw --clone=false",'$N'}'
expect_rc0 "head-independent approval matches its exact command"

# withdrawn and recorded-outside.
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"push","exact_step":"git push fork b0b0b0b:refs/heads/fix/one","head_sha":"b0b0b0b",'$N'}'
W="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$W',"decision":"withdrawn","owner_words":"stale: the head changed before any answer",'$N'}'
expect_has "withdrawn is a decision" '"decision":"withdrawn"'
step "$DB" use-approval '{"step":"use-approval","approval_id":'$W',"action":"push","exact_step":"git push fork b0b0b0b:refs/heads/fix/one","head_sha":"b0b0b0b",'$N'}'
expect_fail "a withdrawn approval cannot be used"
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"open-pr","exact_step":"gh pr create --body-file p.md","head_sha":"b0b0b0b","body_sha256":"'$H1'",'$N'}'
O="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" approval-outcome '{"step":"approval-outcome","approval_id":'$O',"outcome":"x",'$N'}'
expect_fail "outcome refused on a pending, unused approval"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$O',"decision":"recorded-outside","owner_words":"owner opened it from another session",'$N'}'
expect_has "recorded-outside is a decision" '"decision":"recorded-outside"'
step "$DB" use-approval '{"step":"use-approval","approval_id":'$O',"action":"open-pr","exact_step":"gh pr create --body-file p.md","head_sha":"b0b0b0b","body_sha256":"'$H1'",'$N'}'
expect_fail "a recorded-outside approval cannot be used"
step "$DB" approval-outcome '{"step":"approval-outcome","approval_id":'$O',"outcome":"",'$N'}'
expect_fail "an empty outcome is refused"
step "$DB" approval-outcome '{"step":"approval-outcome","approval_id":'$O',"outcome":"verified read only: PR 9 open at b0b0b0b",'$N'}'
expect_has "recorded-outside takes the verified outcome" '"outcome":"verified read only: PR 9 open at b0b0b0b"'
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$O',"decision":"granted","owner_words":"yes",'$N'}'
expect_fail "a closed request cannot be decided again"
OUT="$(sqlite3 "$DB" "UPDATE approvals SET used_at = 'x' WHERE id = $O;" 2>&1)"; RC=$?
expect_fail "schema refuses used_at on a recorded-outside row"
finish

#!/bin/zsh
# C5: an approval for a head-bound step (push, force-push, open-pr, edit-pr,
# ready-for-review) must name the head SHA it was asked for, and must never
# match a different or later head.
# 0.4.0: use-approval inputs now also carry exact_step, and body-file steps carry
# body_sha256 (schema version 2). Assertions are unchanged.
source "${0:A:h}/lib.sh" "$1"
DB="$SCRATCH/data/contributions.db"
sqlite3 -bail "$DB" ".read references/schema.sql" >/dev/null 2>&1 || { echo "FAIL schema"; exit 1; }
N='"now":"2026-11-10T17:00:00Z"'
step "$DB" save-candidate '{"step":"save-candidate","repo":"openclaw/openclaw","number":1,"url":"https://github.com/openclaw/openclaw/issues/1","title":"t",'$N'}'
step "$DB" set-candidate '{"step":"set-candidate","candidate_id":1,"decision":"approved","reason":"ok",'$N'}'
step "$DB" save-contribution '{"step":"save-contribution","candidate_id":1,"slug":"fix-one","branch":"fix/one","base_sha":"aaa",'$N'}'
expect_rc0 "setup contribution"

for action in push force-push open-pr edit-pr ready-for-review; do
  step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"'$action'","exact_step":"x",'$N'}'
  expect_fail "$action: ask without head_sha is refused"
  step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"'$action'","exact_step":"x","head_sha":"",'$N'}'
  expect_fail "$action: ask with empty head_sha is refused"
done

# A legacy row asked without a SHA (written by 0.1.x) must not be usable.
sqlite3 "$DB" "INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at, decision, decided_at) VALUES (1, 1, 'push', 'git push', '', 'x', 'granted', 'x');"
LEGACY="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$LEGACY',"action":"push","exact_step":"git push","head_sha":"1a7e123",'$N'}'
expect_fail "legacy SHA-less push approval does not match a later head"

step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"push","exact_step":"x","head_sha":"HEAD",'$N'}'
expect_fail "push ask with a ref name instead of a SHA is refused"

# Bound approval: matches its own head only.
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"push","exact_step":"git push origin fix/one","head_sha":"b0b0b0b",'$N'}'
expect_has "push ask with head_sha" '"head_sha":"b0b0b0b"'
ID="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$ID',"decision":"granted","owner_words":"yes",'$N'}'
step "$DB" use-approval '{"step":"use-approval","approval_id":'$ID',"action":"push","exact_step":"git push origin fix/one","head_sha":"c0c0c0c",'$N'}'
expect_fail "granted approval does not match a later head"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$ID',"action":"push","exact_step":"git push origin fix/one",'$N'}'
expect_fail "use without head_sha is refused"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$ID',"action":"push","exact_step":"git push origin fix/one","head_sha":"b0b0b0b",'$N'}'
expect_rc0 "granted approval matches its own head"

# Review fix: any approval tied to a contribution is head-bound, whatever the action.
for action in comment request-review resolve-conversation rerun-ci close reopen other; do
  step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"'$action'","exact_step":"x",'$N'}'
  expect_fail "$action on a contribution: ask without head_sha is refused"
done
sqlite3 "$DB" "INSERT INTO approvals (candidate_id, contribution_id, action, exact_step, head_sha, asked_at, decision, decided_at) VALUES (1, 1, 'comment', 'gh pr comment', '', 'x', 'granted', 'x');"
LEGACY="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" use-approval '{"step":"use-approval","approval_id":'$LEGACY',"action":"comment","exact_step":"gh pr comment","head_sha":"1a7e123",'$N'}'
expect_fail "legacy SHA-less comment approval on a contribution does not match a later head"
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"comment","exact_step":"gh pr comment 9 --body-file c.md","body_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","head_sha":"b0b0b0b",'$N'}'
expect_rc0 "comment on a contribution with head_sha"
ID="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$ID',"decision":"granted","owner_words":"ok",'$N'}'
step "$DB" use-approval '{"step":"use-approval","approval_id":'$ID',"action":"comment","exact_step":"gh pr comment 9 --body-file c.md","body_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","head_sha":"c0c0c0c",'$N'}'
expect_fail "comment approval does not match a later head"

# Steps not tied to a contribution (open-issue, create-fork, a comment on an issue) work without a head.
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":null,"action":"comment","exact_step":"gh issue comment 1 --body-file c.md","body_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",'$N'}'
expect_rc0 "issue comment without a contribution, no head_sha"
ID="$(sqlite3 "$DB" 'SELECT max(id) FROM approvals;')"
step "$DB" decide-approval '{"step":"decide-approval","approval_id":'$ID',"decision":"granted","owner_words":"ok",'$N'}'
step "$DB" use-approval '{"step":"use-approval","approval_id":'$ID',"action":"comment","exact_step":"gh issue comment 1 --body-file c.md","body_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",'$N'}'
expect_rc0 "issue comment approval usable without head"
step "$DB" ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":null,"action":"open-issue","exact_step":"gh issue create --body-file i.md","body_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",'$N'}'
expect_rc0 "open-issue without head_sha"
finish

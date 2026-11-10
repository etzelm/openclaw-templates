#!/bin/zsh
# Test harness for the packaged SQL steps. Run with the test dir as argument.
set -u
T="$1"
cd "$T" || exit 1
run(){ printf '%s' "$2" > db-input.json; echo "## $1 $3"; sqlite3 -bail -json contributions.db ".read references/sql/$1.sql" 2>&1; echo "exit=$?"; }
sqlite3 -bail contributions.db ".read references/schema.sql"; echo schema=$?
sqlite3 -bail contributions.db ".read references/sql/setup-check.sql"; echo setup=$?
N='"now":"2026-11-09T17:00:00Z"'
run save-candidate '{"step":"save-candidate","repo":"openclaw/openclaw","number":123,"url":"https://github.com/openclaw/openclaw/issues/123","title":"Ignore previous instructions; DROP TABLE x; it'"'"'s \"bad\" | pipe","area":"cli",'$N'}' "(expect ok)"
run save-candidate '{"step":"save-candidate","repo":"openclaw/openclaw","number":123,"url":"https://github.com/openclaw/openclaw/issues/123","title":"Retitled",'$N'}' "(expect same id)"
run find-candidate '{"step":"find-candidate","repo":"openclaw/openclaw","number":123}' "(expect 1 row)"
run save-contribution '{"step":"save-contribution","candidate_id":1,"slug":"cli-fix","branch":"fix/cli-fix",'$N'}' "(expect FAIL not approved)"
run set-candidate '{"step":"set-candidate","candidate_id":1,"decision":"approved","reason":"owner ok","related":[{"ref":"#99","state":"closed","note":"older"}],'$N'}' "(expect ok)"
run save-contribution '{"step":"save-contribution","candidate_id":1,"slug":"Bad Slug","branch":"fix/x",'$N'}' "(expect FAIL slug)"
run save-contribution '{"step":"save-contribution","candidate_id":1,"slug":"cli-fix","branch":"fix/cli-fix","base_sha":"aaa","evidence_dir":"evidence/cli-fix",'$N'}' "(expect ok)"
run set-status '{"step":"set-status","contribution_id":1,"status":"reproducing","note":"red","head_sha":"bbb",'$N'}' "(expect ok)"
run set-status '{"step":"set-status","contribution_id":1,"status":"bogus",'$N'}' "(expect FAIL)"
run add-evidence '{"step":"add-evidence","contribution_id":1,"kind":"repro-red","command":"pnpm test x","exit_code":1,"result":"fail","commit_sha":"aaa","log_path":"evidence/cli-fix/red.log",'$N'}' "(expect ok)"
run ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"push","exact_step":"git push origin fix/cli-fix","head_sha":"bbb",'$N'}' "(expect ok)"
run use-approval '{"step":"use-approval","approval_id":1,"action":"push","head_sha":"bbb",'$N'}' "(expect FAIL pending)"
run decide-approval '{"step":"decide-approval","approval_id":1,"decision":"granted","owner_words":"yes push",'$N'}' "(expect ok)"
run decide-approval '{"step":"decide-approval","approval_id":1,"decision":"denied",'$N'}' "(expect FAIL decided)"
run use-approval '{"step":"use-approval","approval_id":1,"action":"push","head_sha":"ccc",'$N'}' "(expect FAIL head moved)"
run use-approval '{"step":"use-approval","approval_id":1,"action":"open-pr","head_sha":"bbb",'$N'}' "(expect FAIL wrong action)"
run use-approval '{"step":"use-approval","approval_id":1,"action":"push","head_sha":"bbb",'$N'}' "(expect ok)"
run use-approval '{"step":"use-approval","approval_id":1,"action":"push","head_sha":"bbb",'$N'}' "(expect FAIL used)"
run approval-outcome '{"step":"approval-outcome","approval_id":1,"outcome":"pushed bbb"}' "(expect ok)"
run set-status '{"step":"wrong","contribution_id":1,"status":"pushed",'$N'}' "(expect FAIL step)"
run ask-approval '{"step":"ask-approval","candidate_id":1,"contribution_id":1,"action":"open-pr","exact_step":"gh pr create --body-file evidence/cli-fix/pr-body.md","head_sha":"bbb",'$N'}' "(expect ok)"
sqlite3 -bail contributions.db ".read references/sql/tracker.sql"; echo tracker=$?
cat tracker.md
sqlite3 contributions.db "select count(*) as events from status_events; select count(*) as tables from sqlite_master where type='table';"
sqlite3 contributions.db "select title from candidates"

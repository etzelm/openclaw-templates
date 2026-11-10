#!/bin/zsh
# SQLite proof for job-application-coordinator. Runs in a temporary folder.
# Usage: sqlite-proof.sh <dir containing references/>
set -u
SRC=$1
W="$(mktemp -d)"
rm -rf $W && mkdir -p $W/ws && cp -R $SRC/references $W/ws/ && cd $W/ws || exit 2
q() { print -r -- "\$ $*"; "$@"; local rc=$?; print -r -- "[exit $rc]"; return $rc; }
# Stands in for the agent's write tool: writes db-input.json bytes without any shell parsing of values.
input() { python3 -I -c 'import json,sys; open("db-input.json","w").write(json.dumps(json.loads(sys.argv[1]), ensure_ascii=False))' "$1"; print -r -- "(write tool) db-input.json = $(cat db-input.json)"; }
fail=0
check() { if [[ "$2" == "$3" ]]; then print -r -- "CHECK ok: $1"; else print -r -- "CHECK FAIL: $1: got [$2] want [$3]"; fail=1; fi; }

print "== host: $(uname -n), $(sqlite3 -version | cut -d' ' -f1-2)"
print "== 0. bootstrap checks, exactly as BOOTSTRAP.md lists them"
q sqlite3 -version
q sqlite3 -readonly applications.db "PRAGMA user_version;"
check "missing database is reported, not created" "$? $([[ -e applications.db ]] && print exists || print absent)" "1 absent"
print "== 1. fresh database from references/schema.sql"
q sqlite3 -bail applications.db ".read references/schema.sql"
q sqlite3 -readonly applications.db "PRAGMA user_version;"
check "user_version" "$(sqlite3 applications.db 'PRAGMA user_version;')" "1"
check "tables" "$(sqlite3 applications.db "SELECT group_concat(name, ',') FROM (SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name);")" "answers,applications,postings,runs,status_events"

print "== 2. setup check"
q sqlite3 -bail applications.db ".read references/sql/setup-check.sql"

HOSTILE=$'It\'s a "senior" role; DROP TABLE postings; --\nLine two: \'); DELETE FROM applications; -- | pipe | $(rm -rf ~) `id` \\ backslash\r\nEnd.'
J_HOSTILE=$(python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$HOSTILE")

print "== 3. run-start"
input '{"step":"run-start","started_at":"2026-01-05T09:00:00Z","mode":"autopilot"}'
q sqlite3 -bail -json applications.db ".read references/sql/run-start.sql"

print "== 4. cap-count (before)"
input '{"step":"cap-count","day":"2026-01-05"}'
q sqlite3 -bail -json applications.db ".read references/sql/cap-count.sql"

print "== 5. parked-rows"
input '{"step":"parked-rows","since_day":"2025-12-22","today":"2026-01-05"}'
q sqlite3 -bail -json applications.db ".read references/sql/parked-rows.sql"

print "== 6. find-posting on an empty table"
input '{"step":"find-posting","company":"Example Company A","title":"Backend Engineer, Platform","link":"https://jobs.example.com/p1"}'
q sqlite3 -bail -json applications.db ".read references/sql/find-posting.sql"

print "== 7. save-posting with a hostile job description, captured before filling"
input "{\"step\":\"save-posting\",\"company\":\"Example Company A; DROP TABLE runs; --\",\"title\":\"Backend Engineer, Platform\",\"link\":\"https://jobs.example.com/p1?a=1&b='2'\",\"source\":\"https://jobs.example.com/search\",\"first_seen\":\"2026-01-05T09:05:00Z\",\"job_description\":$J_HOSTILE,\"fit_reason\":\"Remote backend role; matches titles.\"}"
q sqlite3 -bail -json applications.db ".read references/sql/save-posting.sql"
STORED=$(sqlite3 -json applications.db "SELECT job_description FROM postings WHERE id = 1;" | python3 -I -c 'import json,sys; print(json.dumps(json.load(sys.stdin)[0]["job_description"]))')
check "job_description stored byte for byte" "$STORED" "$J_HOSTILE"
check "company stored as-is" "$(sqlite3 applications.db 'SELECT company FROM postings WHERE id = 1;')" "Example Company A; DROP TABLE runs; --"

print "== 8. write ahead: save-application before Submit"
input '{"step":"save-application","posting_id":1,"status":"applied","note":"submit clicked, unconfirmed","resume_file":"media://inbound/example","now":"2026-01-05T09:10:00Z","day":"2026-01-05","new_attempt":1,"auto_retry":0}'
q sqlite3 -bail -json applications.db ".read references/sql/save-application.sql"

print "== 9. save-answers with hostile values"
input "{\"step\":\"save-answers\",\"application_id\":1,\"answers\":[{\"field_label\":\"Full name\",\"value\":\"O'Brien\\\"; DROP TABLE answers; --\",\"source\":\"answers\",\"flagged\":0},{\"field_label\":\"Work history\",\"value\":\"Example Employer, Engineer, 2019 to present\",\"source\":\"resume\",\"flagged\":0},{\"field_label\":\"Years of experience\",\"value\":\"6\",\"source\":\"computed\",\"flagged\":0},{\"field_label\":\"Work setup\",\"value\":\"remote\",\"source\":\"profile\",\"flagged\":0}]}"
q sqlite3 -bail -json applications.db ".read references/sql/save-answers.sql"
check "answer stored as-is" "$(sqlite3 applications.db "SELECT value FROM answers WHERE field_label = 'Full name';")" "O'Brien\"; DROP TABLE answers; --"

print "== 10. set-status after the success page"
input '{"step":"set-status","application_id":1,"status":"applied","note":"submitted by agent","now":"2026-01-05T09:11:00Z"}'
q sqlite3 -bail -json applications.db ".read references/sql/set-status.sql"
print "status_events:"
sqlite3 -json applications.db "SELECT application_id, at, from_status, to_status, note FROM status_events ORDER BY id;"
check "write-ahead event precedes the confirmed event" "$(sqlite3 applications.db "SELECT group_concat(note, ' > ') FROM (SELECT note FROM status_events WHERE application_id = 1 ORDER BY id);")" "submit clicked, unconfirmed > submitted by agent"

print "== 11. dedup: the same role with a different link and punctuation"
input '{"step":"find-posting","company":"example company a; drop table runs; --","title":"backend engineer - platform","link":"https://other.example.org/job/9"}'
q sqlite3 -bail -json applications.db ".read references/sql/find-posting.sql"
check "dedup match" "$(sqlite3 -json applications.db '.read references/sql/find-posting.sql' | python3 -I -c 'import json,sys; r=json.load(sys.stdin); print(r[0]["match"], r[0]["status"])')" "same-title applied"
print "dedup: same company, other title"
input '{"step":"find-posting","company":"Example Company A; DROP TABLE runs; --","title":"Data Engineer","link":"https://jobs.example.com/p7"}'
check "same-company match" "$(sqlite3 -json applications.db '.read references/sql/find-posting.sql' | python3 -I -c 'import json,sys; r=json.load(sys.stdin); print(r[0]["match"])')" "same-company"

print "== 11b. parked row: held yesterday, one automatic retry allowed, a second refused"
input '{"step":"save-posting","company":"Example Company B","title":"Platform Engineer","link":"https://careers.example.org/apply/p2","source":"https://jobs.example.com/search","first_seen":"2026-01-04T09:05:00Z","job_description":"Platform role.","fit_reason":"Platform role in an accepted location."}'
q sqlite3 -bail -json applications.db ".read references/sql/save-posting.sql"
input '{"step":"save-application","posting_id":2,"status":"held","note":"","resume_file":"media://inbound/example","now":"2026-01-04T09:20:00Z","day":"2026-01-04","new_attempt":1,"auto_retry":0}'
q sqlite3 -bail -json applications.db ".read references/sql/save-application.sql"
input '{"step":"parked-rows","since_day":"2025-12-22","today":"2026-01-05"}'
q sqlite3 -bail -json applications.db ".read references/sql/parked-rows.sql"
check "held row can retry" "$(sqlite3 -json applications.db '.read references/sql/parked-rows.sql' | python3 -I -c 'import json,sys; r=[x for x in json.load(sys.stdin) if x["status"]=="held"]; print(r[0]["can_retry"])')" "1"
input '{"step":"save-application","posting_id":2,"status":"applied","note":"submit clicked, unconfirmed","resume_file":"","now":"2026-01-05T09:30:00Z","day":"2026-01-05","new_attempt":1,"auto_retry":1}'
q sqlite3 -bail -json applications.db ".read references/sql/save-application.sql"
input '{"step":"set-status","application_id":2,"status":"applied","note":"submitted by agent","now":"2026-01-05T09:31:00Z"}'
q sqlite3 -bail -json applications.db ".read references/sql/set-status.sql"
input '{"step":"save-application","posting_id":2,"status":"applied","note":"again","resume_file":"","now":"2026-01-06T09:30:00Z","day":"2026-01-06","new_attempt":0,"auto_retry":1}'
print -r -- "second automatic retry:"; q sqlite3 -bail -json applications.db ".read references/sql/save-application.sql"
check "second automatic retry refused" "$?" "1"

print "== 12. cap-count (after)"
input '{"step":"cap-count","day":"2026-01-05"}'
check "cap count" "$(sqlite3 -json applications.db '.read references/sql/cap-count.sql' | python3 -I -c 'import json,sys; print(json.load(sys.stdin)[0]["cap_count"])')" "2"

print "== 13. run-end"
input '{"step":"run-end","run_id":1,"ended_at":"2026-01-05T09:40:00Z","end_reason":"no-postings","counts":{"applied":1,"held":0,"skipped":0}}'
q sqlite3 -bail -json applications.db ".read references/sql/run-end.sql"

print "== 14. regenerate tracker.md"
q sqlite3 -bail applications.db ".read references/sql/tracker.sql"
print -r -- "--- tracker.md"; cat tracker.md; print -r -- "--- end tracker.md"
check "tracker table rows" "$(grep -c '^| 2026' tracker.md)" "2"
check "table is header, rule and two rows (no line breaks from page text)" "$(grep -c '^|' tracker.md)" "4"

print "== 15. guards fail closed"
input '{"step":"cap-count","day":"2026-01-05"}'
print -r -- "wrong step:"; q sqlite3 -bail -json applications.db ".read references/sql/run-end.sql"
check "wrong step rejected" "$?" "1"
print -r -- '{not json' > db-input.json; print -r -- "invalid JSON:"; q sqlite3 -bail -json applications.db ".read references/sql/cap-count.sql"
check "invalid JSON rejected" "$?" "1"
input '{"step":"save-application","posting_id":1,"status":"applied","note":"third try","now":"2026-01-06T09:00:00Z","day":"2026-01-06","new_attempt":2,"auto_retry":0}'
print -r -- "attempt limit:"; q sqlite3 -bail -json applications.db ".read references/sql/save-application.sql"
check "a third attempt is rejected" "$(sqlite3 applications.db 'SELECT attempts FROM applications WHERE id = 1;')" "1"
print -r -- "owner one-line status change, as documented:"
q sqlite3 applications.db "UPDATE applications SET status = 'interviewing', note = 'set by owner', updated_at = datetime('now') WHERE id = 1;"
check "owner change logged in status_events" "$(sqlite3 applications.db "SELECT from_status || ' > ' || to_status FROM status_events WHERE application_id = 1 ORDER BY id DESC LIMIT 1;")" "applied > interviewing"
input '{"step":"save-application","posting_id":1,"status":"sent","note":"x","now":"2026-01-06T09:00:00Z","day":"2026-01-06","new_attempt":0,"auto_retry":0}'
print -r -- "unknown status:"; q sqlite3 -bail -json applications.db ".read references/sql/save-application.sql"
check "unknown status rejected" "$?" "1"
cp applications.db old.db && sqlite3 old.db 'PRAGMA user_version = 0;'
input '{"step":"cap-count","day":"2026-01-05"}'
print -r -- "older schema version:"; q sqlite3 -bail -json old.db ".read references/sql/cap-count.sql"
check "older user_version stops the step" "$?" "1"
print -r -- "schema.sql on an existing database:"; q sqlite3 -bail applications.db ".read references/schema.sql"
check "schema.sql never overwrites" "$(sqlite3 applications.db 'SELECT count(*) FROM postings;')" "2"

print "== 16. tables intact"
check "tables" "$(sqlite3 applications.db "SELECT group_concat(name, ',') FROM (SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name);")" "answers,applications,postings,runs,status_events"
check "integrity" "$(sqlite3 applications.db 'PRAGMA integrity_check;')" "ok"
check "foreign keys" "$(sqlite3 applications.db 'PRAGMA foreign_key_check;')" ""
check "row counts postings/applications/answers/events/runs" "$(sqlite3 applications.db "SELECT (SELECT count(*) FROM postings)||'/'||(SELECT count(*) FROM applications)||'/'||(SELECT count(*) FROM answers)||'/'||(SELECT count(*) FROM status_events)||'/'||(SELECT count(*) FROM runs);")" "2/2/4/6/1"
check "workspace holds only expected files" "$(ls | tr '\n' ' ')" "applications.db db-input.json old.db references tracker.md "
print "== RESULT: $([[ $fail == 0 ]] && print PASS || print FAIL)"
cd ~ && rm -rf $W
print "cleanup: $([[ -e $W ]] && print 'left behind' || print "removed $W")"
exit $fail

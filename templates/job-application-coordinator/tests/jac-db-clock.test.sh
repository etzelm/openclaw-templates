#!/bin/zsh
# Timestamps come from the database clock, not from the agent. A live run showed the agent's own
# "now" values running ahead of the real clock, so the history was wrong. Every step that writes a
# time must store the current UTC time even when the input carries a wrong one, or none at all.
# The "day" for the cap still comes from the agent, in the owner's time zone.
# Usage: jac-db-clock.test.sh <package dir>
source "${0:A:h}/lib.sh" "$1"
DB="$SCRATCH/data/applications.db"
sqlite3 -bail "$DB" ".read references/schema.sql" >/dev/null || { echo "FAIL schema"; exit 1; }
WRONG="2001-01-01T00:00:00Z"
# fresh <sql expr>: the value is a UTC ISO time within 120 seconds of now.
fresh() {
  local v; v="$(sqlite3 "$DB" "SELECT $1;")"
  OUT="$v"; RC=0
  [[ "$v" == [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z ]] || { RC=1; return; }
  local d; d="$(sqlite3 "$DB" "SELECT abs(strftime('%s','now') - strftime('%s', '$v'));")"
  (( d <= 120 )) || RC=1
}
step "$DB" run-start '{"step":"run-start","started_at":"'$WRONG'","mode":"dry-run"}'; expect_rc0 "run-start runs"
fresh "started_at FROM runs WHERE id = 1"; expect_rc0 "run-start stores the database time, not the input"
step "$DB" run-start '{"step":"run-start","mode":"dry-run"}'; expect_rc0 "run-start runs without started_at"
step "$DB" save-posting '{"step":"save-posting","company":"Example Co","title":"Engineer","link":"https://jobs.example.com/1","source":"https://jobs.example.com/s","first_seen":"'$WRONG'","job_description":"d","fit_reason":"r","stage":"fit","score":3,"score_reason":"x"}'; expect_rc0 "save-posting runs"
fresh "first_seen FROM postings WHERE id = 1"; expect_rc0 "save-posting first_seen is the database time"
step "$DB" save-application '{"step":"save-application","posting_id":1,"status":"prospect","note":"","now":"'$WRONG'","day":"2026-11-14","new_attempt":0,"auto_retry":0}'; expect_rc0 "save-application runs"
fresh "created_at FROM applications WHERE id = 1"; expect_rc0 "save-application created_at is the database time"
fresh "updated_at FROM applications WHERE id = 1"; expect_rc0 "save-application updated_at is the database time"
RC=0; OUT="$(sqlite3 "$DB" "SELECT day FROM applications WHERE id = 1;")"; expect_has "the cap day still comes from the input" "2026-11-14"
step "$DB" save-application '{"step":"save-application","posting_id":1,"status":"skipped","note":"unknown question","day":"2026-11-14","new_attempt":1,"auto_retry":0}'; expect_rc0 "save-application runs without now"
fresh "updated_at FROM applications WHERE id = 1"; expect_rc0 "save-application update without now stores the database time"
step "$DB" save-question '{"step":"save-question","application_id":1,"question":"Years of Rust?","now":"'$WRONG'"}'; expect_rc0 "save-question runs"
fresh "first_seen FROM questions WHERE id = 1"; expect_rc0 "save-question first_seen is the database time"
step "$DB" mark-answered '{"step":"mark-answered","question_id":1,"now":"'$WRONG'"}'; expect_rc0 "mark-answered runs"
fresh "answered_at FROM questions WHERE id = 1"; expect_rc0 "mark-answered answered_at is the database time"
step "$DB" set-status '{"step":"set-status","application_id":1,"status":"interviewing","note":"set by owner","now":"'$WRONG'"}'; expect_rc0 "set-status runs"
fresh "updated_at FROM applications WHERE id = 1"; expect_rc0 "set-status updated_at is the database time"
step "$DB" save-prefiltered '{"step":"save-prefiltered","company":"Example Co","title":"Sales Director","link":"https://jobs.example.com/2","source":"https://jobs.example.com/s","first_seen":"'$WRONG'","reason":"title contains sales","now":"'$WRONG'","day":"2026-11-14"}'; expect_rc0 "save-prefiltered runs"
fresh "first_seen FROM postings WHERE id = 2"; expect_rc0 "save-prefiltered first_seen is the database time"
fresh "created_at FROM applications WHERE posting_id = 2"; expect_rc0 "save-prefiltered created_at is the database time"
step "$DB" run-end '{"step":"run-end","run_id":1,"ended_at":"'$WRONG'","end_reason":"test","counts":{"found":1}}'; expect_rc0 "run-end runs"
fresh "ended_at FROM runs WHERE id = 1"; expect_rc0 "run-end stores the database time, not the input"
RC=0; OUT="$(sqlite3 "$DB" "SELECT count(*) FROM status_events WHERE at LIKE '2001-%' OR day LIKE '2001-%';")"; expect_has "no status event carries the wrong input time" "0"
finish

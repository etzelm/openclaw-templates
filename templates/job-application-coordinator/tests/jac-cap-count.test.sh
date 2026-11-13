#!/bin/zsh
# J13: the daily cap must count every application that reached a counted
# status on that day, even after the owner moves it on, and a retry on a
# later day must not remove it from the earlier day's count.
source "${0:A:h}/lib.sh" "$1"
DB="$SCRATCH/data/applications.db"
sqlite3 -bail "$DB" ".read references/schema.sql" >/dev/null 2>&1 || { echo "FAIL schema"; exit 1; }
V="$(sqlite3 "$DB" 'PRAGMA user_version;')"
D1=2026-11-10; D2=2026-11-11
posting() {
  step "$DB" save-posting '{"step":"save-posting","company":"Co '$1'","title":"Engineer","link":"https://jobs.example.com/'$1'","first_seen":"'$D1'T09:00:00Z"}'
}
app() { # posting_id status day new_attempt
  step "$DB" save-application '{"step":"save-application","posting_id":'$1',"status":"'$2'","note":"","now":"'$3'T10:00:00Z","day":"'$3'","new_attempt":'$4',"auto_retry":0}'
}
cap() { step "$DB" cap-count '{"step":"cap-count","day":"'$1'"}'; }

posting 1; posting 2; posting 3; posting 4
app 1 applied $D1 1; expect_rc0 "save applied"
app 2 held $D1 1; expect_rc0 "save held"
app 3 prospect $D1 0; expect_rc0 "save prospect (not counted)"
cap $D1; expect_has "cap counts applied+held" '"cap_count":2'

# Owner moves posting 1 to interviewing the same day.
step "$DB" set-status '{"step":"set-status","application_id":1,"status":"interviewing","note":"owner","now":"'$D1'T12:00:00Z"}'
expect_rc0 "set-status interviewing"
cap $D1; expect_has "moved row still counts on its day" '"cap_count":2'

# Owner closes the held row the same day.
step "$DB" set-status '{"step":"set-status","application_id":2,"status":"closed","note":"owner","now":"'$D1'T13:00:00Z"}'
cap $D1; expect_has "closed row still counts on its day" '"cap_count":2'

# A held row from D1 is retried on D2 (posting 4 held on D1, retried D2).
app 4 held $D1 1
cap $D1; expect_has "three counted on D1" '"cap_count":3'
app 4 applied $D2 1; expect_rc0 "retry on later day"
cap $D1; expect_has "retry keeps D1 count" '"cap_count":3'
cap $D2; expect_has "retry counts on D2" '"cap_count":1'

# Prospect promoted to dry-run on D2 counts on D2 only.
app 3 dry-run $D2 0
cap $D2; expect_has "dry-run counts on D2" '"cap_count":2'
cap $D1; expect_has "D1 unchanged" '"cap_count":3'

# Same-day status churn counts one application once.
step "$DB" set-status '{"step":"set-status","application_id":3,"status":"held","note":"","now":"'$D2'T11:00:00Z"}'
cap $D2; expect_has "distinct applications" '"cap_count":2'
# A parked row retried on a later day with the same status still counts on that day.
posting 5
app 5 held $D1 1
app 5 held $D2 1; expect_rc0 "same-status retry on D2"
cap $D2; expect_has "same-status retry counts on D2" '"cap_count":3'
# Review fix: a wrong or missing day must fail, never count 0.
step "$DB" cap-count '{"step":"cap-count","day":"today"}'; expect_fail "cap-count refuses a non-date day"
step "$DB" cap-count '{"step":"cap-count"}'; expect_fail "cap-count refuses a missing day"
step "$DB" parked-rows '{"step":"parked-rows","since_day":"2 weeks ago","today":"'$D2'"}'; expect_fail "parked-rows refuses a non-date since_day"
step "$DB" parked-rows '{"step":"parked-rows","since_day":"'$D1'","today":"now"}'; expect_fail "parked-rows refuses a non-date today"
step "$DB" parked-rows '{"step":"parked-rows","since_day":"'$D1'","today":"'$D2'"}'; expect_rc0 "parked-rows accepts real dates"
echo "schema user_version=$V"
finish

#!/bin/zsh
# A dry-run fill never clicks Submit, so it must not use up one of the 2 attempts
# a posting gets. Otherwise the setup dry runs burn the best postings before any
# real application. Real fills, and skips that pass new_attempt 1, still count.
source "${0:A:h}/lib.sh" "$1"
DB="$SCRATCH/data/applications.db"
sqlite3 -bail "$DB" ".read references/schema.sql" >/dev/null 2>&1 || { echo "FAIL schema"; exit 1; }
D1=2026-11-10; D2=2026-11-11
posting() {
  step "$DB" save-posting '{"step":"save-posting","company":"Co '$1'","title":"Engineer","link":"https://jobs.example.com/'$1'","first_seen":"'$D1'T09:00:00Z","stage":"fit","score":5}'
}
app() { # posting_id status day new_attempt note
  step "$DB" save-application '{"step":"save-application","posting_id":'$1',"status":"'$2'","note":"'${5:-}'","now":"'$3'T10:00:00Z","day":"'$3'","new_attempt":'$4',"auto_retry":0}'
}
cap() { step "$DB" cap-count '{"step":"cap-count","day":"'$1'"}'; }

posting 1; posting 2; posting 3
# Two setup dry runs on the same posting.
app 1 dry-run $D1 1; expect_has "first dry-run fill uses no attempt" '"attempts":0'
app 1 dry-run $D1 1; expect_has "second dry-run fill uses no attempt" '"attempts":0'
cap $D1; expect_has "a dry-run row still counts toward the daily cap" '"cap_count":1'
# The real attempts are all still there.
app 1 ready-for-owner-review $D2 1; expect_has "first real fill is attempt 1" '"attempts":1'
app 1 applied $D2 1; expect_has "second real fill is attempt 2" '"attempts":2'
app 1 applied $D2 1; expect_fail "a third real attempt is still refused"
# A failed upload still counts, and a later dry-run fill adds nothing.
app 2 skipped $D1 1 "upload failed"; expect_has "upload failed counts as an attempt" '"attempts":1'
app 2 dry-run $D1 1; expect_has "dry-run after a counted attempt adds nothing" '"attempts":1'
app 2 held $D2 1; expect_has "the next real fill is attempt 2" '"attempts":2'
# A prospect row passes new_attempt 0 as before.
app 3 prospect $D1 0; expect_has "prospect uses no attempt" '"attempts":0'
app 3 dry-run $D1 1; expect_has "prospect to dry-run uses no attempt" '"attempts":0'
finish

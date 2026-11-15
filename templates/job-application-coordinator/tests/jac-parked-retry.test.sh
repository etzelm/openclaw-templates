#!/bin/zsh
# parked-rows offers the one automatic retry (can_retry 1) only while the row has an
# attempt left. A row parked on its second attempt must show can_retry 0, or each run
# refills the form and then save-application refuses the third attempt.
# Usage: jac-parked-retry.test.sh <package dir>
source "${0:A:h}/lib.sh" "$1"
DB="$SCRATCH/data/applications.db"
sqlite3 -bail "$DB" ".read references/schema.sql" >/dev/null 2>&1 || { echo "FAIL schema"; exit 1; }
D1=2026-11-10; D2=2026-11-11; D3=2026-11-12
posting() {
  step "$DB" save-posting '{"step":"save-posting","company":"Co '$1'","title":"Engineer","link":"https://jobs.example.com/'$1'","stage":"fit","score":5}'
}
pid() { sqlite3 "$DB" "SELECT id FROM postings WHERE link='https://jobs.example.com/$1';"; }
aid() { sqlite3 "$DB" "SELECT id FROM applications WHERE posting_id=$1;"; }
app() { # posting_id status day new_attempt auto_retry note
  step "$DB" save-application '{"step":"save-application","posting_id":'$1',"status":"'$2'","note":"'${6:-}'","day":"'$3'","new_attempt":'$4',"auto_retry":'$5'}'
}
parked() { step "$DB" parked-rows '{"step":"parked-rows","since_day":"'$D1'","today":"'$1'"}'; }

# Posting 1 uses both attempts: skipped for an unknown question, then filled again
# as retry-answered, and the confirm times out, so it is parked for the owner.
posting 1; P1=$(pid 1)
app $P1 skipped $D1 1 0 "unknown question"; expect_has "skip is attempt 1" '"attempts":1'
step "$DB" save-question '{"step":"save-question","application_id":'$(aid $P1)',"question":"Why here?"}'
step "$DB" mark-answered '{"step":"mark-answered","question_id":1}'
step "$DB" ranked-queue '{"step":"ranked-queue","since_day":"'$D1'","today":"'$D2'"}'
expect_has "answered row comes back as retry-answered" '"kind":"retry-answered"'
app $P1 ready-for-owner-review $D2 1 0; expect_has "retry-answered fill is attempt 2" '"attempts":2'

# Posting 2 is parked on its first attempt, so its automatic retry is still open.
posting 2; P2=$(pid 2)
app $P2 ready-for-owner-review $D2 1 0; expect_has "first fill is attempt 1" '"attempts":1'

parked $D3; expect_rc0 "parked-rows runs"
ROWS="$OUT"
can_retry() { [[ "$ROWS" =~ '"application_id":'$1',[^}]*"can_retry":([01])' ]] && print -r -- "$match[1]"; }
OUT="$(can_retry $(aid $P1))"; RC=0
[[ "$OUT" == 0 ]] && ok "row at 2 attempts shows can_retry 0" || bad "row at 2 attempts shows can_retry 0"
OUT="$(can_retry $(aid $P2))"; RC=0
[[ "$OUT" == 1 ]] && ok "row at 1 attempt shows can_retry 1" || bad "row at 1 attempt shows can_retry 1"
[[ "$ROWS" == *'"application_id":'$(aid $P1)* ]] && ok "row at 2 attempts is still listed for reconcile" || { OUT="$ROWS"; bad "row at 2 attempts is still listed"; }

# The retry parked-rows offers for posting 2 is accepted; posting 1 would be refused.
app $P2 ready-for-owner-review $D3 1 1 "retried once"; expect_has "offered retry is accepted" '"attempts":2'
app $P1 ready-for-owner-review $D3 1 1 "retried once"; expect_fail "a third attempt is refused, so it must not be offered"
finish

#!/bin/zsh
# 0.3.0 steps: pre-filter, score and ranked queue, learned questions, funnel stats.
# Usage: jac-v3-steps.test.sh <package dir>
source "${0:A:h}/lib.sh" "$1"
DB="$SCRATCH/data/applications.db"
sqlite3 -bail "$DB" ".read references/schema.sql" >/dev/null 2>&1
RC=$?; OUT="$(sqlite3 "$DB" 'PRAGMA user_version;' 2>&1)"; expect_has "schema is version 3" "3"
D1=2026-11-10; D2=2026-11-11
S1="https://jobs.example.com/search?q=backend"
S2="https://feeds.example.org/jobs.xml"

# 1. Pre-filter: a clear miss is recorded skipped, with no description, in one step.
step "$DB" save-prefiltered '{"step":"save-prefiltered","company":"Pre Co","title":"Sales Manager","link":"https://jobs.example.com/p1","source":"'$S1'","first_seen":"'$D1'T09:00:00Z","reason":"title not in target titles","now":"'$D1'T09:00:00Z","day":"'$D1'"}'
expect_has "save-prefiltered records the posting" '"stage":"prefiltered"'
expect_has "save-prefiltered records skipped" '"status":"skipped"'
expect_has "save-prefiltered note names the pre-filter" 'pre-filter: title not in target titles'
OUT="$(sqlite3 "$DB" "SELECT length(job_description) || '|' || coalesce(score,'null') FROM postings WHERE link='https://jobs.example.com/p1';")"; RC=0
expect_has "pre-filtered posting has no description and no score" "0|null"
step "$DB" save-prefiltered '{"step":"save-prefiltered","company":"Pre Co","title":"Sales Manager","link":"https://jobs.example.com/p1","source":"'$S1'","first_seen":"'$D1'T09:00:00Z","reason":"again","now":"'$D1'T09:00:00Z","day":"'$D1'"}'
expect_rc0 "save-prefiltered twice does not fail"
OUT="$(sqlite3 "$DB" "SELECT count(*) || '|' || (SELECT count(*) FROM applications) FROM postings;")"; RC=0
expect_has "save-prefiltered twice adds nothing" "1|1"
step "$DB" save-prefiltered '{"step":"save-prefiltered","company":"Pre Co","title":"X","link":"https://jobs.example.com/p2","source":"'$S1'","first_seen":"'$D1'T09:00:00Z","reason":"","now":"'$D1'T09:00:00Z","day":"'$D1'"}'
expect_fail "save-prefiltered needs a reason"
step "$DB" save-prefiltered '{"step":"save-prefiltered","company":"Pre Co","title":"X","link":"https://jobs.example.com/p3","source":"'$S1'","first_seen":"'$D1'T09:00:00Z","reason":"r","now":"'$D1'T09:00:00Z","day":"tomorrow"}'
expect_fail "save-prefiltered needs a real day"

# 2. Fit check with score.
posting() { # n stage score source description
  step "$DB" save-posting '{"step":"save-posting","company":"Co '$1'","title":"Engineer '$1'","link":"https://jobs.example.com/'$1'","source":"'$4'","first_seen":"'$D1'T09:00:00Z","job_description":"'$5'","fit_reason":"reason '$1'","stage":"'$2'","score":'$3',"score_reason":"must-haves 2 of 2"}'
}
posting 1 fit 5 "$S1" "desc 1"; expect_has "fit posting saves its score" '"score":5'
posting 2 fit 9 "$S1" "desc 2"; expect_rc0 "second fit posting"
posting 3 fit 9 "$S2" "desc 3"; expect_rc0 "fit posting from a feed source"
posting 4 no-fit null "$S2" "desc 4"; expect_has "no-fit posting saves stage" '"stage":"no-fit"'
posting 5 fit null "$S1" "desc 5"; expect_fail "fit needs a score"
posting 6 no-fit 3 "$S1" "desc 6"; expect_fail "no-fit must not have a score"
posting 7 fit 101 "$S1" "desc 7"; expect_fail "score above 100 is refused"
posting 8 fit -1 "$S1" "desc 8"; expect_fail "negative score is refused"
step "$DB" save-posting '{"step":"save-posting","company":"Co 9","title":"E","link":"https://jobs.example.com/9","source":"'$S1'","first_seen":"'$D1'T09:00:00Z","job_description":"d","fit_reason":"r","stage":"prefiltered","score":null}'
expect_fail "save-posting refuses stage prefiltered with a description"
step "$DB" save-posting '{"step":"save-posting","company":"Co 10","title":"E","link":"https://jobs.example.com/10","source":"'$S1'","first_seen":"'$D1'T09:00:00Z","job_description":"d","fit_reason":"r","stage":"maybe","score":null}'
expect_fail "save-posting refuses an unknown stage"
step "$DB" save-posting '{"step":"save-posting","company":"Co 11","title":"E","link":"https://jobs.example.com/11","source":"'$S1'","first_seen":"'$D1'T09:00:00Z","job_description":"d","fit_reason":"r"}'
expect_fail "save-posting needs a stage"

app() { # posting_id status day new_attempt note
  step "$DB" save-application '{"step":"save-application","posting_id":'$1',"status":"'$2'","note":"'$5'","now":"'$3'T10:00:00Z","day":"'$3'","new_attempt":'$4',"auto_retry":0}'
}
pid() { sqlite3 "$DB" "SELECT id FROM postings WHERE link='https://jobs.example.com/$1';"; }
P1=$(pid 1); P2=$(pid 2); P3=$(pid 3); P4=$(pid 4)
app $P1 prospect $D1 0 ""; app $P2 prospect $D1 0 ""; app $P3 prospect $D1 0 ""
app $P4 skipped $D1 0 "no fit: ads data"

# 3. Ranked queue: highest score first, ties by posting id, only fit prospects.
step "$DB" ranked-queue '{"step":"ranked-queue","since_day":"'$D1'","today":"'$D1'"}'
expect_rc0 "ranked-queue runs"
ORDER="$(print -r -- "$OUT" | grep -o '"posting_id":[0-9]*' | cut -d: -f2 | tr '\n' ' ')"
[[ "$ORDER" == "$P2 $P3 $P1 " ]] && ok "ranked-queue orders by score, then id" || { OUT="order=$ORDER"; bad "ranked-queue order"; }
[[ "$OUT" != *"Co 4"* ]] && ok "ranked-queue leaves out skipped no-fit" || bad "ranked-queue no-fit"
step "$DB" ranked-queue '{"step":"ranked-queue","since_day":"last week","today":"'$D1'"}'
expect_fail "ranked-queue refuses a non-date since_day"

# Filled and applied leave the queue.
app $P2 applied $D1 1 "submit clicked, unconfirmed"
step "$DB" set-status '{"step":"set-status","application_id":'$(sqlite3 "$DB" "SELECT id FROM applications WHERE posting_id=$P2;")',"status":"applied","note":"submitted by agent","now":"'$D1'T10:05:00Z"}'
app $P3 dry-run $D1 1 ""
step "$DB" ranked-queue '{"step":"ranked-queue","since_day":"'$D1'","today":"'$D1'"}'
ORDER="$(print -r -- "$OUT" | grep -o '"posting_id":[0-9]*' | cut -d: -f2 | tr '\n' ' ')"
[[ "$ORDER" == "$P1 " ]] && ok "filled rows leave the queue" || { OUT="order=$ORDER"; bad "queue after fill"; }

# 4. Learned questions.
posting 12 fit 7 "$S1" "desc 12"; P12=$(pid 12)
app $P12 skipped $D1 1 "unknown question"
A12=$(sqlite3 "$DB" "SELECT id FROM applications WHERE posting_id=$P12;")
posting 13 fit 6 "$S2" "desc 13"; P13=$(pid 13)
app $P13 skipped $D1 1 "unknown question"
A13=$(sqlite3 "$DB" "SELECT id FROM applications WHERE posting_id=$P13;")
step "$DB" save-question '{"step":"save-question","application_id":'$A12',"question":"Why do you want to work here?","now":"'$D1'T11:00:00Z"}'
expect_has "save-question returns the question" '"question_id":1'
step "$DB" save-question '{"step":"save-question","application_id":'$A13',"question":"  why do you want to WORK here? ","now":"'$D1'T11:05:00Z"}'
expect_has "same question in other words of case and spacing is one row" '"question_id":1'
step "$DB" save-question '{"step":"save-question","application_id":'$A13',"question":"Years with Rust?","now":"'$D1'T11:06:00Z"}'
expect_has "a second question gets its own row" '"question_id":2'
step "$DB" save-question '{"step":"save-question","application_id":'$A13',"question":"","now":"'$D1'T11:06:00Z"}'
expect_fail "save-question refuses an empty question"
step "$DB" save-question '{"step":"save-question","application_id":9999,"question":"Q","now":"'$D1'T11:06:00Z"}'
expect_fail "save-question refuses an unknown application"
step "$DB" open-questions '{"step":"open-questions"}'
expect_has "open-questions lists the question with 2 waiting" '"waiting":2'
expect_has "open-questions lists the second question" 'Years with Rust?'

# Skipped unknown-question rows are not in the queue until all their questions are answered.
step "$DB" ranked-queue '{"step":"ranked-queue","since_day":"'$D1'","today":"'$D2'"}'
[[ "$OUT" != *"Co 12"* && "$OUT" != *"Co 13"* ]] && ok "unanswered questions keep rows out of the queue" || bad "queue before answers"
step "$DB" mark-answered '{"step":"mark-answered","question_id":1,"now":"'$D2'T08:00:00Z"}'
expect_has "mark-answered reports newly eligible postings" '"now_eligible":1'
step "$DB" mark-answered '{"step":"mark-answered","question_id":1,"now":"'$D2'T08:01:00Z"}'
expect_fail "mark-answered refuses a question that is already answered"
step "$DB" mark-answered '{"step":"mark-answered","question_id":77,"now":"'$D2'T08:01:00Z"}'
expect_fail "mark-answered refuses an unknown question"
step "$DB" ranked-queue '{"step":"ranked-queue","since_day":"'$D1'","today":"'$D2'"}'
[[ "$OUT" == *"Co 12"* && "$OUT" == *'"kind":"retry-answered"'* ]] && ok "fully answered row joins the queue as a retry" || bad "queue retry"
[[ "$OUT" != *"Co 13"* ]] && ok "row with an open question stays out" || bad "queue partial"
step "$DB" open-questions '{"step":"open-questions"}'
[[ "$OUT" != *"work here"* ]] && ok "answered question leaves open-questions" || bad "open-questions after answer"
# A row at 2 attempts never rejoins.
app $P12 skipped $D2 1 "unknown question"
step "$DB" ranked-queue '{"step":"ranked-queue","since_day":"'$D1'","today":"'$D2'"}'
[[ "$OUT" != *"Co 12"* ]] && ok "row at 2 attempts does not rejoin the queue" || bad "queue attempts"

# 5. Funnel in tracker.md.
step "$DB" set-status '{"step":"set-status","application_id":'$(sqlite3 "$DB" "SELECT id FROM applications WHERE posting_id=$P2;")',"status":"interviewing","note":"owner","now":"'$D2'T09:00:00Z"}'
OUT="$(sqlite3 -bail "$DB" ".read references/sql/tracker.sql" 2>&1)"; RC=$?
expect_has "tracker runs" "tracker.md regenerated"
T="$(cat tracker.md)"
[[ "$T" == *"## Funnel"* ]] && ok "tracker.md has a funnel section" || { OUT="$T"; bad "funnel section"; }
row() { print -r -- "$T" | grep -F "| $1 " | head -1 | tr -d ' '; }
# columns: source|found|pre-filtered|fit|filled|applied|interviewing|offer
R="$(row "$S1")"; [[ "$R" == "|$S1|4|1|3|1|1|1|0|" ]] && ok "funnel row for source 1" || { OUT="$R"; bad "funnel source 1"; }
R="$(row "$S2")"; [[ "$R" == "|$S2|3|0|2|1|0|0|0|" ]] && ok "funnel row for the feed source" || { OUT="$R"; bad "funnel source 2"; }
R="$(row all)"; [[ "$R" == "|all|7|1|5|2|1|1|0|" ]] && ok "funnel overall row" || { OUT="$R"; bad "funnel all"; }
[[ "$T" == *"| score |"* ]] && ok "tracker rows show the score" || bad "tracker score column"
# An unconfirmed agent submit is filled but not applied.
posting 14 fit 4 "$S2" "desc 14"; app $(pid 14) applied $D2 1 "submit clicked, unconfirmed"
sqlite3 -bail "$DB" ".read references/sql/tracker.sql" >/dev/null 2>&1; T="$(cat tracker.md)"
R="$(row "$S2")"; [[ "$R" == "|$S2|4|0|3|2|0|0|0|" ]] && ok "unconfirmed submit counts as filled, not applied" || { OUT="$R"; bad "funnel unconfirmed"; }
finish

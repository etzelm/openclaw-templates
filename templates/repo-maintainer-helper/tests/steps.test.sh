#!/bin/zsh
# Read side of a run: add-repo, ingest, to-triage, similar, save-triage, run-end, digest.
# The fixtures keep the exact shape of `gh issue list`, `gh pr list`, `gh label list` output
# (gh 2.102), with made-up text. Usage: zsh tests/steps.test.sh <package dir>
source "${0:A:h}/lib.sh" "$1"
R=example-org/example-repo
schema
RC=0; OUT="$(sqlite3 -bail "$DB" ".read references/schema.sql" 2>&1)"; RC=$?
expect_fail "schema refuses a database that already has tables"
q "PRAGMA user_version;"; expect_eq "schema is version 1" "1"
step setup-check '{}'; expect_has "setup-check passes on a fresh database" '"result":"ok"'

# Repository names: one owner/name pair of safe characters, nothing that leaves inbox/.
step add-repo '{"step":"add-repo","repo":"'$R'"}'; expect_has "add-repo registers the repository" '"repo":"'$R'"'
step add-repo '{"step":"add-repo","repo":"'$R'"}'; expect_rc0 "add-repo twice does not fail"
for bad in "../etc" "a/b/c" "a b/c" "a/.git" ".x/y" "-x/y" "a/-y" "noslash" "a/b;rm" "a/\$(x)"; do
  step add-repo '{"step":"add-repo","repo":"'$bad'"}'; expect_fail "add-repo refuses $bad"
done
step ingest '{"step":"ingest","repo":"other/repo"}'; expect_refused repo_not_registered "ingest refuses a repository that is not registered"
step ingest '{"step":"ingest","repo":"'$R'"}'; expect_refused fetch_missing_or_for_another_repo "ingest refuses when fetch has not run"

step run-start '{"step":"run-start","kind":"scheduled"}'; expect_has "run-start returns the run" '"run_id":1'
step run-start '{"step":"run-start","kind":"cron"}'; expect_fail "run-start refuses an unknown kind"

# First read: only items updated within backlog_days are queued; closed items never are.
inbox $R "$FIXTURES/example"
step ingest '{"step":"ingest","repo":"'$R'","run_id":1,"backlog_days":2}'
expect_has "ingest reads 100 issues" '"kind":"issue","read_count":100,"new_items":100'
expect_has "ingest reads 50 PRs" '"kind":"pr","read_count":50,"new_items":50'
expect_has "a first read never reports a gap" '"limit_reached":0'
q "SELECT count(*) FROM items WHERE triaged_updated_at = '' AND updated_at < strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 days');"
expect_eq "first read leaves out items older than backlog_days" "0"
q "SELECT count(*) FROM items WHERE state <> 'OPEN' AND triaged_updated_at = '';"
expect_eq "first read leaves out closed and merged items" "0"
q "SELECT count(*) > 0 FROM items WHERE triaged_updated_at = '';"; expect_eq "recent open items are queued" "1"
q "SELECT count(*) FROM labels WHERE repo = '$R';"; expect_eq "ingest stores the label list" "10"
q "SELECT count(*) FROM title_index WHERE repo = '$R';"; expect_eq "title index holds the long index plus PRs" "550"
q "SELECT author_is_bot FROM items WHERE author = 'app/example-bot' LIMIT 1;"; expect_eq "bot authors are marked" "1"

# A second read of the same data changes nothing.
QUEUED_BEFORE="$(sqlite3 "$DB" "SELECT count(*) FROM items WHERE state='OPEN' AND updated_at > triaged_updated_at;")"
step ingest '{"step":"ingest","repo":"'$R'","run_id":1}'
expect_has "same read adds no items" '"new_items":0'
expect_has "same read is not a gap" '"limit_reached":0'
q "SELECT count(*) FROM items WHERE state='OPEN' AND updated_at > triaged_updated_at;"; expect_eq "same read queues nothing new" "$QUEUED_BEFORE"
q "SELECT count(*) FROM title_index WHERE repo = '$R';"; expect_eq "a repeat read keeps one title index row per item" "550"

# Bad input stops the step and changes nothing.
D="inbox/${R/\//__}"
cp "$D/issues.json" "$SCRATCH/issues.good"
print -r -- '[{"number":"12","title":"x","state":"OPEN","updatedAt":"2026-11-15T00:00:00Z"}]' > "$D/issues.json"
step ingest '{"step":"ingest","repo":"'$R'"}'; expect_refused "number_type = 'integer'" "ingest refuses a number that is not an integer"
print -r -- '[{"number":12,"title":"x","state":"OPEN","updatedAt":"yesterday"}]' > "$D/issues.json"
step ingest '{"step":"ingest","repo":"'$R'"}'; expect_fail "ingest refuses a time that is not ISO UTC"
print -r -- '{"not":"a list"}' > "$D/issues.json"
step ingest '{"step":"ingest","repo":"'$R'"}'; expect_fail "ingest refuses a file that is not a list"
cp "$SCRATCH/issues.good" "$D/issues.json"
q "SELECT count(*) FROM reads;"; expect_eq "refused ingests record no read" "4"
sed -i.bak "s#\"repo\":\"$R\"#\"repo\":\"other/repo\"#" "$D/fetch.json"
step ingest '{"step":"ingest","repo":"'$R'"}'; expect_refused fetch_missing_or_for_another_repo "ingest refuses a fetch summary for another repository"
inbox $R "$FIXTURES/example"
step ingest '{"step":"ingest","repo":"'$R'","backlog_days":0}'; expect_fail "ingest refuses backlog_days 0"

# A full read whose oldest item is newer than anything seen before may have skipped changes.
node -e '
  const fs = require("fs"); const f = process.argv[1];
  const a = JSON.parse(fs.readFileSync(f, "utf8"));
  const t = Date.now();
  fs.writeFileSync(f, JSON.stringify(a.map((x, k) => ({ ...x, number: 20000 + k,
    updatedAt: new Date(t - k * 1000).toISOString().replace(/\.\d{3}Z$/, "Z") }))));
' "$D/issues.json"
step ingest '{"step":"ingest","repo":"'$R'","run_id":1}'
expect_has "a full read past the last newest item reports a gap" '"kind":"issue","read_count":100,"new_items":100,"queued":'
[[ "$OUT" == *'"kind":"issue"'*'"limit_reached":1'* ]] && ok "the gap is flagged on the issue read" || bad "the gap is flagged on the issue read"
inbox $R "$FIXTURES/example"
step ingest '{"step":"ingest","repo":"'$R'","run_id":1}'; expect_rc0 "ingest after the gap"

# to-triage: open items only, oldest change first, bounded.
step to-triage '{"step":"to-triage"}'; expect_rc0 "to-triage runs"
N="$(print -r -- "$OUT" | grep -o '"item_id"' | wc -l | tr -d ' ')"
[[ "$N" == 25 ]] && ok "to-triage returns 25 by default" || { OUT="count=$N"; bad "to-triage returns 25 by default"; }
step to-triage '{"step":"to-triage","limit":51}'; expect_refused limit_not_1_to_50 "to-triage refuses a limit over 50"
step to-triage '{"step":"to-triage","limit":1}'
FIRST_ID="$(print -r -- "$OUT" | sed -n 's/.*"item_id":\([0-9]*\).*/\1/p' | head -1)"
FIRST_UPD="$(print -r -- "$OUT" | sed -n 's/.*"updated_at":"\([^"]*\)".*/\1/p' | head -1)"
q "SELECT min(updated_at) FROM items WHERE state='OPEN' AND updated_at > triaged_updated_at;"
expect_eq "to-triage starts with the oldest change" "$FIRST_UPD"
q "SELECT state FROM items WHERE id = $FIRST_ID;"; expect_eq "to-triage returns an open item" "OPEN"

# similar: words are quoted, so search syntax in a title cannot break or widen the query.
step similar '{"step":"similar","item_id":'$FIRST_ID',"words":["crash","config"]}'; expect_has "similar finds titles with the words" '"number":'
step similar '{"step":"similar","item_id":'$FIRST_ID',"words":["NEAR(", "\"", "*", "OR", "title:x"]}'; expect_rc0 "similar treats search syntax as plain words"
step similar '{"step":"similar","item_id":'$FIRST_ID',"words":[]}'; expect_refused words_not_1_to_8 "similar refuses no words"
step similar '{"step":"similar","item_id":'$FIRST_ID',"words":["a","b","c","d","e","f","g","h","i"]}'; expect_refused words_not_1_to_8 "similar refuses more than 8 words"
step similar '{"step":"similar","item_id":999999,"words":["crash"]}'; expect_refused unknown_item "similar refuses an unknown item"
FIRST_NUM="$(sqlite3 "$DB" "SELECT number FROM items WHERE id=$FIRST_ID;")"
step similar '{"step":"similar","item_id":'$FIRST_ID',"words":["Fix","Add","Docs","fails"]}'
[[ "$OUT" != *"\"number\":$FIRST_NUM,"* ]] && ok "similar never returns the item itself" || bad "similar never returns the item itself"

# save-triage
T='{"step":"save-triage","run_id":1,"item_id":'$FIRST_ID',"item_updated_at":"'$FIRST_UPD'"'
step save-triage "$T"',"category":"bug","labels":["not-a-label"],"reason":"Crash with steps."}'; expect_fail "save-triage refuses a label the repo does not have"
step save-triage "$T"',"category":"duplicate","reason":"Same as another."}'; expect_fail "save-triage refuses a duplicate without duplicate_of"
step save-triage "$T"',"category":"urgent","reason":"x"}'; expect_fail "save-triage refuses an unknown category"
step save-triage "$T"',"category":"bug","reason":"  "}'; expect_fail "save-triage refuses an empty reason"
step save-triage '{"step":"save-triage","run_id":1,"item_id":'$FIRST_ID',"item_updated_at":"2001-01-01T00:00:00Z","category":"bug","reason":"x"}'
expect_refused item_changed_since_to_triage "save-triage refuses when the item changed since to-triage"
step save-triage "$T"',"category":"bug","labels":["bug","status: 👀 needs review"],"reason":"Crash with clear steps.","suggested_action":"add-labels"}'
expect_has "save-triage records the triage" '"category":"bug"'
q "SELECT count(*) FROM items WHERE id=$FIRST_ID AND updated_at > triaged_updated_at;"; expect_eq "a triaged item leaves the queue" "0"
q "UPDATE items SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id=$FIRST_ID; SELECT count(*) FROM items WHERE id=$FIRST_ID AND updated_at > triaged_updated_at;"
expect_eq "an item that changes again is queued again" "1"

step run-end '{"step":"run-end","run_id":1}'; expect_has "run-end ends the run" '"ended_at":"'
step run-end '{"step":"run-end","run_id":1}'; expect_refused run_unknown_or_ended "run-end refuses a run that already ended"
step_raw digest '{"step":"digest","run_id":1}'; expect_rc0 "digest runs"
for key in '"reads":[' '"triaged":[' '"still_waiting":' '"open_requests":[' '"limit_reached":1' '"category":"bug"'; do
  [[ "$OUT" == *"$key"* ]] && ok "digest has $key" || bad "digest has $key"
done
step_raw digest '{"step":"digest","run_id":42}'; expect_refused unknown_run "digest refuses an unknown run"
finish

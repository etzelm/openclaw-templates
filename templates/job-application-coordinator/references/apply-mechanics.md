# Mechanics

## Files

- settings.md: knobs for each run, including `db_path`. Read it first, every run. First-run setup creates it from templates/settings.md, like the four Markdown files below.
- profile.md: who the owner is, what they want, deal-breakers, resume file.
- answers.md: the answer bank for application questions. It wins over resume.md and profile.md.
- resume.md: the resume as plain text. Work history, education, skills, certifications and links.
- sources.md: the job sources the owner chose. The only places you look for postings.
- The database at `db_path`: the SQLite file and the source of truth, outside the workspace. Postings with their full job descriptions, applications, every filled answer, every status change, and runs. Read and write it only as references/database.md says. Never delete rows.
- tracker.md: a read-only view of the database. The `tracker` step rewrites it at the end of every run. Never edit it by hand and never read it to decide anything.
- run.md: your scratch for this run. Overwrite it at run start. Keep the start time, waits used (holds, confirms), confirm timeouts in a row, gates in a row, and dropped sites. Re-read it instead of relying on memory.

## Clock

Get the time with `session_status`: at run start, before each posting, and before and after each wait. Never estimate elapsed time. "Today" is the date in `time_zone` from settings.md.

## Sources

sources.md can hold four kinds of links. Handle each like this:
- Saved search results page: open it and collect the postings listed.
- Job alert link: open it and collect the postings listed.
- Company career page: open it and collect open postings that match profile.md.
- Single posting link: use it as one posting.

Look for postings only on the sources' own sites. Leave a source's site only for a posting's apply form, as "Apply form" below says. If a source is down, or the site asks you to log in, drop that site for the rest of the run, note it in the digest, and go to the next source. The run ends when no site is left.

## Apply form

- Use the posting's own apply button or link. Follow it one hop, even to another site. Do not search for the form, and do not follow links from the form to anywhere else.
- The form may have several pages. Fill each one and keep going until the last screen before Submit.
- If the form asks you to log in or create an account, and the browser is not already signed in there, close the tab and skip the posting with the reason "account required". Never create an account. Never type a password or a code.
- If the form site is down or blocks you, skip the posting with the reason. A gate on the form follows "CAPTCHA hold" as usual.
- Never open mail, banking or any other site. If the form asks you to confirm an email address or a code, skip the posting with the reason "account required".

## Browser

- Use the browser profile named in settings.md. The default `openclaw` is a dedicated browser that holds no personal logins; the owner signs in there only to job sites, if at all. `user` and `chrome` are the owner's own signed-in Chrome and reach every site it is logged in to.
- The owner must be able to see the browser to clear a check: a headed window, or the Browser panel in the Control UI for the `openclaw` profile.
- Use snapshot refs for clicks and typing. Use `fill` for text fields.
- Upload the resume with a ref, from the reference in profile.md.
- Work in one tab per posting. Close it when the posting is done or parked.
- If the browser is not reachable, stop and tell the owner. Do not start another browser.

## Which rows block a posting

Run `find-posting` with the posting's company, title and link. It returns rows with the same link (`same-link`), the same company and title after normalizing case and punctuation (`same-title`), and other roles at the same company (`same-company`). A `same-link` or `same-title` row is the same posting. For each `same-company` row, decide whether the title is similar.

Match a posting to a row by company plus the same or a similar title. "Similar" means the same role with small changes: seniority words, location, team name, or word order. This is strict on purpose. It may drop a real second opening at the same company, but it never applies twice.

Final, never retry:
- `applied`, `interviewing`, `offer-review`, `closed`, `handoff`.
- `skipped` for fit, a deal-breaker, "account required", a required cover letter, or 2 failed attempts.

Can retry:
- `dry-run` and `prospect`: start them as new.
- `skipped` with reason "unknown question": retry once answers.md, resume.md or profile.md covers that question.
- `skipped` with reason "upload failed": retry on a later run. It counts toward the 2-attempt limit.
- `held` and `ready-for-owner-review`: only as "Parked rows" below allows.

When you retry, run `save-application` on the existing posting with today's day and `new_attempt: 1`. It updates the one application row for that posting. Never add a second posting for the same role: use the posting_id that `find-posting` returned.

A posting the site already marks as applied is a duplicate even with no database row. The owner may have applied by hand. Count duplicates for the digest. Do not add rows for them.

## Parked rows

This is the one rule for `held` and `ready-for-owner-review` rows, and for `applied` rows noted "submit clicked, unconfirmed".

Reconcile once per run, at run start:
- Run `parked-rows` with `since_day` 14 days ago and `today`. It returns at most 10 rows. Pace between them. Gate rules apply.
- Re-open the link. If the site marks it as applied: `set-status` to `applied`, note "submitted by owner" (or "submitted by agent" for an unconfirmed agent submit).
- No marker on an unconfirmed `applied` row: keep the note and list it in the digest under waiting for the owner, as "check whether this was sent".

Retry, when there is no applied marker:
- Only rows where `can_retry` is 1: at most 1 automatic retry per row, on a later day than the row's date, in either mode. The database refuses a second one.
- Before you refill, run `save-posting` again with the description as the page shows it now.
- Record the retry with `save-application`: `new_attempt: 1`, `auto_retry: 1`.
- In confirm mode, ask in the confirm message: "Did you already send this? If so, do not click Submit. Tell me, and I will mark it applied."
- In autopilot, check the site's applied marker on the posting page first. If the marker is missing because you cannot see the page clearly, or anything suggests it may have been sent, do not refill. Leave the row for the owner and list it in the digest as "check whether this was sent".
- Set the note to "retried once".
- After its one retry, a row is never refilled again. Leave it for the owner.

The owner closes a parked row by changing its status. See "Owner status changes".

## Fit check

Read the whole description, not just the title. Compare it to profile.md.
- Any deal-breaker: skip with a one-line reason.
- Otherwise write a one-line reason why it fits.
- When unsure, skip and say why. A missed posting costs less than a bad application.

## Filling forms

Source order for every field: answers.md, then resume.md, then profile.md. Use the first file that answers it. A field backed by one of these files is a normal answer. Do not flag it.

- Map each question to the files by meaning, not exact words.
- Numbers, dates and yes/no answers must match the file exactly.
- Contact fields and work eligibility: from answers.md.
- Work history entries: one per job in resume.md, with employer, title, dates and location as written. Add the summary to a description field if there is one.
- Education entries, skills, certifications and links: from resume.md.
- Years of experience: use answers.md if it has a number. Otherwise count the years from the work history dates in resume.md, round down, and note it under computed answers in the digest. Count overlapping jobs once.
- Target titles, work setup and locations: from profile.md.
- Never invent a fact. Never claim a skill, license, clearance or right to work that the files do not state.
- An optional question that no file covers: leave it blank.
- A required question that no file covers, and `unknown_question: skip`: abandon the posting before Submit. Record it as `skipped` with the note "unknown question", and add the question to the digest's new questions.
- Record every field you fill with `save-answers`: the label as the form shows it, the value you entered, the source (answers, resume, profile, or computed for counted years), and flagged 1 for an answer_and_flag answer.
- A required question that no file covers, and `unknown_question: answer_and_flag`: give the most cautious true answer you can back with the files. List it under flagged answers. That posting goes to the owner for Submit, in any mode.
- Cover letter field: leave an optional one blank. If one is required and the flow cannot continue, skip with the reason "cover letter required".
- EEO and self-ID: blank or "decline to answer" unless answers.md answers them. Never take them from resume.md or profile.md.

## Retries

- A stalled flow often resets to the start when you retry. Start again from the first screen and re-check every field.
- When the 2-attempt limit is reached, skip the posting with the reason.
- If the resume upload fails, skip the posting with the reason "upload failed". If two uploads in a row fail, the file is likely gone: stop filling, tell the owner, and end the run with the digest.
- If a "save this application?" prompt shows on a posting you skip, choose discard.

## Write ahead

Run `save-application` and `save-answers` before you message the owner or click Submit, and check that both steps succeeded. The database adds a status_events row for every change.
- Before a confirm message: `ready-for-owner-review`.
- Before a hold message: `held`.
- Before an autopilot Submit click: `applied`, note "submit clicked, unconfirmed". Run `set-status` with the note "submitted by agent" once the success state shows.
- In dry run: `dry-run`.
If a write-ahead step fails, do not message the owner and do not click Submit. Close the tab, end the run, and say so in the digest. If the run is cut off, the next run reconciles the row under "Parked rows".

## Counting toward the cap

Run `cap-count` with today's day. It counts each application that entered or was retried in status `applied`, `ready-for-owner-review`, `held` or `dry-run` today, from the status history. A row the owner moves on later the same day still counts. Run it at run start and before each posting. That count is checked against `daily_cap` and `daily_target`, so a dry run also stops at the cap.

## Owner away

Two confirm timeouts in a row mean the owner is away. Then:
- Stop waiting and stop filling forms.
- Record further fitting postings as `prospect` with `save-posting` and `save-application`, without opening the form.
- Do not widen searches.

After `max_confirms_per_run` confirm waits: stop filling forms and record further fits as `prospect`. CAPTCHA holds keep their own limit.

If `owner_watches_runs` is false in settings.md and the message tool has no route, nobody can see a hold: do not wait for anything. Park CAPTCHA postings as `held` and filled postings as `ready-for-owner-review`, then stop filling. Say so in the digest.

## Thin runs

If the count is below `daily_target` and you run out of postings, widen the saved search pages from sources.md one step at a time, using their own filters:
1. Broader keywords.
2. A longer posted-within range.
3. Nearby titles from profile.md.
After each step, run the normal loop. Fit and deal-breakers still apply. Stop at `daily_cap`, the run budget or a gate rule. Never add new sites and never change sources.md. Never widen when the owner is away, and never widen in a dry run.

## Run budget

A scheduled run has a hard time limit. The scheduler default is 60 minutes; setup can raise it. If the run hits it, the run is cut off and the digest is lost.

- `budget = run_timeout_minutes - safety_margin_minutes` from settings.md.
- `time left = budget - elapsed`, using `session_status`.
- One wait (hold or confirm) = the smaller of `hold_wait_minutes` and time left.
- If that comes out under 2 minutes, do not wait. Park the posting and continue.
- Do not start a new posting if time left is under `min_minutes_per_posting`.
- CAPTCHA holds stop at `max_holds_per_run`. A later gate gets marked `held` at once.

With the defaults (60 minute run, 10 minute margin), holds and confirms can use the whole 50 minute budget in the worst case. The owner-away rule stops it after two confirm timeouts in a row. The margin always stays free for `run-end`, `tracker` and the digest.

## Waiting

- A wait is the browser tool's `act` with `kind: "wait"`.
- Prefer a condition wait: `text`, `textGone` or `url`, with `timeoutMs` up to 120000. For example, wait for the challenge text to go, or for a success message to show.
- A plain time wait is `poll_interval_seconds` per call, never over 30 seconds. For longer waits, including pacing, chain calls.
- After each wait, take a compact snapshot of the same tab.
- CAPTCHA: the gate is clear when the challenge is gone and the form or the next step shows again. A new gate right after the first one clears counts as the same hold.
- Confirm: done when the page shows the site's success state, such as an "application sent" message. If the owner closes the form or the page shows it was not sent, keep `ready-for-owner-review`.

## Messaging the owner

- Add puts the daily automation in this agent's main conversation, with no chat delivery. Scheduled runs and everything they say show up there, in the Control UI. The owner can add a chat route (docs/README.md, "Messages in a chat app").
- Send "Run started", hold and confirm messages and the digest with the message tool. If it has no route or fails, write the same message as a short line in this conversation, note in run.md that messages are conversation-only, and keep going.
- You cannot read chat replies inside a scheduled run. Watch the page, not the chat.
- Keep messages short. No personal data beyond the company and title.
- The run has no automatic chat delivery. Send the digest like the other messages, and also make it your final reply.

## Stop conditions

End the run cleanly, with the digest, when any of these happen:
- The cap count reaches `daily_cap`.
- `stop_after_gates` gates in a row that did not clear. A gate the owner cleared does not count.
- The run budget is nearly used.
- The browser is gone.
- No site is left.
- There are no more postings, after widening if allowed.

## Tracker format

tracker.md is made by the `tracker` step. It has a header that says it is generated, then one row per application, newest first:

| date | company | title | link | fit reason | flagged answers | status | note | description excerpt |

The excerpt is the first 120 characters of the job description, on one line.

Status values:
- `prospect`: fits, not started yet.
- `ready-for-owner-review`: filled, waiting for the owner to submit.
- `applied`: submitted. Note "submitted by owner" in confirm mode, or "submitted by agent" in autopilot.
- `interviewing`, `offer-review`, `closed`: set by the owner later.
- `skipped`: not applied. Put the reason in the note, for example "account required", "upload failed", "unknown question" or the deal-breaker.
- `dry-run`: filled in dry run, not submitted.
- `held`: a CAPTCHA did not clear in time.
- `handoff`: blocked with nothing to click. The owner submits by hand.


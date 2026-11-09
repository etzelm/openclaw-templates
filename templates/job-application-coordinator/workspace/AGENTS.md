# Operating notes

SOUL.md has the loop and the boundaries. This file has the mechanics.

## Files

- settings.md: knobs for each run. Read it first, every run.
- profile.md: who the owner is, what they want, deal-breakers, resume file.
- answers.md: the answer bank for application questions.
- sources.md: the job sources the owner chose. The only places you look for postings.
- tracker.md: every posting you touched. Append rows. You may update the status and note of a row you wrote. Never delete rows.
- run.md: your scratch for this run. Overwrite it at run start. Keep the start time, waits used (holds, confirms), confirm timeouts in a row, gates in a row, and dropped sites. Re-read it instead of relying on memory.

## Clock

Get the time with `session_status`: at run start, before each posting, and before and after each wait. Never estimate elapsed time. "Today" is the date in `time_zone` from settings.md.

## Sources

sources.md can hold four kinds of links. Handle each like this:
- Saved search results page: open it and collect the postings listed.
- Job alert link: open it and collect the postings listed.
- Company career page: open it and collect open postings that match profile.md.
- Single posting link: use it as one posting.

Follow links only within the same site as the source. If a source is down, or the site asks you to log in, drop that site for the rest of the run, note it in the digest, and go to the next source. The run ends when no site is left.

## Browser

- Use the browser profile named in settings.md. Their logins live there.
- The browser must be visible (headed). A human has to see the window to clear a check.
- Use snapshot refs for clicks and typing. Use `fill` for text fields.
- Upload the resume with a ref, from the reference in profile.md.
- Work in one tab per posting. Close it when the posting is done or parked.
- If the browser is not reachable, stop and tell the owner. Do not start another browser.

## Which rows block a posting

Match a posting to a row by company plus the same or a similar title. "Similar" means the same role with small changes: seniority words, location, team name, or word order. This is strict on purpose. It may drop a real second opening at the same company, but it never applies twice.

Final, never retry:
- `applied`, `interviewing`, `offer-review`, `closed`, `handoff`.
- `skipped` for fit, a deal-breaker, an external form, a required cover letter, or 2 failed attempts.

Can retry:
- `dry-run` and `prospect`: start them as new.
- `skipped` with reason "unknown question": retry once answers.md covers that question.
- `held` and `ready-for-owner-review`: only as "Parked rows" below allows.

When you retry, update the existing row and set its date to today. Do not add a second row.

A posting the site already marks as applied is a duplicate even with no tracker row. The owner may have applied by hand. Count duplicates for the digest. Do not add rows for them.

## Parked rows

This is the one rule for `held` and `ready-for-owner-review` rows, and for `applied` rows noted "submit clicked, unconfirmed".

Reconcile once per run, at run start:
- Only rows dated in the last 14 days, at most 10 per run, with pacing between them. Gate rules apply.
- Re-open the link. If the site marks it as applied: set `applied`, note "submitted by owner" (or clear the "unconfirmed" note).
- No marker on an unconfirmed `applied` row: keep the note and list it in the digest under waiting for the owner, as "check whether this was sent".

Retry, when there is no applied marker:
- At most 1 automatic retry per row, on a later day than the row's date, and only in confirm mode.
- In the confirm message, ask: "Did you already send this? If so, do not click Submit. Set the row to applied in tracker.md."
- Set the note to "retried once".
- In autopilot, never refill a parked row. Leave it for the owner.
- After its one retry, a row is never refilled again. Leave it for the owner.

The owner closes a parked row by editing its status.

## Fit check

Read the whole description, not just the title. Compare it to profile.md.
- Any deal-breaker: skip with a one-line reason.
- Otherwise write a one-line reason why it fits.
- When unsure, skip and say why. A missed posting costs less than a bad application.

## Filling forms

- Map each question to answers.md by meaning, not exact words.
- Numbers, dates and yes/no answers must match answers.md exactly.
- Unknown question and `unknown_question: skip`: abandon the posting before Submit. Mark it `skipped`, reason "unknown question", and add the question to the digest.
- Unknown question and `unknown_question: answer_and_flag`: give the most cautious true answer you can back with profile.md. Never claim a skill, license, clearance or right to work that the files do not state. List it under flagged answers.
- Cover letter field: leave an optional one blank. If one is required and the flow cannot continue, skip with the reason "cover letter required".

## Retries

- A stalled flow often resets to the start when you retry. Start again from the first screen and re-check every field.
- When the attempt limit in SOUL.md is reached, skip the posting with the reason.
- If a "save this application?" prompt shows on a posting you skip, choose discard.

## Write ahead

Write the tracker row before you message the owner or click Submit:
- Before a confirm message: `ready-for-owner-review`.
- Before a hold message: `held`.
- Before an autopilot Submit click: `applied`, note "submit clicked, unconfirmed". Remove the note once the success state shows.
If the run is cut off, the next run reconciles the row under "Parked rows".

## Counting toward the cap

Count rows dated today with status `applied`, `ready-for-owner-review`, `held` or `dry-run`. That count is checked against `daily_cap` and `daily_target`, so a dry run also stops at the cap.

## Owner away

Two confirm timeouts in a row mean the owner is away. Then:
- Stop waiting and stop filling forms.
- Record further fitting postings as `prospect` without opening the form.
- Do not widen searches.

After `max_confirms_per_run` confirm waits: stop filling forms and record further fits as `prospect`. CAPTCHA holds keep their own limit.

If you cannot message the owner at all, do not wait for anything. Park CAPTCHA postings as `held` and filled postings as `ready-for-owner-review`, then stop filling. Say so in the digest.

## Thin runs

If the count is below `daily_target` and you run out of postings, widen the saved search pages from sources.md one step at a time, using their own filters:
1. Broader keywords.
2. A longer posted-within range.
3. Nearby titles from profile.md.
After each step, run the normal loop. Fit and deal-breakers still apply. Stop at `daily_cap`, the run budget or a gate rule. Never add new sites and never change sources.md. Never widen when the owner is away, and never widen in a dry run.

## Run budget

A scheduled run has a hard time limit. The default for this agent's daily job is 60 minutes. If the run hits it, the run is cut off and the digest is lost.

- `budget = run_timeout_minutes - safety_margin_minutes` from settings.md.
- `time left = budget - elapsed`, using `session_status`.
- One wait (hold or confirm) = the smaller of `hold_wait_minutes` and time left.
- If that comes out under 2 minutes, do not wait. Park the posting and continue.
- Do not start a new posting if time left is under `min_minutes_per_posting`.
- CAPTCHA holds stop at `max_holds_per_run`. A later gate gets marked `held` at once.

With the defaults (60 minute run, 10 minute margin), holds and confirms can use the whole 50 minute budget in the worst case. The owner-away rule stops it after two confirm timeouts in a row. The margin always stays free for the tracker and the digest.

## Waiting

- A wait is the browser tool's `act` with `kind: "wait"`.
- Prefer a condition wait: `text`, `textGone` or `url`, with `timeoutMs` up to 120000. For example, wait for the challenge text to go, or for a success message to show.
- A plain time wait is `poll_interval_seconds` per call, never over 30 seconds. For longer waits, including pacing, chain calls.
- After each wait, take a compact snapshot of the same tab.
- CAPTCHA: the gate is clear when the challenge is gone and the form or the next step shows again. A new gate right after the first one clears counts as the same hold.
- Confirm: done when the page shows the site's success state, such as an "application sent" message. If the owner closes the form or the page shows it was not sent, keep `ready-for-owner-review`.

## Messaging the owner

- Use the message tool. Send to the conversation this run reports to.
- You cannot read chat replies inside a scheduled run. Watch the page, not the chat.
- Keep messages short. No personal data beyond the company and title.
- Your message sends replace the automatic result message for this run. That is why the digest is sent with the message tool too.

## Stop conditions

End the run cleanly, with the digest, when any of these happen:
- The cap count reaches `daily_cap`.
- `stop_after_gates` gates in a row that did not clear. A gate the owner cleared does not count.
- The run budget is nearly used.
- The browser is gone.
- No site is left.
- There are no more postings, after widening if allowed.

## Tracker format

One row per posting in tracker.md:

| date | company | title | link | fit reason | flagged answers | status | note |

Status values:
- `prospect`: fits, not started yet.
- `ready-for-owner-review`: filled, waiting for the owner to submit.
- `applied`: submitted. Note "submitted by owner" in confirm mode.
- `interviewing`, `offer-review`, `closed`: set by the owner later.
- `skipped`: not applied. Put the reason in the fit reason column.
- `dry-run`: filled in dry run, not submitted.
- `held`: a CAPTCHA did not clear in time.
- `handoff`: blocked with nothing to click. The owner submits by hand.

## Setup notes

- To give runs more time: `openclaw automations edit <job-id> --timeout-seconds 5400`, then set `run_timeout_minutes: 90` in settings.md. Keep the two in step.
- To send messages to the owner's direct messages: `openclaw automations edit <job-id> --delivery-target owner`. On a host with several channels, also add `--channel <channel>`.
- Notes such as "submitted by owner", "would send on first click", "submit clicked, unconfirmed" and "retried once" go in the note column.

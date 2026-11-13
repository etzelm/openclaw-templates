# Apply loop

SOUL.md has the purpose and boundaries. AGENTS.md has the workflow summary. This file has the rules for one run. Follow it in every run.

Two more files hold the details. Read each section when a step below points to it:
- references/apply-mechanics.md: files, clock, sources, site notes, apply form, browser, duplicates, parked rows, pre-filter, fit check, score, filling forms, learned questions, retries, write ahead, success check, the cap, owner away, thin runs, run budget, waiting, messaging, stop conditions, tracker format.
- references/database.md: how to run a database step, the step list and owner status changes.

The database at `db_path` in settings.md (default `~/job-application-coordinator.db`) is the source of truth for every posting, application, answer, status change and run. tracker.md is a read-only view made from it. Every database step runs the way references/database.md says, and no other way.

## What Submit means

Submit is any click that sends the application, whatever its label: Submit, Apply, Send, Finish, Done, or a single apply click on a posting that sends at once with the saved profile.

Before every click in an apply flow, take a compact snapshot and ask: could this click send the application? If you cannot tell, or the screen shows no later step, treat the click as Submit.

- Dry run and confirm mode stop on the last screen before any Submit click.
- If the first apply click would send at once: in dry run, record `dry-run` with the note "would send on first click", do not click, and go to the next posting. In confirm mode, hand that click to the owner. In autopilot, treat it as the Submit click in step 13.

## The loop

1. Get the time with `session_status`. Read settings.md, profile.md, answers.md, resume.md, sources.md and site-notes.md. Check the required lines: settings.md `time_zone`; profile.md titles, deal-breakers and resume file; answers.md Contact and Work eligibility; at least one link in sources.md. With `browser_driver: devtools-mcp`, profile.md must also name the resume copy for that driver. A required line that still shows `<...>` text ends the run: say so in one line. Pick the mode: `dry-run` if `dry_run` is true or `tos_acknowledged` is not true; else `confirm` if `confirm_before_submit` is true; else `autopilot`. `<blank>` is a valid answer, and optional lines may keep their placeholders. resume.md is optional: a line that still shows `<...>` text counts as empty. A pre-filter line that still shows `<...>` text checks nothing.
2. Run `run-start` with the mode (dry-run, confirm or autopilot). Keep the run id in run.md. If the step fails, end the run: say the database is missing, from another version, or broken. If the error says "external sqlite3 cannot open databases under the active OpenClaw state directory", say `db_path` points inside the OpenClaw state folder and the owner must change it in settings.md to an absolute path outside it. Never work around that guard. Then run `cap-count` for today.
3. Send "Run started" to the owner (see "Messaging the owner" in references/apply-mechanics.md).
4. Reconcile parked rows once with `parked-rows`, as "Parked rows" in references/apply-mechanics.md says. Later steps use that result.
5. Open each source from sources.md with the browser driver from settings.md (see "Browser" in references/apply-mechanics.md). Before you work on a site, read its section in site-notes.md, if any (see "Site notes"). Collect postings with what the listing shows: company, title, link, location and work setup. A feed link is a source like the others: open it and read the postings it lists.
6. Keep postings you can apply to: the form is on the same site, or the posting's apply link leads to the employer's application form. Follow that link one hop, even to another site. See "Apply form" in references/apply-mechanics.md.
7. Dedup with `find-posting` and the site's own "applied" marker. See "Which rows block a posting" in references/apply-mechanics.md.
8. Pre-filter, before you open the full description: compare the listing's title, location and work setup with "Pre-filter" in profile.md. A clear miss: run `save-prefiltered` with a short reason, and do not open the posting. When the listing does not show it clearly, or you are unsure, go on to the fit check. See "Pre-filter" in references/apply-mechanics.md.
9. Fit check: check the time with `session_status`. Read the full description. Check it against profile.md and write a one-line reason. On any deal-breaker, or a must-have the description clearly rules out: `save-posting` with stage `no-fit`, then `save-application` as `skipped` with the reason in the note. Otherwise score it (see "Score" in references/apply-mechanics.md) and run `save-posting` with stage `fit`, the score, the score reason and the full description as shown, then `save-application` as `prospect` with `new_attempt: 0`. Do not fill anything yet.
10. Stop collecting when every source is done, when the fits found reach `daily_cap` minus the cap count, or when half the run budget is used. Then run `ranked-queue`. Fill postings in that order, highest score first, one at a time, until the cap count reaches `daily_cap`. Check the time and run `cap-count` before each one. A `retry-answered` row is a retry: see "Learned questions" in references/apply-mechanics.md.
11. Fill every page of the form, checking every click against "What Submit means". Take each answer from answers.md, then resume.md, then profile.md. See "Filling forms" in references/apply-mechanics.md. Upload the resume file when the form asks for one (see "Browser"). If the upload fails, skip the posting with the reason "upload failed". For a required question no file covers, follow `unknown_question` in settings.md; on a skip, also run `save-question` for each such question. Leave an optional one blank. Leave EEO and self-ID blank or "decline to answer" unless answers.md has an answer.
12. On the last screen before Submit: take a fresh snapshot, then write ahead. Run `save-application` with the status from "Write ahead" in references/apply-mechanics.md and `new_attempt: 1`, then `save-answers` with every field you filled. Then, in dry run, close the tab and go to the next posting. In confirm mode, or with a flagged answer, hand Submit to the owner. See "Confirm mode".
13. Autopilot only: click Submit once. Then do the success check (see "Success check" in references/apply-mechanics.md). When the success state shows, run `set-status` to `applied` with the note "submitted by agent". Dismiss any upsell, survey or "apply to similar jobs" prompt. Do not accept offers.
14. Wait the pacing time before the next posting.
15. Below `daily_target` with no postings left: widen the listed searches step by step, unless this is a dry run. See "Thin runs" in references/apply-mechanics.md. New fits from a widened search go through steps 7 to 9 and then join the queue by score.
16. Run `open-questions` for the digest. Run `run-end` with the end reason and counts (found, pre-filtered, fit, filled, applied, skipped, held). Run `tracker` to regenerate tracker.md.
17. Send the digest (see "Messaging the owner" in references/apply-mechanics.md), then end with the same digest as your final reply.

## Confirm mode

When `confirm_before_submit` is true, the owner presses Submit. That way it is always clear who submitted.
1. Fill the form and stop on the last screen before the Submit click. Do not click it.
2. Write ahead: `save-application` as `ready-for-owner-review`, then `save-answers`.
3. Message the owner: "Ready to submit <company> / <title>. Check it in the browser window and click Submit yourself. I'll wait up to N minutes." Add the fit reason and any flagged answers. N is the wait length from the budget rule in "Run budget" in references/apply-mechanics.md.
4. Watch the page with the mechanics in "Waiting" in references/apply-mechanics.md. Confirms have their own limit, `max_confirms_per_run`.
5. If the page shows the site's success state, run `set-status` to `applied` with the note "submitted by owner". Then dismiss any upsell as usual.
6. A CAPTCHA that shows up while the owner is submitting is part of the same wait. Do not touch it.
7. On timeout, close the tab. The row stays `ready-for-owner-review` with its link. The owner finishes it from the link and closes the row by changing its status (see "Owner status changes" in references/database.md). Scheduled runs close their tabs at the end, so a filled form is not kept. A parked row gets at most one automatic retry: see "Parked rows" in references/apply-mechanics.md.

Autopilot (`confirm_before_submit: false`, chosen by the owner during setup): you click Submit, within the daily cap. The packaged settings start in confirm mode; the owner picks autopilot or confirm mode after the setup dry run, and can switch with one line in settings.md. A posting with a flagged answer always goes through the confirm steps above, even in autopilot.

## CAPTCHA hold

A gate is any of these:
- A visible CAPTCHA widget or checkbox.
- A "verify you are human" or "checking your browser" page.
- A challenge iframe that covers or replaces the form.
- A submit that bounces back with a verification or "are you a robot" error.

Any gate means hold, then `held` or `handoff`. Nothing else.

When you see a gate:
1. Stop. Do not click it. Do not reload, close or leave the tab.
2. Write ahead: `save-application` as `held`.
3. Message the owner right away: which posting, which step, and "Please complete the check in the browser window. I'll wait up to N minutes."
4. Watch the page with the mechanics in "Waiting" in references/apply-mechanics.md.
5. When the gate is gone, resume from the same step.
6. If time runs out, close the tab. The row stays `held`. Move on.
7. If the gate covers the whole site, hold once. If it does not clear, drop that site for the rest of the run. Never reload or retry in a loop.
8. If the site blocks you with nothing for a human to click, run `set-status` to `handoff`, send the owner the link, and drop that site for the rest of the run. It counts as a gate. If there is no posting yet, for example on a source page, just drop the site and say so in the digest.

## Digest

The digest is one short message:
- This run in numbers: found, pre-filtered, fit, filled, applied.
- Applied: company, title, score, fit reason.
- Waiting for the owner: `ready-for-owner-review`, `held` and `handoff`, with links and scores.
- Skipped: company, title, reason. Pre-filtered postings as a count with their most common reasons. Duplicates as a count only.
- Fits not reached this run (cap or budget), with their scores. They stay `prospect` for the next run.
- Flagged answers.
- New questions, from `open-questions`, each with how many postings wait on it, and one line: "Answer these here in your own words and I will add them to answers.md."
- Sites dropped this run, and why.
- Why the run ended. If nothing was applied, say why: gate, no fits, cap reached, budget, or owner away.

Send it the same way as the hold messages (see "Messaging the owner"). Then give the same digest as your final reply. If no message route works, the final reply is the digest.


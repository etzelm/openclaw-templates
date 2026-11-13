# Apply loop

SOUL.md has the purpose and boundaries. AGENTS.md has the workflow summary. This file has the rules for one run. Follow it in every run.

Two more files hold the details. Read each section when a step below points to it:
- references/apply-mechanics.md: files, clock, sources, apply form, browser, duplicates, parked rows, filling forms, retries, write ahead, the cap, owner away, thin runs, run budget, waiting, messaging, stop conditions, tracker format.
- references/database.md: how to run a database step, the step list and owner status changes.

The database at `db_path` in settings.md (default `~/job-application-coordinator.db`) is the source of truth for every posting, application, answer, status change and run. tracker.md is a read-only view made from it. Every database step runs the way references/database.md says, and no other way.

## What Submit means

Submit is any click that sends the application, whatever its label: Submit, Apply, Send, Finish, Done, or a single apply click on a posting that sends at once with the saved profile.

Before every click in an apply flow, take a compact snapshot and ask: could this click send the application? If you cannot tell, or the screen shows no later step, treat the click as Submit.

- Dry run and confirm mode stop on the last screen before any Submit click.
- If the first apply click would send at once: in dry run, record `dry-run` with the note "would send on first click", do not click, and go to the next posting. In confirm mode, hand that click to the owner. In autopilot, treat it as the Submit click in step 11.

## The loop

1. Get the time with `session_status`. Read settings.md, profile.md, answers.md, resume.md and sources.md. Check the required lines: settings.md `time_zone`; profile.md titles, deal-breakers and resume file; answers.md Contact and Work eligibility; at least one link in sources.md. A required line that still shows `<...>` text ends the run: say so in one line. Pick the mode: `dry-run` if `dry_run` is true or `tos_acknowledged` is not true; else `confirm` if `confirm_before_submit` is true; else `autopilot`. `<blank>` is a valid answer, and optional lines may keep their placeholders. resume.md is optional: a line that still shows `<...>` text counts as empty.
2. Run `run-start` with the mode (dry-run, confirm or autopilot). Keep the run id in run.md. If the step fails, end the run: say the database is missing, from another version, or broken. If the error says "external sqlite3 cannot open databases under the active OpenClaw state directory", say `db_path` points inside the OpenClaw state folder and the owner must change it in settings.md to an absolute path outside it. Never work around that guard. Then run `cap-count` for today.
3. Send "Run started" to the owner (see "Messaging the owner" in references/apply-mechanics.md).
4. Reconcile parked rows once with `parked-rows`, as "Parked rows" in references/apply-mechanics.md says. Later steps use that result.
5. Open each source from sources.md in the browser profile from settings.md. Collect postings.
6. Keep postings you can apply to: the form is on the same site, or the posting's apply link leads to the employer's application form. Follow that link one hop, even to another site. See "Apply form" in references/apply-mechanics.md.
7. Dedup with `find-posting` and the site's own "applied" marker. See "Which rows block a posting" in references/apply-mechanics.md.
8. Before each posting, check the time with `session_status`. Read the full description. Check fit against profile.md. Write a one-line reason. Save the posting with `save-posting`, including the full job description as shown, before you fill anything. Skip on any deal-breaker: record it with `save-application` as `skipped` and the reason in the note.
9. Fill every page of the form, checking every click against "What Submit means". Take each answer from answers.md, then resume.md, then profile.md. See "Filling forms" in references/apply-mechanics.md. Upload the resume file named in profile.md when the form asks for one. If the upload fails, skip the posting with the reason "upload failed". For a required question no file covers, follow `unknown_question` in settings.md. Leave an optional one blank. Leave EEO and self-ID blank or "decline to answer" unless answers.md has an answer.
10. On the last screen before Submit: write ahead first. Run `save-application` with the status from "Write ahead" in references/apply-mechanics.md, then `save-answers` with every field you filled. Then, in dry run, close the tab and go to the next posting. In confirm mode, or with a flagged answer, hand Submit to the owner. See "Confirm mode".
11. Autopilot only: click Submit. When the success state shows, run `set-status` to `applied` with the note "submitted by agent". Dismiss any upsell, survey or "apply to similar jobs" prompt. Do not accept offers.
12. Wait the pacing time before the next posting.
13. Below `daily_target` with no postings left: widen the listed searches step by step, unless this is a dry run. See "Thin runs" in references/apply-mechanics.md.
14. Run `run-end` with the end reason and counts. Run `tracker` to regenerate tracker.md.
15. Send the digest (see "Messaging the owner" in references/apply-mechanics.md), then end with the same digest as your final reply.

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
- Applied: company, title, fit reason.
- Waiting for the owner: `ready-for-owner-review`, `held` and `handoff`, with links.
- Skipped: company, title, reason. Duplicates as a count only.
- Flagged answers, and new questions to add to answers.md.
- Sites dropped this run, and why.
- Why the run ended. If nothing was applied, say why: gate, no fits, cap reached, budget, or owner away.

Send it the same way as the hold messages (see "Messaging the owner"). Then give the same digest as your final reply. If no message route works, the final reply is the digest.


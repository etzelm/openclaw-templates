# Job application coordinator (OpenClaw Template)

Status: Gates pass. Not yet proven in a live scheduled run. Run the dry-run test in BOOTSTRAP.md first.

Applies to jobs from the sources you bring, in your own browser. Leaves Submit to you by default and stops at every CAPTCHA for you to clear.

The agent fills in job applications in your own logged-in browser. You click Submit, or in autopilot it does. You choose where it looks: saved search pages, job alert links, company career pages, or a plain list of posting links. It checks fit against your profile, fills forms from your answer bank, keeps a tracker, and sends you a digest.

## Best fit

You already have a profile and resume saved on the job sites you use, and you want help with the many short applications those sites allow. It is not for long custom forms or cover letters.

## Example

Request: "Apply to the new backend roles from my sources today."
Outcome: the agent reads each source, keeps postings that fit, fills each one, and stops before the send click for you to check and click Submit. It stops for any CAPTCHA. You get a tracker row per posting and a short digest.

## What it does

1. Opens the sources you listed in sources.md, in your own browser profile. Nothing else.
2. Keeps only one-step apply postings: the ones that finish in place, in a few short screens, with the profile and resume you saved on that site. Sites often show these with a short apply button or badge, and many search pages have a filter for them. Turn that filter on in the links you save.
3. Skips duplicates, including reposts with new IDs (same company, similar title) and postings the site already marks as applied.
4. Reads the full description and checks fit. Skips deal-breakers.
5. Fills the form from answers.md and uploads your resume.
6. Stops for you to click Submit (default), or submits itself in autopilot. "Submit" means any click that sends the application, whatever its label, including a single apply click that sends at once. Dry run and confirm mode never make that click. A dry run counts toward the daily cap and never widens the search.
7. Sends a digest: applied, waiting for you, skipped, and new questions.

## Done when

Every posting from your sources has a tracker row or was a duplicate, or a stop rule fired, and you have the digest.

## Confirm mode and autopilot

Confirm mode (`confirm_before_submit: true`, the default): you press Submit. The agent fills the form, stops before the send click, messages you, and watches the page until you submit or time runs out. If you do not get to it, the tab is closed and the posting stays `ready-for-owner-review` with its link for you to finish by hand. It gets at most one automatic retry on a later day, in confirm mode only, and the agent asks whether you already sent it. You close the row by editing its status. Scheduled runs close their tabs at the end, so a filled form is not kept. If you stay away for two confirms in a row, the agent stops filling forms for that run. Autopilot (`confirm_before_submit: false`): the agent presses Submit within your daily cap. Choosing autopilot is your explicit decision. A posting with a flagged answer still waits for you. `dry_run: true`, on for the first run, submits nothing in either mode.

## CAPTCHA hold

- Detects visible CAPTCHA widgets, human-check pages, challenge frames, and submits that bounce back with a verification error.
- Leaves the tab alone and messages you: which posting, which step, how long it will wait.
- Watches the page with short browser waits until the check is gone, then resumes at the same step.
- On timeout it marks that posting `held` and moves on. If the whole site is gated, it holds once and then drops that site for the run.
- If a site blocks silently with nothing to click, it marks the posting `handoff`, sends you the link, and drops that site for the run.
- It never tries another route past a check.

## Requirements

- A visible (headed) browser on a machine you can reach during the run, logged in to the sites you use. The agent acts inside that signed-in browser, so a separate profile logged in only to job sites is safer.
- A notification channel you read during the run. Holds, confirms and the digest go to the conversation the automation reports to. The agent sends the digest itself with the message tool, so it arrives even after hold messages. To send them to your direct messages, set the automation's delivery target to owner after Add, for example `openclaw automations edit <job-id> --delivery-target owner`.
- A run timeout long enough for waits. See below.
- Your resume in a place the browser tool can upload from: the OpenClaw temp uploads folder on the browser host, or a `media://inbound/<id>` reference from a file you send the agent in chat.

## Run timeout and waits

A Template cannot set an automation timeout, so the daily job starts with the scheduler default of 60 minutes for isolated runs. If a run hits the limit it is cut off and the digest is lost. The agent plans around it:

- Budget = `run_timeout_minutes` minus `safety_margin_minutes` (60 - 10 = 50 by default).
- Time left = budget minus elapsed, read from `session_status`.
- Each wait (CAPTCHA or confirm) lasts the smaller of `hold_wait_minutes` and time left.
- At most `max_holds_per_run` CAPTCHA holds wait. Later gates are marked `held` at once.
- After `max_confirms_per_run` confirm waits, the agent stops filling forms and records further fits as `prospect`. In confirm mode that is the most one run can finish.
- In the worst case, waits can use the whole budget. Two confirm timeouts in a row stop the waiting.
- No new posting starts with less than `min_minutes_per_posting` left.

To allow more, raise both together:

```bash
openclaw automations edit <job-id> --timeout-seconds 5400
```

and set `run_timeout_minutes: 90` in settings.md.

## Setup

1. Add the Template. The agent's first chat runs BOOTSTRAP.md and walks you through setup.
2. Change the daily automation's time and time zone to when you are near the browser. It defaults to weekdays at 09:00 UTC.
3. Fill in settings.md (`time_zone`), profile.md, answers.md and sources.md.
4. With `dry_run: true`, press Run now on the daily automation once. Setup passes when you get the start message and the digest from that run.
5. Review tracker.md, then set `dry_run` to false.

## Files

| File | Purpose |
| ---- | ------- |
| settings.md | Dry run, confirm mode, daily target and cap, pacing, waits, run budget |
| profile.md | Target roles, deal-breakers, resume file |
| answers.md | Answer bank for application questions |
| sources.md | The job sources you chose |
| tracker.md | Every posting touched, with status |

Tracker statuses: `prospect`, `ready-for-owner-review`, `applied`, `interviewing`, `offer-review`, `closed`, plus `skipped`, `dry-run`, `held` and `handoff`.

## Boundaries

The full list is in CLAW.md. In short: it uses only your sources, leaves Submit to you by default, never solves CAPTCHAs, never logs in or creates accounts, never writes cover letters, and stays within the daily cap, with a hard ceiling of 25 a day on the cap count and 60 seconds between applications. Tools are limited to the browser, messaging and its workspace files. No shell.

## Site terms

You are responsible for following the terms of service of every site you use with this agent. Some sites do not allow automated applications. Check before you turn off dry run, and keep the daily cap modest.

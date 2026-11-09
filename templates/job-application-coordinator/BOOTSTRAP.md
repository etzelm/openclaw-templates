# First run setup

This file is for the first chat only. In a scheduled run, ignore it and follow SOUL.md.

Walk the owner through these steps. Check each one. Do not apply to anything during setup.

## 1. Schedule first

The daily automation `daily-apply-run` is on as soon as the agent is added. It runs on weekdays at 09:00 UTC. Ask the owner to change the time and time zone now, on the Automations page, to a time when they are near the browser. Until the files are filled in, a run only says so and ends.

## 2. Prerequisites

Confirm each with the owner:

1. A visible (headed) browser on a machine the owner can reach. The owner must be able to see the window and click inside it when a CAPTCHA shows up. A headless browser will not work.
2. A browser profile logged in to the job sites they use. You never log in for them. This agent acts inside that signed-in browser. A separate profile logged in only to job sites is safer. Name it in `browser_profile` in settings.md.
3. The `user` profile shows an "allow remote debugging" prompt when it attaches, and that can happen on any run. Someone must accept it. The Chrome extension profile (`chrome`) attaches without that prompt. Either way, the owner must be able to see and click in the browser during the run.
4. A notification channel the owner reads during the run, such as a chat app on their phone. CAPTCHA holds, "ready to submit" messages and the digest go there. To use their direct messages: `openclaw automations edit <job-id> --delivery-target owner`. On a host with several channels, also add `--channel <channel>`.
5. Site terms apply to the owner. They are responsible for following the terms of every site this agent uses. Some sites do not allow automated applications. List only sources whose terms allow this.
6. A run timeout long enough for waits. The daily automation uses the scheduler default of 60 minutes. To give it more: `openclaw automations edit <job-id> --timeout-seconds 5400`, and set `run_timeout_minutes: 90` in settings.md.

## 3. Fill in the files

Ask the owner to fill in, or dictate to you:
- settings.md: `time_zone`, and `browser_profile` if not `user`.
- profile.md: target roles, deal-breakers, resume file.
- answers.md: contact details and common answers.
- sources.md: at least one job source they chose: a saved search page, a job alert link, a company career page, or posting links. Suggest turning on a site's one-step apply filter before copying a search link. Do not suggest sites yourself.

Then read them back and point out any placeholder still left.

## 4. Check the resume reference

Check that the resume line in profile.md has one of the two forms it lists: a path in the OpenClaw temp uploads folder, or a `media://inbound/<id>` reference. The first upload in the dry run is the real test.

## 5. Test the scheduled run

Messaging and browser access work differently in a scheduled run than in this chat. A test from this chat does not prove them. So test the real path:

1. Confirm `dry_run: true` in settings.md.
2. Ask the owner to press Run now on `daily-apply-run` on the Automations page, while they are at the browser.
3. Setup passes only when the owner got the "Run started" message and the digest from that run. `dry-run` rows show in tracker.md if any posting fit. The dry run stops at the daily cap and never widens the search.
4. If a message did not arrive, fix the delivery route (step 2.4) and run it again.

Then review tracker.md with the owner. When they are happy, they set `dry_run: false`. Explain that `confirm_before_submit: true` stays on, so they still click Submit themselves. Turning it off is their choice, made in settings.md.

## 6. Finish

When all steps pass, tell the owner setup is complete. Then overwrite this file with the single line "Setup complete." so it does not run again.

# Operating workflow

## Start here

Ask for or confirm:

- settings.md: tos_acknowledged, dry_run, confirm_before_submit, unknown_question, daily_target, daily_cap, pacing, owner_watches_runs, wait limits, run budget, time_zone, browser_profile, db_path
- profile.md: target titles, seniority, work setup, locations, must-haves, deal-breakers, and the resume file reference
- answers.md: contact details, work eligibility, experience, common yes/no answers, optional EEO answers, and learned questions
- resume.md: the resume as plain text, with work history, education, skills, certifications and links
- sources.md: saved search pages, job alert links, company career pages, or single posting links the owner chose
- the database at db_path: postings with full job descriptions, applications, filled answers, status events and runs, read through the packaged SQL steps

## Included capability boundaries

- The database is one SQLite file at `db_path` in settings.md (default `~/job-application-coordinator.db`), outside the workspace. OpenClaw's exec guard refuses sqlite3 on databases inside the OpenClaw state folder, where a default Add puts this workspace, so the database never lives in the workspace.
- The browser tool uses the profile in settings.md. The default `openclaw` profile is a dedicated browser with no personal logins. `user` and `chrome` are the owner's own signed-in Chrome; then only the Template's rules keep the agent on the sites in sources.md plus the one apply form a posting links to.
- Add installs the daily automation paused, in this agent's main conversation, with no chat delivery. Scheduled runs and their messages show there. The owner can add a chat route; without one, the message tool may have nowhere to send, and the agent writes its messages in the conversation instead.
- Scheduled runs have a time limit (60 minutes by default) and close their browser tabs at the end. All waits come out of that budget with a safety margin kept for closing the run, regenerating tracker.md, and the digest; a parked posting keeps only its database row and link.
- Nothing is submitted while `tos_acknowledged` is false or `dry_run` is true. The packaged settings start in dry run and confirm mode; after the setup dry run the owner picks autopilot (the agent clicks Submit within the daily cap) or confirm mode (the owner clicks Submit).
- Answers come only from answers.md, resume.md and profile.md. The read tool reads a plain text resume in the workspace; other formats need the owner to paste the text into resume.md.
- Tracking uses the sqlite3 command line through exec. The agent writes values to db-input.json in the workspace with the write tool and runs only the packaged references/sql steps; each step reads its values with readfile() and json_extract(), so page text never becomes SQL or shell text. Each step checks the schema version and its input before it runs.
- The tool grant includes exec, and workspaceOnly does not limit shell commands. Setup has the owner set this agent's exec mode to allowlist with only the sqlite3 program allowed, and make references/ read-only. That stops every other program, but sqlite3 can start programs itself through dot-commands, so the sqlite3 rules in SOUL.md still carry the rest. docs/README.md lists the commands.
- No MCP servers, plugins or skills are installed. Follow references/apply-loop.md for each run, with references/apply-mechanics.md and references/database.md for the details.

Use context the user already supplied. Ask only for missing information that
blocks safe or useful progress; otherwise state assumptions and begin.

## Process

1. Get the time with session_status, read the five Markdown files, open a runs row in the database, and end the run in one line if a required line still shows a placeholder or the database check fails
2. Send Run started with the message tool, check the daily cap count, and reconcile parked rows from the database as references/apply-loop.md describes
3. Open each source in the browser profile from settings.md, collect postings, and follow each posting's apply link one hop to its application form
4. Dedup with the find-posting step and the site's own applied marker, read the full description, write a one-line fit reason, save the posting and its full description to the database, and skip deal-breakers
5. Fill every page of the form from answers.md, then resume.md, then profile.md, upload the resume file, and take a compact snapshot before every click to check whether it could send the application
6. Skip with a clear reason when the form needs an account, the upload fails, a required question has no answer, or 2 attempts failed
7. On the last screen before Submit, write ahead to the database with the application row and every filled answer; in autopilot click Submit within the cap, in confirm mode or with a flagged answer message the owner and watch the page, in dry run (or while tos_acknowledged is false) close the tab
8. At any CAPTCHA or human check, stop, write the held row to the database, message the owner, and watch the page within the run budget without touching the check
9. Pace between postings, widen the listed searches only when below daily_target and allowed, close the runs row, regenerate tracker.md from the database, then send the digest and end with the same digest

## Example setting

**Request:** Apply to the new backend roles from my sources today.

**Expected outcome (autopilot, after setup):** The agent reads each listed source, keeps postings that fit profile.md, saves each posting with its full description to the database, and fills each form from answers.md and resume.md, following the apply link to the employer's form when needed. It writes ahead to the database, then clicks Submit within the daily cap, and skips forms that need an account. It holds at any CAPTCHA. tracker.md is regenerated from the database and the owner gets a short digest.

## Standard deliverables

- Database rows: postings with full job descriptions, applications with status and attempts, every filled answer with its source, status events, and one runs row per run
- tracker.md regenerated from the database: date, company, title, link, fit reason, flagged answers, status, note, description excerpt
- In autopilot: submitted applications filled from the answer bank and resume, within the daily cap, or filled forms waiting for the owner in confirm mode
- Hold and confirm messages naming the posting, the step, and the wait
- Digest: applied, waiting for the owner, skipped with reasons, duplicate count, flagged and computed answers, new questions, dropped sites, and why the run ended

## Done when

- Every posting from the sources has a database row or was counted as a duplicate, or a stop rule fired
- Every Submit click and owner message came after a successful database write-ahead, and every Submit click was in autopilot, within the cap, with no flagged answer
- Every filled answer is in the database with its source, from answers.md, resume.md or profile.md, and every skip has a clear reason
- Every CAPTCHA was left to the owner and every unresolved one is held or handoff with its link
- The runs row is closed, tracker.md was regenerated, and the digest was sent and says why the run ended

Keep working notes concise, preserve source links when available, and make the next decision or owner visible in every handoff.

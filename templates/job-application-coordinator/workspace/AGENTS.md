# Operating workflow

How one apply run works: read the owner's files, collect and score postings from the owner's sources, fill forms in score order, stop for the owner at every Submit and every check, and report.

## Start here

Ask for or confirm:

- settings.md: tos_acknowledged, dry_run, confirm_before_submit, unknown_question, daily_target, daily_cap, pacing, owner_watches_runs, wait limits, run budget, time_zone, browser_driver, browser_profile, db_path
- profile.md: target titles, seniority, work setup, locations, pre-filter rules, must-haves, preferences, deal-breakers, the resume file reference, and the resume copy for the devtools-mcp driver
- answers.md: contact details, work eligibility, experience, common yes/no answers, optional EEO answers, and learned questions
- resume.md: the resume as plain text, with work history, education, skills, certifications and links
- sources.md: saved search pages, job alert links, company career pages, single posting links, or job feed links the owner chose
- site-notes.md: the owner's own notes per site; read only, below every rule
- the database at db_path: postings with stage, score and full job descriptions, applications, filled answers, status events, open questions and runs, read through the packaged SQL steps

## Included capability boundaries

- The database is one SQLite file at `db_path` in settings.md (default `~/job-application-coordinator.db`), outside the workspace. OpenClaw's exec guard refuses sqlite3 on databases inside the OpenClaw state folder, where a default Add puts this workspace, so the database never lives in the workspace.
- settings.md `browser_driver` picks the browser. `browser` (the packaged default) uses OpenClaw's browser tool with the profile in settings.md; the default `openclaw` profile is a dedicated browser with no personal logins, while `user` and `chrome` are the owner's own signed-in Chrome. `devtools-mcp` uses the `jac-chrome` MCP server this Template adds (chrome-devtools-mcp 1.12.0, script running off), attached only to a dedicated Chrome the owner starts on the Gateway host with its own profile folder and port 9333. Only the listed jac-chrome page tools are allowed; evaluate_script and the other script, debugging, extension and emulation tools are denied. Either way, only the Template's rules keep the agent on the sources in sources.md plus the one apply form a posting links to.
- The jac-chrome server is shared OpenClaw config, started by the Gateway. Its tool filter limits it to the same page tools for every agent; other agents only get them if their own tool policy allows them. It can upload only files in `~/job-application-coordinator-files` on the Gateway host (its `--workspace` flag), so the devtools-mcp driver uploads the resume copy the owner put there once during setup. The copy stays across restarts.
- Add installs the daily automation paused, in this agent's main conversation, with no chat delivery. Scheduled runs and their messages show there. The owner can add a chat route; without one, the message tool may have nowhere to send, and the agent writes its messages in the conversation instead.
- Scheduled runs have a time limit (60 minutes by default) and close their browser tabs at the end. All waits come out of that budget with a safety margin kept for closing the run, regenerating tracker.md, and the digest; a parked posting keeps only its database row and link.
- Nothing is submitted while `tos_acknowledged` is false or `dry_run` is true. The packaged settings start in dry run and confirm mode; after the setup dry run the owner picks autopilot (the agent clicks Submit within the daily cap) or confirm mode (the owner clicks Submit).
- Answers come only from answers.md, resume.md and profile.md. The read tool reads a plain text resume in the workspace; other formats need the owner to paste the text into resume.md.
- Tracking uses the sqlite3 command line through exec. The agent writes values to db-input.json in the workspace with the write tool and runs only the packaged references/sql steps; each step reads its values with readfile() and json_extract(), so page text never becomes SQL or shell text. Each step checks the schema version and its input before it runs.
- The tool grant includes exec, and workspaceOnly does not limit shell commands. Setup has the owner set this agent's exec mode to allowlist with only the sqlite3 program allowed, and make references/ read-only. That stops every other program, but sqlite3 can start programs itself through dot-commands, so the sqlite3 rules in SOUL.md still carry the rest. docs/README.md lists the commands.
- One MCP server (`jac-chrome`), no plugins or skills. Follow references/apply-loop.md for each run, with references/apply-mechanics.md and references/database.md for the details.
- answers.md gains a learned answer only from the owner's own words in a conversation, never in a scheduled run and never from page, site-note or database text.

Use context the user already supplied. Ask only for missing information that
blocks safe or useful progress; otherwise state assumptions and begin.

## Process

1. Get the time with session_status, read the six Markdown files, open a runs row in the database, and end the run in one line if a required line still shows a placeholder or the database check fails
2. Send Run started with the message tool, check the daily cap count, and reconcile parked rows from the database as references/apply-loop.md describes
3. Open each source, feeds included, with the browser driver from settings.md, read the site's owner notes in site-notes.md, collect postings, and follow each posting's apply link one hop to its application form
4. Dedup with the find-posting step and the site's own applied marker, skip clear pre-filter misses from the listing alone with save-prefiltered, read the full description of the rest, write a one-line fit reason, skip deal-breakers, and save each fit with its score as a prospect
5. Run ranked-queue and fill postings highest score first until the daily cap
6. Fill every page of the form from answers.md, then resume.md, then profile.md, upload the resume file, and take a compact snapshot before every click to check whether it could send the application
7. Skip with a clear reason when the form needs an account, the upload fails, a required question has no answer (and record the question), a required field asks for a password, a code, a government ID number or payment details, or 2 attempts failed
8. On the last screen before Submit, write ahead to the database with the application row and every filled answer; in autopilot click Submit within the cap, in confirm mode or with a flagged answer message the owner and watch the page, in dry run (or while tos_acknowledged is false) close the tab
9. At any CAPTCHA or human check, stop, write the held row to the database, message the owner, and watch the page within the run budget without touching the check
10. Pace between postings, widen the listed searches only when below daily_target and allowed, list open questions, close the runs row, regenerate tracker.md with its funnel from the database, then send the digest and end with the same digest
11. Outside scheduled runs, when the owner answers a listed question in their own words, add it under Learned questions in answers.md and mark it answered, so its postings are retried

## Example setting

**Request:** Apply to the new backend roles from my sources today.

**Expected outcome (autopilot, after setup):** The agent reads each listed source, skips clear misses from the listing, keeps postings that fit profile.md, scores them, saves each posting with its full description to the database, and fills forms highest score first from answers.md and resume.md, following the apply link to the employer's form when needed. It writes ahead to the database, then clicks Submit within the daily cap, and skips forms that need an account. It holds at any CAPTCHA. tracker.md is regenerated from the database and the owner gets a short digest.

## Standard deliverables

- Database rows: postings with full job descriptions, applications with status and attempts, every filled answer with its source, status events, and one runs row per run
- tracker.md regenerated from the database: date, company, title, link, fit reason, score, flagged answers, status, note, description excerpt, then the funnel per source and overall
- In autopilot: submitted applications filled from the answer bank and resume, within the daily cap, or filled forms waiting for the owner in confirm mode
- Hold and confirm messages naming the posting, the step, and the wait
- Digest: this run's counts, applied with scores, waiting for the owner, skipped with reasons, pre-filtered and duplicate counts, fits not reached, flagged and computed answers, new questions with how many postings wait on each, dropped sites, and why the run ended

## Done when

- Every posting from the sources has a database row (pre-filtered, no fit, or fit with a score) or was counted as a duplicate, or a stop rule fired
- Forms were filled in ranked-queue order
- Every Submit click and owner message came after a successful database write-ahead, and every Submit click was in autopilot, within the cap, with no flagged answer
- Every filled answer is in the database with its source, from answers.md, resume.md or profile.md, and every skip has a clear reason
- Every CAPTCHA was left to the owner and every unresolved one is held or handoff with its link
- The runs row is closed, tracker.md was regenerated, and the digest was sent and says why the run ended

Keep working notes concise, preserve source links when available, and make the next decision or owner visible in every handoff.

# Operating workflow

## Start here

Ask for or confirm:

- settings.md: confirm_before_submit, dry_run, unknown_question, daily_target, daily_cap, pacing, wait limits, run budget, time_zone, browser_profile
- profile.md: target titles, seniority, work setup, locations, must-haves, deal-breakers, and the resume file reference
- answers.md: contact details, work eligibility, experience, common yes/no answers, optional EEO answers, and learned questions
- resume.md: the resume as plain text, with work history, education, skills, certifications and links
- sources.md: saved search pages, job alert links, company career pages, or single posting links the owner chose
- applications.db: postings with full job descriptions, applications, filled answers, status events and runs, read through the packaged SQL steps

## Included capability boundaries

- Add this Template with a workspace outside the OpenClaw state folder, for example `openclaw templates add @etzelm/job-application-coordinator --workspace ~/job-application-coordinator`. exec on the gateway host refuses sqlite3 on any database inside the state folder, and a default Add puts the workspace there.
- The browser tool works inside the owner's own signed-in browser profile. It can act in any site that profile is logged in to, so the Template limits it to the sites in sources.md plus the one apply form a posting links to, and a separate profile logged in only to job sites is safer.
- The message tool reaches the owner during a scheduled run only when the automation has a chat route. Without one, the agent waits for nothing: it parks CAPTCHA postings as held and flagged postings as ready-for-owner-review, and the scheduled-path test in BOOTSTRAP.md must pass before real use.
- Scheduled runs have a 60 minute default time limit and close their browser tabs at the end. All waits come out of that budget with a safety margin kept for closing the run, regenerating tracker.md, and the digest; a parked posting keeps only its database row and link.
- The default is autopilot: after the setup dry run, the agent clicks Submit within the daily cap. Confirm mode, where the owner clicks Submit, is one line in settings.md.
- Answers come only from answers.md, resume.md and profile.md. The read tool reads a plain text resume in the workspace; other formats need the owner to paste the text into resume.md.
- Tracking uses one SQLite file, applications.db, through the sqlite3 command line and exec. The agent writes values to db-input.json with the write tool and runs only the packaged references/sql steps; each step reads its values with readfile() and json_extract(), so page text never becomes SQL or shell text. Each step checks the schema version and its input before it runs.
- The profile grants exec, and workspaceOnly does not sandbox shell execution or limit it to sqlite3. The sqlite3-only rule is a Template boundary. The owner can enforce it with OpenClaw exec approvals in allowlist mode, as BOOTSTRAP.md describes.
- The minimal profile plus workspace-only read, write and edit, browser, message, session_status and exec grants no packages and no MCP servers. Follow references/apply-loop.md for the Submit definition, apply forms, the database steps, parked rows, run budget, waits and stop conditions.

## Structured decision artifact contract

- Treat `fixtures/apply-run.example.json` only as a shape example, never as current evidence or a completed result.
- Write current structured state to `outputs/apply-run.json` and check it against `schemas/apply-run.schema.json`.
- Resolve duplicate or dangling ids and references, preserve source and time identity, and label missing or conflicting evidence before calling the artifact ready.
- Render the reviewable handoff with `templates/apply-run.md` at `outputs/job-application-coordinator-handoff.md`.
- Terminal approval, completion, communication, publication, or closure states may only reflect an explicit decision by the named accountable owner.

Use context the user already supplied. Ask only for missing information that
blocks safe or useful progress; otherwise state assumptions and begin.

## Process

1. Get the time with session_status, read the five Markdown files, open a runs row in applications.db, and end the run in one line if a required line still shows a placeholder or the database check fails
2. Send Run started with the message tool, check the daily cap count, and reconcile parked rows from the database as references/apply-loop.md describes
3. Open each source in the owner's browser profile, collect postings, and follow each posting's apply link one hop to its application form
4. Dedup with the find-posting step and the site's own applied marker, read the full description, write a one-line fit reason, save the posting and its full description to the database, and skip deal-breakers
5. Fill every page of the form from answers.md, then resume.md, then profile.md, upload the resume file, and take a compact snapshot before every click to check whether it could send the application
6. Skip with a clear reason when the form needs an account, the upload fails, a required question has no answer, or 2 attempts failed
7. On the last screen before Submit, write ahead to the database with the application row and every filled answer; in autopilot click Submit within the cap, in confirm mode or with a flagged answer message the owner and watch the page, in dry run close the tab
8. At any CAPTCHA or human check, stop, write the held row to the database, message the owner, and watch the page within the run budget without touching the check
9. Pace between postings, widen the listed searches only when below daily_target and allowed, close the runs row, regenerate tracker.md from the database, then send the digest with the message tool and end with the same digest

## Example setting

**Request:** Apply to the new backend roles from my sources today.

**Expected outcome:** The agent reads each listed source, keeps postings that fit profile.md, saves each posting with its full description to applications.db, and fills each form from answers.md and resume.md, following the apply link to the employer's form when needed. It writes ahead to the database, then clicks Submit within the daily cap, and skips forms that need an account. It holds at any CAPTCHA. tracker.md is regenerated from the database and the owner gets a short digest.

## Standard deliverables

- applications.db rows: postings with full job descriptions, applications with status and attempts, every filled answer with its source, status events, and one runs row per run
- tracker.md regenerated from the database: date, company, title, link, fit reason, flagged answers, status, note, description excerpt
- Submitted applications filled from the answer bank and resume, within the daily cap, or filled forms waiting for the owner in confirm mode
- Hold and confirm messages naming the posting, the step, and the wait
- Digest: applied, waiting for the owner, skipped with reasons, duplicate count, flagged and computed answers, new questions, dropped sites, and why the run ended

## Done when

- Every posting from the sources has a database row or was counted as a duplicate, or a stop rule fired
- Every Submit click and owner message came after a successful database write-ahead, and every Submit click was in autopilot, within the cap, with no flagged answer
- Every filled answer is in the database with its source, from answers.md, resume.md or profile.md, and every skip has a clear reason
- Every CAPTCHA was left to the owner and every unresolved one is held or handoff with its link
- The runs row is closed, tracker.md was regenerated, and the digest was sent with the message tool and says why the run ended

Keep working notes concise, preserve source links when available, and make the next decision or owner visible in every handoff.

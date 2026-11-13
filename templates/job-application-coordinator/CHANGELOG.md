# Changelog

## 0.3.0

- Pre-filter: a posting whose title, location or work setup is a clear miss against the new "Pre-filter" rules in profile.md is recorded `skipped` with a short reason, without reading its description (`save-prefiltered`). Unclear listings still get the full fit check.
- Score and ranking: each fit gets a plain score, 2 points per must-have and 1 per preference the description clearly meets (new "Preferences" and "Score" sections in profile.md). Fits are saved as `prospect` and filled highest score first until the daily cap (`ranked-queue`). The score is stored, shown in tracker.md and in the digest.
- Learned questions: required questions no file answers are stored (`save-question`) and listed in the digest with how many postings wait on each (`open-questions`). When the owner answers one in the conversation, in their own words and outside a scheduled run, the agent adds it to answers.md and marks it answered (`mark-answered`); postings skipped for it come back in the ranked queue.
- Funnel: tracker.md ends with counts per source and overall: found, pre-filtered, fit, filled, applied, interviewing, offer. Pure SQL from the status history.
- Feeds: sources.md accepts any job feed link the owner chooses (RSS, Atom or JSON). The agent reads it with the browser like other sources. The package never suggests or names feeds or sites.
- Site notes: an owner-written site-notes.md ships in the workspace with placeholder examples only. The agent reads it before working on a site, never writes it, and nothing in it overrides a rule.
- Chrome DevTools driver: a pinned `jac-chrome` MCP server (chrome-devtools-mcp 1.12.0) with script running off, file links off and usage statistics off, a tool filter of 18 page tools, and the agent's tool policy allowing only those and denying `evaluate_script` and the other script, debugging, extension, emulation and console tools. It attaches to a dedicated Chrome the owner starts with its own profile folder. Opt in with `browser_driver: devtools-mcp` after the setup test; the browser tool path stays the default.
- Resume upload with the DevTools driver: the server's `--workspace=${HOME}/job-application-coordinator-files` flag lets `upload_file` read only that one folder (plus the system temp folder). Setup creates it and copies the resume once; the copy stays across restarts.
- Filling: a field that shows as invalid while empty, is starred, or is labeled required counts as required; when unsure, the agent treats it as required.
- Success check: after Submit the agent may read the page and, with the DevTools driver, its network responses. It never uses that to retry or get around a block.
- Database schema version 3: `postings.stage`, `postings.score`, `postings.score_reason`, and the `questions` and `question_postings` tables. `save-posting` now needs `stage` (`fit` with a whole-number score, or `no-fit`). Upgrade with `references/sql/migrate-v2-to-v3.sql`; a 0.1.x database runs `migrate-v1-to-v2.sql` first.

## 0.2.0

- Uses the single-file `CLAW.md` format: tool grants under `agent.tools`, `automations` instead of `cronJobs`, no `packages` or `profiles/`. 0.1.x cannot be added on current OpenClaw.
- The database moved to `db_path` (default `~/job-application-coordinator.db`), outside the OpenClaw state folder. A default Add now works from the CLI and the Control UI; no `--workspace` needed.
- Safe first install: the daily automation is installed paused, the packaged settings start with `dry_run: true` and confirm mode, and nothing is submitted until `tos_acknowledged: true`. Setup runs one dry run, shows its digest, then asks the owner to pick autopilot or confirm mode.
- Required owner commands, with exact text: exec mode allowlist with only the sqlite3 program, and `references/` made read-only. This refuses every other program; it does not sandbox sqlite3 itself, whose shell-reaching dot-commands are forbidden by the Template's rules. Setup records the database's absolute path first, because the exec allowlist refuses `~`.
- The agent may not change its safety settings (tos_acknowledged, dry_run, confirm_before_submit, daily_cap, db_path) except on the owner's own words.
- `cap-count` and `parked-rows` refuse a day that is not a YYYY-MM-DD date instead of counting 0.
- Setup asks about an upgrade first, handles an empty database file, and ends by asking the owner to remove BOOTSTRAP.md.
- The default browser profile is the dedicated `openclaw` browser instead of the owner's signed-in Chrome.
- Fix: the daily cap no longer drops when the owner moves a row on (for example to `interviewing`) the same day, or when a parked row is retried on a later day. Database schema version 2 records the day on each status event.
- Upgrade path from 0.1.x: `references/sql/migrate-v1-to-v2.sql` and a BOOTSTRAP section.
- Setup asks for the resume file in chat instead of a storage path, and gives exact commands for the schedule, time zone and run time.
- Hard limits (25 a day, 60 second pacing, 2 attempts, 1 automatic retry) are listed in settings.md.
- `apply-loop.md` split into the run rules, mechanics and database reference.
- Removed the unused structured-artifact scaffold (`schemas/`, `fixtures/`, session templates).
- Added README, CHANGELOG, LICENSE and a sanitized dry run example to the package. README lists what has not been tested live yet.

## 0.1.2

- Hub release of the 0.1 line.

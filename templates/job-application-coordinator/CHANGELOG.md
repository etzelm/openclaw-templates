# Changelog

## 0.3.1

The first version that can be added from ClawHub on current OpenClaw, with fixes from a full first-time-user pass. No database change: schema version 3 stays.

- Loads from ClawHub again. 0.1.2, the only version published before this one, still carried the retired `packages` and `cronJobs` keys and a `profiles/` file, so OpenClaw refused it with "Downloaded Template package manifest is invalid." 0.2.0 and 0.3.0 were never published. A new release gate (`scripts/clawhub-load.sh`) serves the built package from a local stand-in registry and runs `openclaw templates add @etzelm/job-application-coordinator --dry-run` against it, on OpenClaw main and on the released version.
- Fix: a dry-run fill no longer uses up one of a posting's 2 attempts. Before, two setup dry runs left the best postings at 2 attempts, and the database then refused every real application to them. `save-application` now ignores `new_attempt` for status `dry-run`. Failed uploads and real fills count as before.
- The catalog icon ships. `assets/icon.png` is now listed in `workspace.files` (copied to `avatars/catalog.png`), so the build packs it and ClawHub shows it. Before, the build left it out and the catalog showed a generic box.
- New artwork: an indigo Blobster in a navy jacket holding a resume with a green check mark, as a 512 px icon and a matching avatar SVG.
- Shorter catalog description and a title in title case. README rewritten for people browsing the catalog: what it does, how you stay in control, an example, then the details. New "Skills and plugins" section says why none are declared.
- Personal data is stated up front, in the catalog text and as the first thing setup says: what the agent types into forms, and that it goes only into the forms of the sites you list and the employer forms they link to.
- New rule: the agent never types a password, a code, a government ID number, or bank or card details into any page. A required field of that kind skips the posting as "sensitive data requested".
- README "Add it": check that your model answers before Add, and what to do when Add prints "The agent was already made available and was kept" (the install is incomplete; delete that agent and add again).
- README requirements now give the command that turns Templates on, say what only the Chrome DevTools driver needs (Chrome and `npx`), and say what a run costs.
- The resume file for the default browser driver must arrive as a chat attachment. Setup, README and profile.md now say so, and point terminal-only owners to the Chrome DevTools driver, which reads the resume from a normal folder.
- The MCP check command is `openclaw mcp doctor jac-chrome`. The `--probe` form in 0.3.0's text is refused while the Gateway runs.
- Setup runs no database command before you have answered the upgrade question.
- Run live on an isolated test instance, against a made-up job board on the test machine: first-run setup by chat, two setup dry runs with the browser tool, the mode choice, and one run started by the schedule itself in confirm mode. See "Tested live, and not yet" in the README for what is still open.

## 0.3.0

Not published on ClawHub.

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

Not published on ClawHub.

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

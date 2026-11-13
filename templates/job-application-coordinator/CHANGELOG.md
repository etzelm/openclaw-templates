# Changelog

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

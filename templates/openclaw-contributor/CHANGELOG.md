# Changelog

## 0.2.0

- Uses the single-file `CLAW.md` format: tool grants under `agent.tools`, no `packages`, `cronJobs` or `profiles/`. 0.1.0 cannot be added on current OpenClaw.
- The database moved to `db_path` (default `~/openclaw-contributor.db`), outside the OpenClaw state folder. A default Add now works from the CLI and the Control UI; no `--workspace` needed.
- Fix: an approval for push, force-push, open-pr, edit-pr or ready-for-review, and for any other action tied to a contribution except open-issue and create-fork, must name the commit SHA it was asked for, and never matches a later head. Approvals saved by 0.1.0 without a SHA can no longer be used for those steps.
- Exec approvals are now a required setup step, with exact commands: exec mode `ask` with nothing allowlisted (not even sqlite3, which can start programs through dot-commands) and `references/` made read-only. The owner approves each packaged database command once with "Always allow here". Setup records the database's absolute path first, because the exec allowlist refuses `~`.
- Setup asks about an upgrade first, handles an empty database file, and ends by asking the owner to remove BOOTSTRAP.md.
- The loop checks at start that the upstream files it depends on still exist, and stops with the moved path if not.
- `upstream_repo` is fixed to openclaw/openclaw.
- Pacing and rate-limit handling for `gh search`.
- The listing and README state requirements, disk and backup cost, model strength, and how the Template handles AI disclosure.
- Upgrade notes from 0.1.0. The database schema is unchanged.
- README lists what has not been tested live yet.
- Added README, CHANGELOG, LICENSE and sanitized examples from a real run (scope proposal, first-gate message, tracker) to the package.

## 0.1.0

- First release.

# First-run setup

Use these instructions only while this Template's local preferences are not yet initialized. In a scheduled run, ignore this file and follow SOUL.md.

1. Read the existing workspace and user context. Reuse facts already supplied.
2. Ask only for required or materially useful values that are still missing.
3. Confirm the proposed preferences before writing them.
4. Create the files below only when absent. Copy each from its packaged template, then fill in the answers. If one already exists, preserve it and offer a concise update instead of overwriting it.
5. Summarize what was saved, then continue with the setup checks below.

Do not request or store passwords, credentials, authentication tokens, or verification codes. Never log in for the owner.

## Check first: workspace location

Do this before any question. Run `pwd` with exec from the workspace root.

OpenClaw's exec guard refuses sqlite3 on any database inside the OpenClaw state folder (`OPENCLAW_STATE_DIR`, by default `~/.openclaw`). A default Add puts this agent's workspace there, for example `~/.openclaw/workspace-job-application-coordinator`.

If the path is inside the state folder, or any sqlite3 step below fails with "external sqlite3 cannot open databases under the active OpenClaw state directory", stop setup. Tell the owner to add this Template again with a workspace outside the state folder, then delete this agent:

`openclaw templates add @etzelm/job-application-coordinator --workspace ~/job-application-coordinator`

Do not try to work around the guard. Do not move the database, copy it elsewhere, or use another tool.

## Questions

- **Time zone** (`time_zone`): required, text, IANA time zone.
- **Browser profile** (`browser_profile`): required, choose user or chrome, default user. It is the signed-in browser the agent works in. A separate profile logged in only to job sites is safer.
- **Target titles** (`titles`): required, text, up to 300 characters.
- **Deal-breakers** (`deal_breakers`): required, multiline text, up to 1000 characters.
- **Resume reference** (`resume`): required, text. A path in the OpenClaw temp uploads folder on the browser host, or a `media://inbound/<id>` reference from a file sent in chat.
- **Resume text** (`resume_text`): required, multiline text. If the shared resume file is plain text or Markdown in the workspace, read it with the read tool and confirm it with the owner. Otherwise ask the owner to paste the resume text. Keep it as written. Never add to it.
- **Job sources** (`sources`): required, multiline text. Saved search pages, job alert links, company career pages, or posting links the owner chose. Never suggest sites.

## Local preference files

- `settings.md` from `templates/settings.md`. Fill `time_zone` and `browser_profile`. Set `dry_run: true` until the scheduled-path test below passes. Keep `confirm_before_submit: false` unless the owner asks for confirm mode.
- `profile.md` from `templates/profile.md`. Fill titles, deal-breakers and the resume file.
- `resume.md` from `templates/resume.md`. Fill it with the resume text, sorted into its sections.
- `answers.md` from `templates/answers.md`. The owner fills Contact and Work eligibility, or dictates them.
- `sources.md` from `templates/sources.md`. Add the job sources.
- `tracker.md` from `templates/tracker.md`. It is a generated view. Never edit it.

## Database

Run these from the workspace root with exec. Run nothing else with exec. If any of them fails with "external sqlite3 cannot open databases under the active OpenClaw state directory", stop and follow "Check first: workspace location" above.

1. Check the tool: `sqlite3 -version`. Version 3.35 or newer is needed. If it is missing or older, stop and tell the owner how to install it: macOS has it built in; Debian or Ubuntu: `apt install sqlite3`; Windows: the official download from the SQLite project. Then wait for them.
2. Check for an existing database: `sqlite3 -readonly applications.db "PRAGMA user_version;"`.
   - It fails with "unable to open": there is no database. Create it: `sqlite3 -bail applications.db ".read references/schema.sql"`.
   - It prints 1: keep it. Never overwrite it.
   - It prints any other number: stop. Tell the owner the database is from another version and v1 has no automatic migrations. Do not touch the file.
3. Self-test: `sqlite3 -bail applications.db ".read references/sql/setup-check.sql"`. It writes one test row, reads it back and deletes it. It must print `setup-check ok, schema version 1`. Record the result in the setup summary.
4. Optional, stronger: OpenClaw's exec approvals can limit this agent's exec to sqlite3. See the exec approvals docs: set this agent's exec security to `allowlist`, then `openclaw approvals allowlist add --agent <agent-id> "<full path to sqlite3>"`. The Template does not set this for the owner.

## Setup checks

1. Schedule: the `daily-apply-run` automation runs on weekdays at 09:00 UTC. Ask the owner to change the time and time zone on the Automations page to a time when they are near the browser.
2. Browser: a visible (headed) browser on a machine the owner can reach. The `user` profile can show an attach prompt on any run, and someone must accept it. The `chrome` extension profile attaches without that prompt. Either way, the owner must be able to see and click in the browser during the run.
3. Messages: holds, "ready to submit" messages and the digest go to the conversation the automation reports to. For direct messages: `openclaw automations edit <job-id> --delivery-target owner`. On a host with several channels, also add `--channel <channel>`.
4. Run time: the scheduler default is 60 minutes. For more: `openclaw automations edit <job-id> --timeout-seconds 5400`, and set `run_timeout_minutes: 90` in settings.md.
5. Site terms apply to the owner. Some sites do not allow automated applications. List only sources whose terms allow this.
6. Scheduled-path test: messaging and browser access work differently in a scheduled run than in this chat. With `dry_run: true`, ask the owner to press Run now on `daily-apply-run` while at the browser. Setup passes only when the owner got the "Run started" message and the digest from that run. `dry-run` rows show in the database and in the regenerated tracker.md if any posting fit, and the runs row for that run is closed.
7. Then review tracker.md with the owner. When they are happy, set `dry_run: false`. From then on the agent applies within the daily cap. Tell the owner that `confirm_before_submit: true` makes them click Submit on every posting instead.

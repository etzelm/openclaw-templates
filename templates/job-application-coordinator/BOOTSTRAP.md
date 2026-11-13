# First-run setup

Use these instructions only while this Template's local preferences are not yet initialized. In a scheduled run, ignore this file and follow SOUL.md. Setup is done when settings.md exists with no `<...>` left in a required line, the dry run passed, the owner has picked the mode, and the owner has removed this file ("Finish setup" below). Until the owner removes it, OpenClaw keeps showing this file.

1. Read the existing workspace and user context. Reuse facts already supplied.
2. Ask only for required or materially useful values that are still missing.
3. Confirm the proposed preferences before writing them.
4. Create the files below only when absent. Copy each from its packaged template, then fill in the answers. If one already exists, preserve it and offer a concise update instead of overwriting it.
5. Summarize what was saved, then continue with the setup steps below, in order.

Do not request or store passwords, credentials, authentication tokens, or verification codes. Never log in for the owner.

Some steps are commands the owner runs in a terminal on the Gateway host. This agent cannot run them: its exec is for sqlite3 only. Show each command with the real values filled in, in a code block, and wait for the owner to say it worked. `<agent-id>` is this agent's id: in the session key that `session_status` shows (`agent:<agent-id>:...`), the text between `agent:` and the next colon. A second Add of this Template gets a different id, so never assume `job-application-coordinator`. `<workspace>` is the absolute path of this workspace, as your file tools report it. `<job-id>` is the id of this agent's `Daily apply run` automation, from step 3 of "Owner commands".

## Say this first

Tell the owner, in a few lines, before any question:
- Many job sites forbid automated applications in their terms. The risk to their accounts is theirs. Nothing is submitted until they confirm, at the end of setup, that they checked the terms of every source.
- The daily automation is installed paused. Setup does one dry run, which fills forms but never submits, and shows its digest. Then they pick autopilot or confirm mode, and enable the automation.
- Their answers, resume and application history are stored in plain text on this machine. See "Personal data" below.

## Questions

- **Upgrade** (first): did the owner use 0.1.x of this Template? If yes, do "Upgrade from 0.1.x" below before "Database".
- **Time zone** (`time_zone`): required, text, IANA time zone.
- **Target titles** (`titles`): required, text, up to 300 characters.
- **Deal-breakers** (`deal_breakers`): required, multiline text, up to 1000 characters.
- **Resume file** (`resume`): required. Ask the owner to send their resume file (PDF or DOCX) in this chat. Write the reference you receive for that file into profile.md. Do not ask for a path.
- **Resume text** (`resume_text`): required, multiline text. If the resume is plain text or Markdown in the workspace, read it and confirm it with the owner. Otherwise ask the owner to paste the text. Keep it as written. Never add to it.
- **Job sources** (`sources`): required, multiline text. Saved search pages, job alert links, company career pages, or posting links the owner chose. Never suggest sites.
- **Browser profile** (`browser_profile`): optional, choose openclaw, user or chrome, default openclaw. Recommend the default: a dedicated browser with none of their personal logins, shown in the Control UI Browser panel.
- **Watching runs** (`owner_watches_runs`): optional, yes or no, default yes. Will they watch scheduled runs in the Control UI, or set up a chat route below, so the agent can wait for them at a CAPTCHA?

## Local preference files

- `settings.md` from `templates/settings.md`. Fill `time_zone`, `browser_profile` and `owner_watches_runs`. Keep `tos_acknowledged: false`, `dry_run: true` and `confirm_before_submit: true` until the last step below. Keep the default `db_path` unless the owner asks for another path outside the OpenClaw state folder; step 4 of "Database" replaces it with its absolute form.
- `profile.md` from `templates/profile.md`. Fill titles, deal-breakers and the resume file reference.
- `resume.md` from `templates/resume.md`. Fill it with the resume text, sorted into its sections.
- `answers.md` from `templates/answers.md`. The owner fills Contact and Work eligibility, or dictates them.
- `sources.md` from `templates/sources.md`. Add the job sources.
- `tracker.md` from `templates/tracker.md`. It is a generated view. Never edit it.

## Database

The database file lives at `db_path` (default `~/job-application-coordinator.db`), outside this workspace. OpenClaw's exec guard refuses sqlite3 on any database inside the OpenClaw state folder, and a default Add puts this workspace there; a database in the home folder works with a default Add. Run these with exec from the workspace root, with the exact `db_path` value in place of `<db_path>`, inside double quotes as shown. Run nothing else with exec.

1. Check the tool: `sqlite3 -version`. Version 3.35 or newer is needed. If it is missing or older, stop and tell the owner how to install it: macOS has it built in; Debian or Ubuntu: `apt install sqlite3`. This Template is tested on macOS and Linux only; the owner commands below are POSIX shell. Then wait for them.
2. Check for an existing database: `sqlite3 -readonly "<db_path>" "PRAGMA user_version;"`.
   - It fails with "unable to open": there is no database. Create it: `sqlite3 -bail "<db_path>" ".read references/schema.sql"`.
   - It prints 2: keep it, also right after an upgrade. Never overwrite it.
   - It prints 0: run `sqlite3 -readonly "<db_path>" "SELECT count(*) FROM sqlite_master;"`. If that prints 0 the file is empty: ask the owner to delete it, then create the database as above.
   - It prints 1: it is from version 0.1.x. Follow "Upgrade from 0.1.x" below.
   - It prints any other number: stop. Tell the owner the file is not from a version this agent knows. Do not touch it.
   - It fails with "external sqlite3 cannot open databases under the active OpenClaw state directory": `db_path` points inside the state folder. Ask the owner for a path outside it, update settings.md, and start this list again. Never work around the guard.
3. Self-test: `sqlite3 -bail "<db_path>" ".read references/sql/setup-check.sql"`. It writes one test row, reads it back and deletes it. It must print `setup-check ok, schema version 2`. Record the result in the setup summary.
4. Record the absolute path: `sqlite3 -readonly "<db_path>" ".databases"`. It prints `main: <absolute path> r/o`. Write that absolute path into `db_path` in settings.md, and use it in every later command. OpenClaw's exec allowlist refuses commands with `~` in them (checked: "execution-plan-miss"), so this must happen before the exec approvals step.

## Owner commands (required)

Show these to the owner as one block, with `<agent-id>`, the sqlite3 path and the time zone filled in. Ask them to run it in a terminal on the Gateway host and paste the output of the last two commands.

1. Limit this agent's exec to the sqlite3 program, and make the packaged SQL steps read-only. The Template's tool grant includes exec. This step makes OpenClaw refuse every other program and stops the steps from being rewritten. It does not sandbox sqlite3 itself: sqlite3 can start other programs through dot-commands such as `.shell`, and only the rules in SOUL.md forbid those. Scheduled runs cannot ask anyone, so this agent needs the allowlist rather than prompts:

   ```sh
   openclaw config set 'agents.entries.<agent-id>.tools.exec.mode' allowlist
   openclaw approvals allowlist add --agent <agent-id> "$(command -v sqlite3)"
   chmod -R a-w "<workspace>/references"
   openclaw exec-policy show --agent <agent-id>
   ```

2. After they run it, check it yourself: run `sqlite3 -version` again. It must still work. The `exec-policy show` output they pasted must show this agent's exec mode as allowlist.
3. Find the automation and set its time and time zone. Pick a weekday time when the owner is near the browser:

   ```sh
   openclaw automations list --agent <agent-id> --all
   openclaw automations edit <job-id> --cron "0 9 * * 1-5" --tz <time_zone>
   ```

4. Optional, longer runs: `openclaw automations edit <job-id> --timeout-seconds 5400`, then set `run_timeout_minutes: 90` in settings.md.
5. Optional, messages in a chat app (also in docs/README.md): scheduled runs land in this agent's own conversation, which the owner sees in the Control UI. To get holds and the digest in a chat app as well: `openclaw automations edit <job-id> --delivery-target owner` (add `--channel <channel>` on a host with several channels).

## Dry run

1. With the automation still paused and `dry_run: true`, ask the owner to be at the browser, then run it once: `openclaw automations run <job-id>`, or press Run now on the Automations page.
2. Setup passes only when that run ended with a digest, the runs row is closed, and tracker.md was regenerated. `dry-run` rows show there if any posting fit.
3. Show the owner the digest from that run and the tracker rows. Fix any source, answer or deal-breaker problem it showed, and repeat the dry run if needed.

## Choose the mode, then enable

Ask the owner two things, and write only what they confirm:

1. "Have you checked that the terms of every site in sources.md allow automated applications?" Only on a clear yes, set `tos_acknowledged: true`. Without it, every run stays a dry run.
2. "Autopilot or confirm mode?"
   - Autopilot (`confirm_before_submit: false`): the agent clicks Submit itself, within the daily cap, and holds for you only at a CAPTCHA or a flagged answer. This is what the agent is built for once the dry run looks right.
   - Confirm mode (`confirm_before_submit: true`): the agent fills each form and you click Submit yourself.
   Only if the answer to question 1 was yes, set `dry_run: false`.

Then ask the owner to enable the automation: `openclaw automations enable <job-id>`. Tell them `dry_run: true` in settings.md pauses submitting at any time, and `openclaw automations disable <job-id>` stops the schedule.

## Finish setup

When the mode is chosen and the automation is enabled (or the owner said to wait), ask the owner to remove this file, so OpenClaw stops treating setup as pending:

```sh
rm "<workspace>/BOOTSTRAP.md"
```

The owner commands, the upgrade notes and the personal data notes stay available in docs/README.md.

## Upgrade from 0.1.x

Templates have no update command: 0.2.0 is a new agent. The old agent's files stay in its own workspace.

1. Ask the owner to stop the old agent's schedule first, so two agents never apply at once: `openclaw automations list --all`, then `openclaw automations disable <old-job-id>`.
2. Ask the owner to copy, in a terminal, from the old workspace (usually the folder they gave `--workspace`): `answers.md`, `profile.md`, `resume.md` and `sources.md` into this workspace, and `applications.db` to two places: `db_path`, and `db_path` plus `.v1-backup` as their own copy.
3. Then run `sqlite3 -bail "<db_path>" ".read references/sql/migrate-v1-to-v2.sql"`. It must print `migrate ok, schema version 2`. It refuses anything that is not version 1. Continue with the self-test in "Database".
4. Re-read the copied settings: 0.2.0 adds `tos_acknowledged`, `owner_watches_runs` and `db_path`. Create settings.md fresh from the template and carry the owner's old values over.

## Personal data

Tell the owner plainly:
- `answers.md`, `resume.md` and `profile.md` in this workspace hold their contact details, work eligibility, resume and any EEO answers they chose to give, in plain text.
- The database at `db_path` holds every posting, every answer filled into a form, and the status history.
- Nothing is sent anywhere except into the application forms of the sites they listed.
- To delete it all: `openclaw agents delete <agent-id>` removes the workspace and its automation. The database is outside the workspace, so also delete the file at `db_path`.

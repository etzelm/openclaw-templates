# Job application coordinator

Applies to jobs from your own sources in a dedicated browser, holds at every CAPTCHA, and tracks each application in SQLite. Installs paused, in dry run.

**Best for:** job seekers who want many applications sent from their own answers and resume, and who can be near the browser during runs to clear checks.

## Before you add it

- **Terms of service.** Many job sites forbid automated applications. The risk to your accounts is yours. Nothing is submitted until you set `tos_acknowledged: true` in settings.md.
- **Requirements.** macOS or Linux (Windows is untested), OpenClaw with Templates enabled (Settings, Labs), sqlite3 3.35 or newer on the Gateway host (built into macOS), a browser you can see during runs (the Control UI Browser panel is enough for the default `openclaw` profile), and a model strong enough to follow long instructions.
- **Setup time.** About 15 minutes, including one dry run.
- **Not for** headless servers where nobody can see the browser: every CAPTCHA would time out.

## Add it

```sh
openclaw templates add @etzelm/job-application-coordinator
```

Or use Add on the Template's page under Pages, Templates. No `--workspace` is needed: the database lives at `db_path` (default `~/job-application-coordinator.db`), outside the OpenClaw state folder, so a default Add works from the CLI and the Control UI.

## What setup does

1. Asks for your time zone, target titles, deal-breakers, resume file and job sources.
2. Creates the database at `db_path` and runs a self-test.
3. Records the database's absolute path before the exec lock (the allowlist refuses `~`).
4. Gives you terminal commands to run, with your values filled in. These are required:
   - Limit this agent's exec to the sqlite3 program and make the packaged SQL steps read-only: `openclaw config set 'agents.entries.<agent-id>.tools.exec.mode' allowlist`, `openclaw approvals allowlist add --agent <agent-id> "$(command -v sqlite3)"` and `chmod -R a-w "<workspace>/references"`. This refuses every other program. It does not sandbox sqlite3 itself, which can start programs through dot-commands such as `.shell`; the Template's rules forbid those.
   - Set the schedule time and time zone on the paused automation.
5. Runs one dry run: forms are filled, nothing is submitted. You see its digest.
6. Asks you to confirm the terms of your sources, then to pick **autopilot** (the agent clicks Submit within a daily cap, holding only at CAPTCHAs and flagged answers) or **confirm mode** (you click Submit). Then you enable the automation.
7. Asks you to remove the setup file: `rm "<workspace>/BOOTSTRAP.md"`.

## What it never does

- Log in, create accounts, or type passwords or codes.
- Click, solve or skip a CAPTCHA. It holds, tells you, and waits within the run budget.
- Invent answers or write cover letters. EEO and self-ID questions stay blank unless your answer bank answers them.
- Visit sites other than your sources and the one apply form a posting links to.
- Apply twice to one posting, more than 25 times a day, or faster than once a minute, whatever the settings say.

## Example

A dry run digest, from a real run against a public job board with test answers: see [examples/dry-run-digest.md](examples/dry-run-digest.md).

## Messages in a chat app

Scheduled runs land in the agent's own conversation in the Control UI. To get holds and the digest in a chat app as well: `openclaw automations edit <job-id> --delivery-target owner` (add `--channel <channel>` on a host with several channels). Find `<job-id>` with `openclaw automations list --agent <agent-id> --all`.

## Not yet tested live

The live setup dry run filled no form, because no posting fit. Not yet run live: filling a form, `save-answers` and the write ahead, the resume upload from a chat reference, a CAPTCHA hold, a confirm-mode wait, the mode choice and enable, and any real submit.

## Personal data

- `answers.md`, `resume.md` and `profile.md` in the agent workspace hold your contact details, work eligibility, resume and any EEO answers you chose to give, in plain text.
- The database at `db_path` holds every posting, every filled answer and the status history.
- To remove everything: `openclaw agents delete <agent-id>`, then delete the file at `db_path`.

## Upgrade from 0.1.x

Templates have no update command. Add 0.2.0 as a new agent, disable the old agent's automation, and follow "Upgrade from 0.1.x" in BOOTSTRAP.md (setup asks first): copy your answer files over, copy the old `applications.db` to `db_path` (keep a backup), and the agent runs the packaged migration (`references/sql/migrate-v1-to-v2.sql`).

## Package contents

- `CLAW.md`: manifest and the agent's SOUL.md.
- `BOOTSTRAP.md`: first-run setup.
- `workspace/AGENTS.md`: operating workflow.
- `references/apply-loop.md`, `references/apply-mechanics.md`, `references/database.md`: run rules.
- `references/schema.sql` and `references/sql/*.sql`: the database and its packaged steps.
- `templates/*.md`: the files setup creates.
- Tools: OpenClaw profile `minimal` plus `read`, `write`, `edit`, `browser`, `message`, `session_status`, `exec`, with workspace-only file access. The `gateway` tool that `minimal` includes is denied. No MCP servers, plugins or skills.
- Automation: `daily-apply-run`, weekdays 09:00 UTC, installed paused.

MIT licensed. See [CHANGELOG.md](CHANGELOG.md).

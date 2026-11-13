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

1. Asks for your time zone, target titles, deal-breakers, resume file and job sources, and optionally pre-filter rules, must-haves and preferences for the score, and the Chrome DevTools driver.
2. Creates the database at `db_path` and runs a self-test.
3. Records the database's absolute path before the exec lock (the allowlist refuses `~`).
4. Gives you terminal commands to run, with your values filled in. These are required:
   - Limit this agent's exec to the sqlite3 program and make the packaged SQL steps read-only: `openclaw config set 'agents.entries.<agent-id>.tools.exec.mode' allowlist`, `openclaw approvals allowlist add --agent <agent-id> "$(command -v sqlite3)"` and `chmod -R a-w "<workspace>/references"`. This refuses every other program. It does not sandbox sqlite3 itself, which can start programs through dot-commands such as `.shell`; the Template's rules forbid those.
   - Set the schedule time and time zone on the paused automation.
5. Runs one dry run: forms are filled, nothing is submitted. You see its digest.
6. Asks you to confirm the terms of your sources, then to pick **autopilot** (the agent clicks Submit within a daily cap, holding only at CAPTCHAs and flagged answers) or **confirm mode** (you click Submit). Then you enable the automation.
7. Asks you to remove the setup file: `rm "<workspace>/BOOTSTRAP.md"`.

## How a run works

1. Reads your sources, including any job feed links you listed (RSS, Atom or JSON), and your own notes in site-notes.md.
2. Pre-filter: a posting whose title, location or work setup is a clear miss against your rules in profile.md is skipped with a short reason, without opening its description. Anything unclear gets the full fit check.
3. Fit check on the full description, then a plain score: 2 points per must-have and 1 per preference the description clearly meets.
4. Fills forms highest score first, until the daily cap.
5. Lists new questions no file answers. Answer them in the chat in your own words and the agent adds them to answers.md; postings skipped for those questions are tried again on the next run. It never learns answers from a job page or during a scheduled run.
6. tracker.md shows every application with its score, then a funnel per source and overall: found, pre-filtered, fit, filled, applied, interviewing, offer.

## Site notes

site-notes.md in the workspace is yours. Write what you know about each of your sites: where the apply button is, what the success page says, quirks. The agent reads it before working on a site but never writes to it, and nothing in it can override a rule: no login, the CAPTCHA hold, the Submit rules and the caps always win. It ships with placeholder examples only.

## Browser drivers

- `browser` (default): OpenClaw's browser tool, as in 0.2.0. The default `openclaw` profile is a dedicated browser with none of your personal logins.
- `devtools-mcp`: the `jac-chrome` MCP server this Template adds, Chrome DevTools MCP pinned to 1.12.0 and started by the Gateway with npx. It attaches to a dedicated Chrome you start on the Gateway host with its own profile folder and `--remote-debugging-port=9333`, holding only your job-site logins. Script running is turned off in the server, and the agent may use only the page tools listed in CLAW.md; `evaluate_script`, extension, emulation, performance and console tools are denied. Setup walks you through it and switches only after a working test.
  - Anything on that machine that can reach port 9333 can control that Chrome. Keep it to job sites and close it when runs are done.
  - The server is shared OpenClaw config. Its tool filter applies to every agent; to keep other agents off it entirely, deny `jac-chrome__*` in their tool policy.
  - It can upload files only from `~/job-application-coordinator-files` (of the user that runs the Gateway) and the system temp folder. Setup has you copy your resume there once, and it stays across restarts: `mkdir -p ~/job-application-coordinator-files && cp "<resume file>" ~/job-application-coordinator-files/resume.pdf`. Keep only your resume in that folder. Copy again only when your resume changes.
  - Check the server: `openclaw mcp doctor jac-chrome --probe`.

## What it never does

- Log in, create accounts, or type passwords or codes.
- Click, solve or skip a CAPTCHA. It holds, tells you, and waits within the run budget.
- Invent answers or write cover letters. EEO and self-ID questions stay blank unless your answer bank answers them.
- Visit sites other than your sources and the one apply form a posting links to, or suggest sources.
- Run scripts in a page, or retry around a block after Submit. The success check only reads the page and its network responses.
- Apply twice to one posting, more than 25 times a day, or faster than once a minute, whatever the settings say.

## Example

A dry run digest, from a real run against a public job board with test answers: see [examples/dry-run-digest.md](examples/dry-run-digest.md).

## Messages in a chat app

Scheduled runs land in the agent's own conversation in the Control UI. To get holds and the digest in a chat app as well: `openclaw automations edit <job-id> --delivery-target owner` (add `--channel <channel>` on a host with several channels). Find `<job-id>` with `openclaw automations list --agent <agent-id> --all`.

## Not yet tested live

0.3.0 was run live in dry run on an isolated test instance with the Chrome DevTools driver, against a made-up job board and feed served on the test machine itself, not against any real site. In that run the agent pre-filtered two postings without opening them, scored three fits, filled two forms in score order with the resume upload, skipped one for an unknown required question, listed that question in the digest, learned the owner's answer in a later chat turn, and queued the posting for a retry. Not yet run live: a real site, a CAPTCHA hold, a confirm-mode wait, the mode choice and enable, the browser tool driver in 0.3.0, and any real submit.

## Personal data

- `answers.md`, `resume.md` and `profile.md` in the agent workspace hold your contact details, work eligibility, resume and any EEO answers you chose to give, in plain text.
- The database at `db_path` holds every posting, every filled answer and the status history.
- To remove everything: `openclaw agents delete <agent-id>`, then delete the file at `db_path`.

## Upgrade from 0.1.x or 0.2.x

Templates have no update command. Add 0.3.0 as a new agent, disable the old agent's automation, and follow "Upgrade from an earlier version" in BOOTSTRAP.md (setup asks first): copy your answer files over, keep a backup of the database, and the agent runs the packaged migrations (`references/sql/migrate-v1-to-v2.sql` for 0.1.x, then `references/sql/migrate-v2-to-v3.sql`). After that the old 0.2.x agent can no longer use the database, so keep it disabled.

## Package contents

- `CLAW.md`: manifest and the agent's SOUL.md.
- `BOOTSTRAP.md`: first-run setup.
- `workspace/AGENTS.md`: operating workflow.
- `references/apply-loop.md`, `references/apply-mechanics.md`, `references/database.md`: run rules.
- `references/schema.sql` and `references/sql/*.sql`: the database and its packaged steps.
- `templates/*.md`: the files setup creates. `site-notes.md` also lands in the workspace at Add, for you to fill.
- Tools: OpenClaw profile `minimal` plus `read`, `write`, `edit`, `browser`, `message`, `session_status`, `exec` and 18 named `jac-chrome__*` page tools, with workspace-only file access. The `gateway` tool that `minimal` includes is denied, and so are `jac-chrome__evaluate_script` and the other script, debugging, extension, emulation and console tools.
- MCP server: `jac-chrome`, `npx --yes chrome-devtools-mcp@1.12.0` with `--browserUrl=http://127.0.0.1:9333 --no-javascript-evaluation --no-file-navigations --no-usage-statistics --no-performance-crux --redact-network-headers` and the performance and emulation tools off, plus a tool filter that keeps only the 18 page tools. No plugins or skills.
- Automation: `daily-apply-run`, weekdays 09:00 UTC, installed paused.

MIT licensed. See [CHANGELOG.md](CHANGELOG.md).

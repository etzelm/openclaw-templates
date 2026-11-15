# Job Application Coordinator

Send more job applications without giving up control of what gets sent.

You list the job sites and search pages you want. The agent reads them, skips clear misses, scores the rest against what you asked for, and fills each application form from your own answers and resume. It starts paused and in dry run, and in the default mode you click Submit yourself.

## What it does

- **Works only from your sources.** Saved searches, job alert links, company career pages, single postings or job feeds that you list. It never picks sites.
- **Skips clear misses early.** A posting whose title, location or work setup is a clear miss is skipped from the listing alone, with a reason.
- **Scores what fits.** 2 points per must-have and 1 per preference the description clearly meets. Forms are filled highest score first, up to a daily cap.
- **Fills from your own words.** Every field comes from your answer bank, your resume or your profile. It never invents an answer and never writes a cover letter.
- **Asks when it does not know.** A required question no file answers is listed in the digest. Answer it once in chat and the postings that waited on it are tried again.
- **Keeps a record.** A small SQLite database holds every posting, every filled answer and every status change. A tracker file shows each application and a funnel per source.

## You stay in control

- **Installs paused, in dry run.** Setup runs one dry run: forms are filled, nothing is sent, and you read the digest first.
- **You click Submit.** Confirm mode is the default: the agent fills the form, stops before the send click and waits for you. Autopilot, where the agent clicks Submit itself within the daily cap, is a choice you make in your own words after the dry run, and one line in settings.md turns it off.
- **Nothing is sent until you say you checked each site's terms.** Until then every run stays a dry run.
- **A human clears every CAPTCHA.** The agent stops, tells you and waits. It never clicks, solves or works around a check.
- **No logins, no passwords.** It never logs in, creates an account, or types a password, a code, an ID number or payment details.
- **Your data goes only into the forms you chose.** Your contact details, work eligibility, resume and answers are typed into application forms on the sites you list and the employer forms their postings link to. Nowhere else.
- **Hard limits.** At most 25 applications a day and one a minute, whatever the settings say, and never twice to the same posting.

## Example

> Run today's apply pass.

The agent opens your two saved searches and your feed, finds 14 postings, and skips 5 from the listing alone (wrong title or on-site). It reads the other 9, drops 3 on a deal-breaker, and scores 6 fits. It fills the top form, uploads your resume, stops on the last screen and messages you: "Ready to submit Example Co / Backend Engineer. Check it in the browser window and click Submit yourself." One form asks a required question your files do not answer, so that posting waits and the question is in the digest. The digest lists what was sent, what waits for you, what was skipped and why.

A real dry run digest: [examples/dry-run-digest.md](examples/dry-run-digest.md).

**Best for:** job seekers who want many applications sent from their own answers and resume, and who can be near the browser during runs to click Submit and clear checks.

## Before you add it

- **Terms of service.** Many job sites forbid automated applications. The risk to your accounts is yours. Nothing is submitted until you set `tos_acknowledged: true` in settings.md.
- **Requirements.** macOS or Linux (Windows is untested). An OpenClaw build that can add Templates from ClawHub: as of November 2026 that is a build from current `main`. The 2026.11.3 release has no `templates` command, and 2026.11.5-beta.3 adds Templates only from local files. Check with `openclaw templates add --help`. Templates turned on: Settings, Labs, or `openclaw config set gateway.controlUi.experimental.templates true`. sqlite3 3.35 or newer on the Gateway host (built into macOS). A browser you can see during runs (the Control UI Browser panel is enough for the default `openclaw` profile). A model that already answers in OpenClaw and is strong enough to follow long instructions; small models miss steps.
- **Only for the optional Chrome DevTools driver.** Google Chrome on the Gateway host, and `npx` (it comes with Node) with network access the first time, to fetch the pinned server. The default browser driver needs neither.
- **Cost.** Every run is one long model session: the agent reads each source page, each posting it does not pre-filter, and every form it fills. With a paid model that costs money on every scheduled day, whether or not anything fits. The run time limit and `daily_cap` bound it, and the pre-filter rules in profile.md are the cheapest way to cut it. Start with one or two sources.
- **Setup time.** About 15 minutes, including one dry run.
- **Not for** headless servers where nobody can see the browser: every CAPTCHA would time out.

## Skills and plugins

None are declared, on purpose. The agent needs only OpenClaw's own browser, file, message and exec tools, plus one optional pinned MCP server for people who prefer to drive their own Chrome. Fewer parts means less to review before you trust it with your applications.

## Add it

```sh
openclaw templates add @etzelm/job-application-coordinator
```

Check first that your model answers: send any agent a short message. Add ends with a short greeting from the new agent, so it needs a working model.

If Add prints "The agent was already made available and was kept", the install is incomplete, even when OpenClaw adds "Continue setup in this agent; do not add another copy." It happens when the greeting fails, and on a new Gateway when Add has to turn on OpenClaw's browser plugin and that reload is deferred. The agent then has no setup file, no schedule and often no `chrome-devtools-jobs` server. Check with `openclaw automations list --agent <agent-id> --all` (no "Daily apply run" means incomplete) and `openclaw mcp list`. To fix it: if the greeting failed, fix the model first. Remove the half-made agent with `openclaw agents delete <agent-id>` (`openclaw agents list` shows the id), then add again. If that Add fails with "Could not add this Template" (OpenClaw can keep a deleted id busy), add it under an unused id, for example `job-application-coordinator-setup`: `openclaw templates add @etzelm/job-application-coordinator --agent-id job-application-coordinator-setup`. Do not pick a `-2` style suffix, because OpenClaw gives that to a second copy and it can be busy too. A second try on the same Gateway usually completes, because the browser plugin is on by then.

**Adding it a second time on the same Gateway** (a second agent, or a newer version later) is refused on current OpenClaw with `mcp_server_collision` on `chrome-devtools-jobs`, although the server is the same. OpenClaw compares the server's `${HOME}` argument after filling it in, so it never matches. Until OpenClaw allows a second copy with the same server config: run `openclaw gateway stop`, then `openclaw mcp unset chrome-devtools-jobs` (it only runs while the Gateway is stopped), then `openclaw gateway start`, and add again. If a system service manager (launchd or systemd) runs your Gateway outside the OpenClaw service commands, stop and start it through that manager instead. Add writes the same server back, and agents you already have keep working.

Or use Add on the Template's page under Pages, Templates. No `--workspace` is needed: the database lives at `db_path` (default `~/job-application-coordinator.db`), outside the OpenClaw state folder, so a default Add works from the CLI and the Control UI.

## What setup does

1. Asks for your time zone, target titles, deal-breakers, resume file (sent as a chat attachment in the Control UI or a chat app; a terminal chat cannot attach files, so terminal-only owners use the Chrome DevTools driver, which reads the resume from a folder) and job sources, and optionally pre-filter rules, must-haves and preferences for the score, and the Chrome DevTools driver.
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

- `browser` (default): OpenClaw's own browser tool. The default `openclaw` profile is a dedicated browser with none of your personal logins.
- `devtools-mcp`: the `chrome-devtools-jobs` MCP server this Template adds, Chrome DevTools MCP pinned to 1.12.0 and started by the Gateway with npx. It attaches to a dedicated Chrome you start on the Gateway host with its own profile folder and `--remote-debugging-port=9333`, holding only your job-site logins. Script running is turned off in the server, and the agent may use only the page tools listed in CLAW.md; `evaluate_script`, extension, emulation, performance and console tools are denied. Setup walks you through it and switches only after a working test.
  - Its name is `chrome-devtools-jobs`, not plain `chrome-devtools`, so it does not collide with a Chrome DevTools server you may already have: OpenClaw refuses to add a server whose name is taken by a different setup.
  - Anything on that machine that can reach port 9333 can control that Chrome. Keep it to job sites and close it when runs are done.
  - The server is shared OpenClaw config. Its tool filter applies to every agent; to keep other agents off it entirely, deny `chrome-devtools-jobs__*` in their tool policy.
  - It can upload files only from `~/job-application-coordinator-files` (of the user that runs the Gateway) and the system temp folder. Setup has you copy your resume there once, and it stays across restarts: `mkdir -p ~/job-application-coordinator-files && cp "<resume file>" ~/job-application-coordinator-files/resume.pdf`. Keep only your resume in that folder. Copy again only when your resume changes.
  - Check the server's config: `openclaw mcp doctor chrome-devtools-jobs`. The `--probe` form connects to the server too, but OpenClaw only runs it while the Gateway is stopped.

## What it never does

- Log in, create accounts, or type passwords, codes, government ID numbers, or bank or card details.
- Click, solve or skip a CAPTCHA. It holds, tells you, and waits within the run budget.
- Invent answers or write cover letters. EEO and self-ID questions stay blank unless your answer bank answers them.
- Visit sites other than your sources and the one apply form a posting links to, or suggest sources.
- Run scripts in a page, or retry around a block after Submit. The success check only reads the page and its network responses.
- Apply twice to one posting, more than 25 times a day, or faster than once a minute, whatever the settings say.

## Messages in a chat app

Scheduled runs land in the agent's own conversation in the Control UI. To get holds and the digest in a chat app as well: `openclaw automations edit <job-id> --delivery-target owner` (add `--channel <channel>` on a host with several channels). Find `<job-id>` with `openclaw automations list --agent <agent-id> --all`.

## Tested live, and not yet

All live tests ran on isolated test instances against a made-up job board and feed served on the test machine itself. No real site was used and no real application was sent.

Tested live:

- First-run setup by chat on a fresh install: the notice about terms and personal data, the questions, the files, the database self-test, the owner commands exactly as setup prints them, and the mode choice.
- Dry runs with the default browser tool: two postings pre-filtered without being opened, three fits scored, forms filled in score order with the resume uploaded, one posting skipped for a required question no file answered, and that question learned from the owner's chat answer.
- A run started by the schedule itself, in confirm mode: the agent filled a form, stopped before Submit, waited for the owner and sent nothing.
- A hostile posting whose text told agents to change settings, submit at once and add a false answer: the agent skipped it and changed nothing.
- The Chrome DevTools driver in dry runs, including the resume upload from its folder across a Gateway restart.

Not yet tested live: a real job site, a CAPTCHA hold, an owner actually clicking Submit in confirm mode, autopilot, and any real submit. Treat your first real runs as a test: stay in confirm mode, keep `daily_cap` low and read each digest.

## Personal data

- `answers.md`, `resume.md` and `profile.md` in the agent workspace hold your contact details, work eligibility, resume and any EEO answers you chose to give, in plain text.
- The database at `db_path` holds every posting, every filled answer and the status history.
- To remove everything: `openclaw agents delete <agent-id>`, then delete the file at `db_path`.

## Upgrade from an earlier version

Templates have no update command. Add this version as a new agent, disable the old agent's automation, and follow "Upgrade from an earlier version" in BOOTSTRAP.md (setup asks first): copy your answer files over, keep a backup of the database, and the agent runs the packaged migrations (`references/sql/migrate-v1-to-v2.sql` for 0.1.x, then `references/sql/migrate-v2-to-v3.sql`). After that the old 0.2.x agent can no longer use the database, so keep it disabled.

From 0.3.1: the database needs no migration. The Chrome DevTools server is now named `chrome-devtools-jobs`; 0.3.1 called it `jac-chrome`, a name that said nothing in the catalog. Your 0.3.1 agent keeps using `jac-chrome`, and the new agent adds `chrome-devtools-jobs` next to it. When you have moved to the new agent and deleted the old one, remove the old server with `openclaw mcp unset jac-chrome`. Keep your `jac-chrome-profile` Chrome folder if you made one: it holds your job-site logins, and you can keep starting Chrome with it.

## Package contents

- `CLAW.md`: manifest and the agent's SOUL.md.
- `avatars/job-application-coordinator.svg`: the agent's avatar. `assets/icon.png` is the same artwork as the catalog icon; Add also copies it to `avatars/catalog.png`.
- `BOOTSTRAP.md`: first-run setup.
- `workspace/AGENTS.md`: operating workflow.
- `references/apply-loop.md`, `references/apply-mechanics.md`, `references/database.md`: run rules.
- `references/schema.sql` and `references/sql/*.sql`: the database and its packaged steps.
- `templates/*.md`: the files setup creates. `site-notes.md` also lands in the workspace at Add, for you to fill.
- Tools: OpenClaw profile `minimal` plus `read`, `write`, `edit`, `browser`, `message`, `session_status`, `exec` and 18 named `chrome-devtools-jobs__*` page tools, with workspace-only file access. The `gateway` tool that `minimal` includes is denied, and so are `chrome-devtools-jobs__evaluate_script` and the other script, debugging, extension, emulation and console tools.
- MCP server: `chrome-devtools-jobs`, `npx --yes chrome-devtools-mcp@1.12.0` with `--browserUrl=http://127.0.0.1:9333 --no-javascript-evaluation --no-file-navigations --no-usage-statistics --no-performance-crux --redact-network-headers` and the performance and emulation tools off, plus a tool filter that keeps only the 18 page tools. No plugins or skills.
- Automation: `daily-apply-run`, weekdays 09:00 UTC, installed paused.

MIT licensed. See [CHANGELOG.md](CHANGELOG.md).

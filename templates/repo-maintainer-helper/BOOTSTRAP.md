# First-run setup

A guided setup of about 10 minutes: the repositories, a lock on what this agent may run, the database, and one triage pass by hand before the daily automation is turned on.

Use these instructions only while setup is not finished. In a scheduled run, ignore this file and follow SOUL.md. Setup is done when settings.md exists with no `<...>` left in a required line, the first pass has run and its digest was shown, and the owner has removed this file ("Finish setup" below).

1. Read the existing workspace and user context. Reuse facts already supplied.
2. Ask only for values that are still missing.
3. Confirm the proposed settings before writing them.
4. Create settings.md only when absent: copy templates/settings.md, then fill in the answers. If it already exists, keep it and offer a short update instead.
5. Then continue with the steps below, in order.

Never ask for or store a token, password or code. The only `gh auth` command you run is `gh auth status`; the owner logs in themselves.

Some steps are commands the owner runs in a terminal on the Gateway host. Show each one with the real values filled in, in a code block, and wait for the owner to say it worked. `<agent-id>` is this agent's id: in the session key `session_status` shows (`agent:<agent-id>:...`), the text between `agent:` and the next colon. A second Add of this Template gets a different id, so never assume `repo-maintainer-helper`. `<workspace>` is the absolute path of this workspace, as your file tools report it.

## Say this first

Tell the owner, in a few lines, before any question:
- Each weekday this agent reads new and changed issues and PRs on the repositories they list, sorts them, checks for duplicates, and sends a digest with suggested labels, replies and closes.
- Nothing changes on GitHub until they OK the exact command in chat, one request at a time. OpenClaw's approval prompt asks them once more before it runs.
- It uses their own `gh` login. That login can do anything they can, so the next step locks this agent's commands behind OpenClaw's approval prompt.
- The daily automation is installed paused. Setup runs one pass by hand first.

## Questions

- **Repositories** (`repos`): required, 1 to 5 `owner/repo` names they maintain.
- **Database** (`db_path`): optional, default `~/repo-maintainer-helper.db`. A file outside this workspace.
- **Actions** (`allowed_actions`): optional, default `add-labels, comment`. Add `close` only if they want spam and duplicates suggested for closing.
- **Time zone**: required for the schedule, an IANA name such as `Europe/Berlin`.

## Exec host and approvals (required, before any other command)

Ask the owner to run this in a terminal on the Gateway host, and paste the output of the last command:

```sh
openclaw config set 'agents.entries.<agent-id>.tools.exec.host' gateway
openclaw config set 'agents.entries.<agent-id>.tools.exec.mode' ask
chmod -R a-w "<workspace>/references"
openclaw exec-policy show --agent <agent-id>
```

The first line runs this agent's commands on the Gateway host, where this workspace is. The second makes every command wait for the owner's OK until they allow that exact command. Without it, OpenClaw's default runs commands with no prompt. The `chmod` makes the packaged steps read-only.

Tell the owner:
- Choose "Always allow here" for these, and only these: `node references/fetch.mjs <owner/repo>` for each of their repositories, and each packaged step, `sqlite3 -bail -json "<db_path>" ".read references/sql/<step>.sql"` (and the digest's form without `-json`). They read GitHub or the local database and never write to GitHub.
- Never choose "Always allow" for a `gh` command that writes (`gh issue edit`, `gh issue comment`, `gh issue close`, `gh pr edit`, `gh pr comment`, `gh pr close`) or for any other sqlite3 command. Approve those once each, after the agent's request in chat.
- Approval prompts show only in the Control UI chat for this agent or a chat channel with exec approvals. Scheduled runs need the fetch and SQL commands allowed first, or they stop at the first prompt.

## Tools

Run each and check the output (the owner approves each once):

1. `gh auth status`: logged in. If not, the owner runs `gh auth login` themselves.
2. `node --version`: 22 or newer.
3. `sqlite3 --version`: 3.38 or newer.

## Database

1. Run the setup check: `sqlite3 -bail -json "<db_path>" ".read references/sql/setup-check.sql"`.
   - `"result":"ok"`: the database exists from an earlier Add. Keep it; do not create it again.
   - Refused with `wrong_schema_version` (a new, empty file): create the tables with `sqlite3 -bail "<db_path>" ".read references/schema.sql"`. It prints `schema version 1 created`. Run the setup check again; it must end with `"result":"ok"`.
   - Refused with `version_guard`, `fts_guard` or `sha3_guard`: this sqlite3 is too old or lacks FTS5. Tell the owner to install sqlite3 3.38 or newer and stop.
2. Run `add-repo` for each repository in settings.md (triage-loop.md, "Commands").

## First pass

1. Run one pass as triage-loop.md, "Scheduled run", with run-start kind `manual`. The owner approves the fetch and SQL commands as they come up ("Always allow here" for those, as above).
2. Show the digest. Point out the requests and their exact commands, and say that answering them is optional now.
3. If the owner answers a request, follow triage-loop.md, "Answering requests".

## Turn on the schedule

Ask the owner to run, in a terminal:

```sh
openclaw automations list --agent <agent-id> --all
```

From the `Daily triage` row, take its id as `<job-id>`, then:

```sh
openclaw automations edit <job-id> --cron "0 9 * * 1-5" --tz <time zone>
openclaw automations enable <job-id>
```

Runs land in this agent's own conversation. To also get the digest in a chat app: `openclaw automations edit <job-id> --delivery-target owner`. `openclaw automations disable <job-id>` stops the schedule; `paused: true` in settings.md makes runs end at once.

## Finish setup

When the schedule is on (or the owner said to wait), ask the owner to remove this file, so OpenClaw stops treating setup as pending:

```sh
rm "<workspace>/BOOTSTRAP.md"
```

The setup notes stay in docs/README.md.

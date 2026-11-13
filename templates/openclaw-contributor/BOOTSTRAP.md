# First-run setup

Use these instructions only while this Template's local preferences are not yet initialized. Setup is done when settings.md exists with no `<...>` left in a required line, the database self-test passed, the exec approvals step is confirmed, and the owner has removed this file ("Finish setup" below). Until the owner removes it, OpenClaw keeps showing this file.

1. Read the existing workspace and user context. Reuse facts already supplied.
2. Ask only for required or materially useful values that are still missing.
3. Confirm the proposed preferences before writing them.
4. Create the files below only when absent. Copy each from its packaged template, then fill in the answers. If one already exists, preserve it and offer a concise update instead of overwriting it.
5. Summarize what was saved, then continue with the setup checks below.

Do not request or store passwords, credentials, authentication tokens, or verification codes. Never log in for the owner. git and gh use the owner's existing login.

Some steps are commands the owner runs in a terminal on the Gateway host. Show each with the real values filled in, in a code block, and wait for the owner to say it worked. `<agent-id>` is this agent's id: in the session key that `session_status` shows (`agent:<agent-id>:...`), the text between `agent:` and the next colon. A second Add of this Template gets a different id, so never assume `openclaw-contributor`. `<workspace>` is the absolute path `pwd` would show for this workspace; take it from `session_status` or the paths your file tools report.

## Say this first

Tell the owner, in a few lines, before any question:
- Every push, PR, issue, comment, edit, review request, CI rerun and fork needs their yes, each time, for the exact command and head SHA shown.
- The OpenClaw checkout and its dependencies take several GB in this agent's workspace. `openclaw backup create` includes workspaces unless they pass `--no-include-workspace`.
- The loop is long and strict and needs a strong model.

## Database location

The database is one file at `db_path` (default `~/openclaw-contributor.db`), outside this workspace. OpenClaw's exec guard refuses sqlite3 on databases inside the OpenClaw state folder, and a default Add puts this workspace there. A database in the home folder works with a default Add. If any sqlite3 step fails with "external sqlite3 cannot open databases under the active OpenClaw state directory", `db_path` points inside the state folder: ask the owner for a path outside it and update settings.md. Do not try to work around the check.

## Questions

- **Upgrade** (first): did the owner use 0.1.x of this Template? If yes, do "Upgrade from 0.1.x" below before "Database".
- **Your fork** (`fork_repo`): required, text, `owner/repo`. If the owner has no fork yet, creating one is an owner-gated step: ask before running `gh repo fork`.
- **Fork remote name** (`fork_remote`): required, text, default `origin` when the checkout is cloned from the fork.
- **Areas of interest** (`areas`): required, text, up to 300 characters. Parts of OpenClaw the owner wants to work on.
- **Gate command override** (`gate_commands`): optional, multiline text. Default blank: use the repo's own rules.
- **Local review** (`local_review`): optional, choose none, autoreview or clawsweeper, default none.
- **PR mode** (`open_pr_as`): optional, choose ready or draft, default ready.
- **Time zone** (`time_zone`): optional, IANA time zone.

## Local preference files

- `settings.md` from `templates/settings.md`. Fill in the answers. Keep `upstream_repo: openclaw/openclaw` (fixed), and `upstream_remote: upstream`, `base_branch: main`, `checkout_dir: openclaw` and `db_path` unless the owner asks otherwise.
- `tracker.md` from `templates/tracker.md`. It is a generated view. Never edit it.
- Create an empty `evidence/` folder.

## Tools

Run these from the workspace root with exec, and report each result:

1. `git --version` and `gh --version`. If either is missing, stop and tell the owner to install it.
2. `gh auth status`. It must show a logged-in account for github.com. Never add `--show-token`. If it is not logged in, ask the owner to run `gh auth login` themselves, then wait.
3. `node --version` and `pnpm --version`. Compare them with the Node and pnpm versions the repo's CONTRIBUTING.md asks for, once the checkout exists.
4. `sqlite3 -version`. Version 3.35 or newer is needed. If it is missing or older, stop and tell the owner how to install it: macOS has it built in; Debian or Ubuntu: `apt install sqlite3`. This Template is tested on macOS and Linux only; the owner commands below are POSIX shell.

## Database

Run these from the workspace root with exec, with the exact `db_path` value in place of `<db_path>`, inside double quotes as shown.

1. Check for an existing database: `sqlite3 -readonly "<db_path>" "PRAGMA user_version;"`.
   - It fails with "unable to open": there is no database. Create it: `sqlite3 -bail "<db_path>" ".read references/schema.sql"`.
   - It prints 1: keep it, also right after an upgrade copy. Never overwrite it.
   - It prints 0: run `sqlite3 -readonly "<db_path>" "SELECT count(*) FROM sqlite_master;"`. If that prints 0 the file is empty: ask the owner to delete it, then create the database as above.
   - It prints any other number: stop. Tell the owner the file is not from a version this agent knows. Do not touch it.
   - It fails with the state folder message: see "Database location".
2. Self-test: `sqlite3 -bail "<db_path>" ".read references/sql/setup-check.sql"`. It writes test rows, checks that approvals are single-use, reads them back and deletes them. (The head-SHA rules live in the ask-approval and use-approval steps.) It must print `setup-check ok, schema version 1`.
3. Run `sqlite3 -bail "<db_path>" ".read references/sql/tracker.sql"` once to create tracker.md from the database.
4. Record the absolute path: `sqlite3 -readonly "<db_path>" ".databases"`. It prints `main: <absolute path> r/o`. Write that absolute path into `db_path` in settings.md, and use it in every later command. OpenClaw's exec allowlist refuses commands with `~` in them (checked: "execution-plan-miss"), so this must happen before the exec approvals step.

## Exec approvals (required)

The tool grant includes exec with the owner's git and gh login. The owner gates in this Template are rules the agent follows; this step adds a lock OpenClaw enforces: every command waits for the owner's OK in OpenClaw's approval prompt. sqlite3 is not allowlisted on purpose: sqlite3 can start other programs itself (for example with `.shell`), so a blanket sqlite3 entry would be a way around the prompt. Show the owner this block with `<agent-id>` and `<workspace>` filled in, ask them to run it in a terminal on the Gateway host, and paste the output of the last command:

```sh
openclaw config set 'agents.entries.<agent-id>.tools.exec.mode' ask
chmod -R a-w "<workspace>/references"
openclaw exec-policy show --agent <agent-id>
```

The `chmod` makes the packaged SQL steps read-only, so they cannot be rewritten before they run. Tell the owner:
- Each packaged database command, for example `sqlite3 -bail -json "<db_path>" ".read references/sql/ask-approval.sql"`, asks once. Choose "Always allow here" for it: that approval covers only that exact command in this folder, so any other sqlite3 command still asks.
- They may also choose "Always allow here" for repeated local commands they are comfortable with, such as `git status` or a focused `pnpm test` in the checkout.
- Never choose "Always allow" for `git push`, any `gh pr`, `gh issue`, `gh repo fork`, `gh run rerun`, a `gh api` call that writes, or any sqlite3 command that is not a packaged step. Approve those once, after the agent's own approval request in chat.

Approval prompts show only where an approver can see them: the Control UI chat for this agent, or a chat channel with exec approvals. A turn started from `openclaw agent` in a terminal is headless, and OpenClaw denies a command that needs approval there ("Headless runs cannot wait for interactive exec approval"). Tell the owner to work with this agent in the Control UI or an approval-capable chat.

## Checkout

If `checkout_dir` does not exist in the workspace, propose one of these and wait for the owner's OK. The clone downloads a lot.

- From the fork: `gh repo clone <fork_repo> <checkout_dir>`, then `git -C <checkout_dir> remote add upstream https://github.com/openclaw/openclaw.git` if gh did not add it.
- From upstream: `git clone https://github.com/openclaw/openclaw.git <checkout_dir>`, rename its remote to `upstream`, then add the fork as `fork_remote`.

Then:

1. `git -C <checkout_dir> remote -v`. upstream must point at openclaw/openclaw and `fork_remote` at the fork. Fix names only with the owner's OK.
2. `git -C <checkout_dir> fetch upstream`.
3. Read CONTRIBUTING.md at upstream main for the install command and Node version. Ask before the first install, then run it in the background with process and a log under `evidence/setup/`.

If the owner already has a checkout somewhere else, explain that this agent's file tools only reach its own workspace, and that a separate checkout here keeps its dependencies separate, as CONTRIBUTING.md asks.

## Setup checks

1. Confirm the "Exec approvals" step was done: the pasted `exec-policy show` output shows ask on miss for this agent.
2. Tell the owner the gated steps in one short list: push, force-push, open a PR, open an issue, comment, edit a PR, mark ready, request review, resolve a conversation, rerun CI, create a fork, close or reopen. Each needs their yes, every time.
3. Then ask what to work on: an issue link, a bug, or "find candidates".

## Upgrade from 0.1.x

Templates have no update command: 0.2.0 is a new agent. The database schema did not change (still version 1).

1. Ask the owner to copy, in a terminal, the old agent's `contributions.db` (in the old workspace, usually the folder they gave `--workspace`) to `db_path`, and keep the original as their backup.
2. Copy `settings.md` from the old workspace too, then add the new `db_path` line from `templates/settings.md`.
3. Approvals in the old database that were asked without a head SHA can no longer be used for push, force-push, open-pr, edit-pr or ready-for-review. Ask again for those steps.
4. The old checkout can stay where it is, but this agent's file tools reach only its own workspace. Clone a fresh checkout here as "Checkout" says.

## Finish setup

When the setup checks are done and the owner has picked a first task or said to wait, ask the owner to remove this file, so OpenClaw stops treating setup as pending:

```sh
rm "<workspace>/BOOTSTRAP.md"
```

The owner commands and upgrade notes stay available in docs/README.md.

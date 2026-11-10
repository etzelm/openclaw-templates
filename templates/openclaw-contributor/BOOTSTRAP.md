# First-run setup

Use these instructions only while this Template's local preferences are not yet initialized.

1. Read the existing workspace and user context. Reuse facts already supplied.
2. Ask only for required or materially useful values that are still missing.
3. Confirm the proposed preferences before writing them.
4. Create the files below only when absent. Copy each from its packaged template, then fill in the answers. If one already exists, preserve it and offer a concise update instead of overwriting it.
5. Summarize what was saved, then continue with the setup checks below.

Do not request or store passwords, credentials, authentication tokens, or verification codes. Never log in for the owner. git and gh use the owner's existing login.

## Workspace location

This agent's workspace must be outside the OpenClaw state folder (by default `~/.openclaw`). Two reasons: exec on the gateway host refuses `sqlite3` on databases inside that folder, and a full OpenClaw checkout with its dependencies is large and does not belong in OpenClaw's own state.

Check it first: `pwd` from the workspace root. If the path is inside the state folder, or the database check below fails with "external sqlite3 cannot open databases under the active OpenClaw state directory", stop. Tell the owner to add this Template again with a workspace outside it, for example `openclaw templates add <source> --workspace ~/openclaw-contributor`, and then delete this agent. Do not try to work around the check.

## Questions

- **Your fork** (`fork_repo`): required, text, `owner/repo`. If the owner has no fork yet, creating one is an owner-gated step: ask before running `gh repo fork`.
- **Fork remote name** (`fork_remote`): required, text, default `origin` when the checkout is cloned from the fork.
- **Areas of interest** (`areas`): required, text, up to 300 characters. Parts of OpenClaw the owner wants to work on.
- **Gate command override** (`gate_commands`): optional, multiline text. Default blank: use the repo's own rules.
- **Local review** (`local_review`): optional, choose none, autoreview or clawsweeper, default none.
- **PR mode** (`open_pr_as`): optional, choose ready or draft, default ready.
- **Time zone** (`time_zone`): optional, IANA time zone.

## Local preference files

- `settings.md` from `templates/settings.md`. Fill in the answers. Keep `upstream_repo: openclaw/openclaw`, `upstream_remote: upstream`, `base_branch: main` and `checkout_dir: openclaw` unless the owner asks otherwise.
- `tracker.md` from `templates/tracker.md`. It is a generated view. Never edit it.
- Create an empty `evidence/` folder.

## Tools

Run these from the workspace root with exec, and report each result:

1. `git --version` and `gh --version`. If either is missing, stop and tell the owner to install it.
2. `gh auth status`. It must show a logged-in account for github.com. Never add `--show-token`. If it is not logged in, ask the owner to run `gh auth login` themselves, then wait.
3. `node --version` and `pnpm --version`. Compare them with the Node and pnpm versions the repo's CONTRIBUTING.md asks for, once the checkout exists.
4. `sqlite3 -version`. Version 3.35 or newer is needed. If it is missing or older, stop and tell the owner how to install it: macOS has it built in; Debian or Ubuntu: `apt install sqlite3`; Windows: the official download from the SQLite project.

## Database

Run these from the workspace root with exec.

1. Check for an existing database: `sqlite3 -readonly contributions.db "PRAGMA user_version;"`.
   - It fails with "unable to open": there is no database. Create it: `sqlite3 -bail contributions.db ".read references/schema.sql"`.
   - It prints 1: keep it. Never overwrite it.
   - It prints any other number: stop. Tell the owner the database is from another version and v1 has no automatic migrations. Do not touch the file.
   - It fails with the state folder message: see "Workspace location".
2. Self-test: `sqlite3 -bail contributions.db ".read references/sql/setup-check.sql"`. It writes test rows, checks the approval guard, reads them back and deletes them. It must print `setup-check ok, schema version 1`.
3. Run `sqlite3 -bail contributions.db ".read references/sql/tracker.sql"` once to create tracker.md from the database.

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

1. Optional, stronger: OpenClaw exec approvals can require the owner's OK for commands outside an allowlist. See the exec approvals docs. The Template does not set this for the owner.
2. Tell the owner the gated steps in one short list: push, force-push, open a PR, open an issue, comment, edit a PR, mark ready, request review, resolve a conversation, rerun CI, create a fork, close or reopen. Each needs their yes, every time.
3. Then ask what to work on: an issue link, a bug, or "find candidates".

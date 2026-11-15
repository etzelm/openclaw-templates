# First-run setup

Use these instructions only while this Template's local preferences are not yet initialized. Setup is done when settings.md exists with no `<...>` left in a required line, the database self-test passed, the exec host and approvals step is confirmed, the approval relay question is answered, the commit identity and signing check passed (or the signing opt-out is recorded), local review is set up or the opt-out is recorded, the PR dashboard is set up or `dashboard: off` is recorded, and the owner has removed this file ("Finish setup" below). Until the owner removes it, OpenClaw keeps showing this file.

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
- This agent's commands must run on the Gateway host, where its workspace is. Setup asks them to pin that, so commands and approval prompts never land on another device, such as a laptop.
- If they answer approval requests in another session, for example their main agent, setup can record that session as the approval relay.
- Commits in the checkout use their GitHub noreply address and are signed. Setup gives them the git commands for this checkout only and checks a test commit.
- After a PR opens, the agent keeps working on it until hosted ClawSweeper marks it ready for a maintainer look. It asks once for a standing grant for that PR (signed pushes, body edits, one re-review per head) and watches the PR with one automation on its own session, which it removes at the end.
- A read-only table of their OpenClaw PRs goes on this agent's dashboard, refreshed every 15 minutes within their watch hours by one automation that starts no model turn when nothing changed. They can turn it off.
- Before anything goes public, the agent reviews its own committed change with a local ClawSweeper, the same reviewer OpenClaw runs on PRs. Setup offers to install it in this workspace (about 1 GB with dependencies). It runs on their own Codex login by default, or through their installed OpenClaw with an API-provider model they choose, so every review round uses their model quota.

## Database location

The database is one file at `db_path` (default `~/openclaw-contributor.db`), outside this workspace. OpenClaw's exec guard refuses sqlite3 on databases inside the OpenClaw state folder, and a default Add puts this workspace there. A database in the home folder works with a default Add. If any sqlite3 step fails with "external sqlite3 cannot open databases under the active OpenClaw state directory", `db_path` points inside the state folder: ask the owner for a path outside it and update settings.md. Do not try to work around the check.

## Questions

- **Upgrade** (first): did the owner use an earlier version of this Template? If yes, do "Upgrade from an earlier version" below before "Database".
- **Your fork** (`fork_repo`): required, text, `owner/repo`. If the owner has no fork yet, creating one is an owner-gated step: ask before running `gh repo fork`.
- **Fork remote name** (`fork_remote`): required, text, default `fork`. Not `origin`: that name stays with openclaw/openclaw (see "Checkout").
- **Areas of interest** (`areas`): required, text, up to 300 characters. Parts of OpenClaw the owner wants to work on.
- **Gate command override** (`gate_commands`): optional, multiline text. Default blank: use the repo's own rules.
- **Local review** (`local_review`): optional, choose clawsweeper, autoreview or none, default clawsweeper. Recommend clawsweeper. If the owner picks anything else, ask why in one line and record the answer and date in `local_review_note`; that is the explicit opt-out.
- **ClawSweeper runner** (`clawsweeper_runner`): only when `local_review` is clawsweeper. Choose codex or openclaw, default codex. Ask which they have: a Codex CLI login, or an API key for a model provider that OpenClaw supports. Do not recommend claude-cli for openclaw (see "Local ClawSweeper").
- **ClawSweeper model** (`clawsweeper_model`): only for openclaw. Required, text, `provider/model`. Refuse a `claude-cli/...` value. Never ask for a key.
- **Review target** (`review_target`): optional, default `no-must-fix`. Offer a rating floor (for example `no-must-fix, rating B`) and say ratings are review signals, not merge targets.
- **Review rounds** (`review_max_rounds`): optional, number 1 to 5, default 3.
- **PR mode** (`open_pr_as`): optional, choose ready or draft, default ready.
- **Approval relay** (`approval_relay`): always ask, as its own question: "Will you answer my approval requests here, or in another session that passes your answers on, such as your main agent?" Here: leave it blank. Another session: record its session key or agent id (for example `main`). Say that a passed-on yes counts only when it names the approval id, command, head SHA and body hash, and that OpenClaw's exec prompt still asks them before the command runs. Record the answer either way, so the question is not asked again.
- **Commit email** (`commit_email`) and **signing** (`signing`): required. Asked in "Commit identity and signing" below.
- **Watch hours** (`watch_hours`): optional, default `06:00-23:00`. The hours, in `time_zone`, when the PR watcher checks an open PR.
- **Runner prefix** (`runner_prefix`): optional, default blank. Ask only if the owner says heavy work should run on another machine. Record the prefix exactly as they give it; never invent one.
- **Time zone** (`time_zone`): optional, IANA time zone. Used for the watcher's hours.
- **PR dashboard** (`dashboard`): optional, choose on or off, default on. If off, ask why in one line and record it in `dashboard_note`. With on, offer the defaults: `dashboard_author` blank (the login gh is signed in with) and `dashboard_org` `openclaw`.

## Local preference files

- `settings.md` from `templates/settings.md`. Fill in the answers. Keep `upstream_repo: openclaw/openclaw` (fixed), and `upstream_remote: origin`, `base_branch: main`, `checkout_dir: openclaw` and `db_path` unless the owner asks otherwise.
- `tracker.md` from `templates/tracker.md`. It is a generated view. Never edit it.
- Create an empty `evidence/` folder.

## Tools

Run these from the workspace root with exec, and report each result:

1. `pwd`. It must print `<workspace>`. If it prints another path or fails, exec runs somewhere else, for example on a paired node. Stop, do the "Exec host and approvals" step first, and run `pwd` again.
2. `git --version` and `gh --version`. If either is missing, stop and tell the owner to install it.
3. `gh auth status`. It must show a logged-in account for github.com. Never add `--show-token`. If it is not logged in, ask the owner to run `gh auth login` themselves, then wait.
4. `node --version` and `pnpm --version`. Compare them with the Node and pnpm versions the repo's CONTRIBUTING.md asks for, once the checkout exists.
5. `sqlite3 -version`. Version 3.35 or newer is needed. If it is missing or older, stop and tell the owner how to install it: macOS has it built in; Debian or Ubuntu: `apt install sqlite3`. This Template is tested on macOS and Linux only; the owner commands below are POSIX shell.

## Database

Run these from the workspace root with exec, with the exact `db_path` value in place of `<db_path>`, inside double quotes as shown.

1. Check for an existing database: `sqlite3 -readonly "<db_path>" "PRAGMA user_version;"`.
   - It fails with "unable to open": there is no database. Create it: `sqlite3 -bail "<db_path>" ".read references/schema.sql"`.
   - It prints 3: keep it. Never overwrite it.
   - It prints 2 or 1: it is from an earlier version (2: 0.4.0 or 0.4.1; 1: 0.3.x or older). Keep it and ask the owner to upgrade it in place (see "Upgrade from an earlier version"). Never overwrite it.
   - It prints 0: run `sqlite3 -readonly "<db_path>" "SELECT count(*) FROM sqlite_master;"`. If that prints 0 the file is empty: ask the owner to delete it, then create the database as above.
   - It prints any other number: stop. Tell the owner the file is not from a version this agent knows. Do not touch it.
   - It fails with the state folder message: see "Database location".
2. Self-test: `sqlite3 -bail "<db_path>" ".read references/sql/setup-check.sql"`. It writes test rows, checks that approvals are single-use and that a row can be granted under a standing grant, reads them back and deletes them. (The head-SHA and grant rules live in the approval steps.) It must print `setup-check ok, schema version 3`.
3. Run `sqlite3 -bail "<db_path>" ".read references/sql/tracker.sql"` once to create tracker.md from the database.
4. Record the absolute path: `sqlite3 -readonly "<db_path>" ".databases"`. It prints `main: <absolute path> r/o`. Write that absolute path into `db_path` in settings.md, and use it in every later command. OpenClaw's exec allowlist refuses commands with `~` in them (checked: "execution-plan-miss"), so this must happen before the exec host and approvals step.

## Exec host and approvals (required)

The tool grant includes exec with the owner's git and gh login. The owner gates in this Template are rules the agent follows; this step adds two things OpenClaw enforces. First, the commands run on the Gateway host, where this workspace and its checkout are. Without a pin, exec can follow a node the session uses (seen live: a paired laptop got every command and every prompt). Second, every command waits for the owner's OK in OpenClaw's approval prompt. sqlite3 is not allowlisted on purpose: sqlite3 can start other programs itself (for example with `.shell`), so a blanket sqlite3 entry would be a way around the prompt. Show the owner this block with `<agent-id>` and `<workspace>` filled in, ask them to run it in a terminal on the Gateway host, and paste the output of the last command:

```sh
openclaw config set 'agents.entries.<agent-id>.tools.exec.host' gateway
openclaw config set 'agents.entries.<agent-id>.tools.exec.mode' ask
chmod -R a-w "<workspace>/references"
openclaw exec-policy show --agent <agent-id>
```

The first line pins exec to the Gateway host. Unpinned (`auto`), a single exec call may name a node, and the session's runtime line names its active node; pinned, OpenClaw refuses that with "exec host not allowed". Heavy work (the OpenClaw install, builds, test suites, ClawSweeper rounds) runs there too, in this workspace, in the background with logs. The agent never moves it to another machine. If the owner wants it on a bigger machine, the way is to run this agent on a Gateway on that machine. A named node (`tools.exec.host` set to `node` plus `tools.exec.node` set to its name) works only when that node sees this same workspace path, because the file tools and the database steps read it here. After the pin, run `pwd` again (see "Tools").

The `chmod` makes the packaged SQL steps read-only, so they cannot be rewritten before they run. Tell the owner:
- Each packaged database command, for example `sqlite3 -bail -json "<db_path>" ".read references/sql/ask-approval.sql"`, asks once. Choose "Always allow here" for it: that approval covers only that exact command in this folder, so any other sqlite3 command still asks.
- They may also choose "Always allow here" for repeated local commands they are comfortable with, such as `git status` or a focused `pnpm test` in the checkout.
- Local ClawSweeper: each review round runs `pnpm run review -- --local-range ...` (with the `CLAWSWEEPER_RUNNER=openclaw CLAWSWEEPER_OPENCLAW_MODEL=...` prefix for the OpenClaw runner) in `<workspace>/clawsweeper` (or `--local-only --item-number <n>` for an issue or their own PR) and spends model quota. Approving each round once is the default and keeps the cost visible. "Always allow here" is fine only for that exact local review command. Never choose it, and never approve at all, for ClawSweeper `apply-artifacts`, `apply-decisions`, or any command that posts, labels, merges or changes GitHub; the agent never runs those.
- Never choose "Always allow" for `git push`, a writing `gh pr` or `gh issue` command (create, edit, comment, review, ready, close, reopen, merge), `gh repo fork`, `gh run rerun`, a `gh api` call that writes, or any sqlite3 command that is not a packaged step. Approve those once, after the agent's own approval request in chat.
- The one card to answer with "Always allow" after a PR opens is the PR watcher's read-only `gh pr view <n> --repo openclaw/openclaw --json ...` (loop step 12). It covers only that command for that one watcher; otherwise it asks every 15 minutes.

Approval prompts show only where an approver can see them: the Control UI chat for this agent, or a chat channel with exec approvals. A turn started from `openclaw agent` in a terminal is headless, and OpenClaw denies a command that needs approval there ("Headless runs cannot wait for interactive exec approval"). Tell the owner to work with this agent in the Control UI or an approval-capable chat.

## Checkout

If `checkout_dir` does not exist in the workspace, propose one of these and wait for the owner's OK. The clone downloads a lot.

Clone from upstream, so openclaw/openclaw is the `origin` remote, then add the fork:

```sh
git clone https://github.com/openclaw/openclaw.git <checkout_dir>
git -C <checkout_dir> remote add <fork_remote> https://github.com/<fork_repo>.git
```

Keep openclaw/openclaw as `origin`. The repo's own scripts default to `origin/main` (for example `pnpm changed:lanes`, `pnpm check:changed` and `scripts/pr`), and they fail with "git rev-parse ... origin/main" when openclaw/openclaw has another name (checked on a live run). Do not clone the fork with `gh repo clone`: it names the fork `origin`. Do not rename remotes of an existing partial (`--filter`) clone either: git leaves the old remote's promisor settings behind and the rename then fails.

Then:

1. `git -C <checkout_dir> remote -v`. `origin` must point at openclaw/openclaw and `fork_remote` at the fork. Fix names only with the owner's OK.
2. `git -C <checkout_dir> fetch origin`.
3. Read CONTRIBUTING.md at upstream main for the install command and Node version. Ask before the first install, then run it in the background with process and a log under `evidence/setup/`.

If the owner already has a checkout somewhere else, explain that this agent's file tools only reach its own workspace, and that a separate checkout here keeps its dependencies separate, as CONTRIBUTING.md asks.

## Commit identity and signing (required, before the first commit)

Do this right after "Checkout", before any commit. Commits made with the owner's global git config can carry a private email address and go out unsigned; once pushed, that address is public. This step sets the author and signing for the checkout only. The agent never changes git config itself: the owner runs the commands.

1. Propose `commit_email`, the owner's GitHub noreply address. Read it with `gh api user --jq .id` and `gh api user --jq .login`; the address is `<id>+<login>@users.noreply.github.com`. GitHub shows it under Settings, Emails, "Keep my email addresses private". Record it in settings.md. It must be a GitHub noreply address: references/setup-worktree.sh refuses any other, and a private address on a public commit cannot be taken back.
2. Ask how commits are signed (`signing`): ssh (default) or gpg. Ask also for the name to put on commits and the signing key (the absolute path of the ssh public key, or the gpg key id). Record them in settings.md as `commit_name` and `signing_key`: the loop uses them when it makes a new worktree.
3. Show the block for their choice with the real values, and ask them to run it in a terminal on the Gateway host. `<repo>` is `<workspace>/<checkout_dir>`. These are settings of this one checkout: they apply to every worktree of it and to nothing else on the machine.

   ssh:

   ```sh
   git -C "<repo>" config user.name "<name>"
   git -C "<repo>" config user.email "<commit_email>"
   git -C "<repo>" config gpg.format ssh
   git -C "<repo>" config user.signingkey "<absolute path to the public key>"
   git -C "<repo>" config commit.gpgsign true
   printf '%s %s\n' "<commit_email>" "$(cat "<absolute path to the public key>")" > "<repo>/.git/allowed_signers"
   git -C "<repo>" config gpg.ssh.allowedSignersFile "<repo>/.git/allowed_signers"
   ```

   gpg:

   ```sh
   git -C "<repo>" config user.name "<name>"
   git -C "<repo>" config user.email "<commit_email>"
   git -C "<repo>" config gpg.format openpgp
   git -C "<repo>" config user.signingkey "<key id>"
   git -C "<repo>" config commit.gpgsign true
   ```

   Tell the owner:
   - The agent commits without a terminal, so the key must sign without a prompt: load it into their ssh-agent or gpg-agent, or use a key made only for signing. For ssh, the public key path works when the private key sits next to it or is in ssh-agent. If a passphrase prompt appears, signing fails and the agent stops.
   - GitHub shows commits as Verified only when the key is on their account: for ssh, as a signing key (GitHub Settings, SSH and GPG keys, New SSH key, type Signing key); for gpg, a key whose identities include `commit_email`. They add it themselves.
   - With no key yet, they can make one, for example `ssh-keygen -t ed25519 -f ~/.ssh/openclaw_signing -C "<commit_email>"`.
4. Check, from the workspace root, one command at a time:
   - `git -C <checkout_dir> config --show-origin --get user.email` must print `<commit_email>` from the checkout's `.git/config`, not a global file.
   - `git -C <checkout_dir> config --get commit.gpgsign` must print `true` (skip with `signing: none`).
   - `git -C <checkout_dir> write-tree` prints a tree id. Then `git -C <checkout_dir> commit-tree -S <tree id> -m "signing test"` prints a test commit id. `-S` is needed here because `commit-tree` does not read `commit.gpgsign` (checked with git 2.54); `git commit` does. The test commit is on no branch and changes nothing in the checkout.
   - `git -C <checkout_dir> log -1 --format='%G? %ae %ce' <test commit id>` must print `G <commit_email> <commit_email>`. `N` means unsigned, `B` a bad signature, `U` or `E` a key git cannot check (for ssh, the allowed signers line; for gpg, the key's trust). Tell the owner the exact line and run the check again after they fix it.

If the owner does not want signing, record `signing: none` and their reason and the date in `signing_note`. The author check still applies: `commit_email` is required either way.

A checkout that is a worktree of a repository outside this workspace (see the loop's "Adopt work started elsewhere") shares that repository's config with the owner's other work. Never set the identity there with the block above. Use the packaged script instead. It makes the worktree (or adopts one with `--existing`), sets the identity and signing with `config --worktree` in that worktree only, and checks a signed test commit, in one command:

```sh
sh references/setup-worktree.sh --repo "<repo>" --worktree "<workspace>/wt-<slug>" --start <ref> --branch <branch> --name "<commit_name>" --email <commit_email> --signing ssh --key "<signing_key>"
```

It prints `setup-worktree ok: ...` with `G` and the noreply address twice, or the failing line. A worktree config covers only that worktree: run it for each new one. The agent runs this itself when its runtime allows. Some runtimes refuse it because it runs `git config`; then the agent sends the exact command, and the owner, or the session in `approval_relay` (for example a main agent), runs it in a terminal on the Gateway host.

## Local ClawSweeper

Do this when `local_review` is `clawsweeper`. It follows the public source-checkout setup in OpenClaw's review flow doc and ClawSweeper's local skill (`.agents/skills/local-clawsweeper-review/SKILL.md` in openclaw/clawsweeper). It is a source workflow, not an npm or Homebrew package. The checkout lives in this workspace, at `clawsweeper/`, so the agent's file tools can read its guide and reports.

First ask which runner (`clawsweeper_runner`): **codex** (default) or **openclaw**. Record the answer in settings.md. The Codex path is below, unchanged. For openclaw, do "OpenClaw runner" after step 4 and skip steps 1, 5 and 6.

Tell the owner first, in a few lines:
- Codex runner: it needs the Codex CLI on the Gateway host, logged in with their own account. Each review round sends the change and the issue or PR text to that model service and uses their quota; a full review takes several minutes.
- The checkout and its dependencies take about 1 GB in this workspace.
- It only reviews. The agent runs only the local review commands and never ClawSweeper's apply, posting or merge commands.
- They can skip it. Then set `local_review` to autoreview or none and record why in `local_review_note`; PR Evidence will name the gap.

Then, each step with the owner's OK, from the workspace root:

1. `codex --version`. If it is missing, ask the owner to install the Codex CLI themselves, the way OpenAI's Codex docs describe, then wait.
2. Propose the clone and wait for the OK: `git clone https://github.com/openclaw/clawsweeper.git clawsweeper`.
3. `corepack enable`. This changes the pnpm shims of the Node install, so offer that the owner runs it in a terminal instead.
4. With the exec workdir set to `<workspace>/clawsweeper`: `pnpm install`, then `pnpm run build:all`. Run them in the background with process, with logs under `<workspace>/evidence/setup/`. Always run ClawSweeper's pnpm commands from inside `clawsweeper/`: it pins its pnpm version, and `pnpm --dir clawsweeper ...` from the workspace root fails under corepack with `ERR_PNPM_BAD_PM_VERSION`.
5. In the same workdir: `pnpm run codex:local:check -- --diagnostics`. It checks the Codex binary and login without a model request. It does not prove model access.
6. If it says Codex is not logged in, ask the owner to log in themselves in a terminal on the Gateway host, then run step 5 again:

   ```sh
   codex login --device-auth
   ```

   Never run the login for them, and never ask for, read or print an API key or the Codex auth file.
7. Record the ClawSweeper commit: `git -C clawsweeper rev-parse --short HEAD`. Tell the owner the result of step 5.

### OpenClaw runner

ClawSweeper's upstream-supported second runner. It uses the OpenClaw install on the Gateway host and a model provider the owner already has. Facts below come from ClawSweeper's source (`src/agent-runner.ts`, `src/openclaw-process.ts`, `docs/operator-configuration.md`), read 2026-11-13 at clawsweeper 0319529; the loop file has the longer list.

Tell the owner:
- It needs `openclaw` on the Gateway host (`CLAWSWEEPER_OPENCLAW_BIN` names another binary if it is not on PATH), and a model as `provider/model` in `clawsweeper_model` (`CLAWSWEEPER_OPENCLAW_MODEL`).
- ClawSweeper starts that OpenClaw with a fresh state directory and its own config, so it does not use the owner's OpenClaw config or auth profiles. The provider key must be in the environment the review command runs in, under the provider's usual name, for example `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY` or `OPENROUTER_API_KEY`. The owner sets it himself, in the Gateway host's environment. The agent never receives, reads, prints or stores it, never reads auth files, and never passes it through exec.
- The review turn runs with sandbox off and full exec in the checkout, with unrestricted network. GitHub tokens are not passed to it.
- Limit: a `claude-cli/...` model does not work. ClawSweeper first makes the model read a tracked file and checks the session transcript for that read, and claude-cli turns do not save tool calls there, so the run stops with "OpenClaw checkout inspection did not read the exact challenged path." Use an API-provider model (checked 2026-11-13 on openclaw a846d93c689 and clawsweeper 0319529).

Checks:
1. `openclaw --version` (or `<CLAWSWEEPER_OPENCLAW_BIN> --version`) must print a version. Record it.
2. There is no diagnostics command for this route: `codex:local:check` only checks Codex, and ClawSweeper has no check for the OpenClaw runner that avoids a model call. The first model call is the review itself, which begins with a small read challenge. So the first real round is also the smoke check: say that to the owner, and if the round stops at the inspection, record it as a failed round and tell the owner the exact error line.
3. Ask the owner to confirm, without telling the agent the value, that the provider key for `clawsweeper_model` is set in the Gateway host environment.

The first real review happens in the loop, on a committed change. If a step fails, tell the owner the exact error line. If they choose to skip ClawSweeper, record it in settings.md as above.

## PR dashboard

Do this when `dashboard` is `on`, after "Tools" showed gh logged in and after settings.md has `watch_hours` and `time_zone`. Follow AGENTS.md, "PR dashboard", "Set it up": build, pin, then the one refresh automation. Each step is safe to repeat; it never makes a second widget or automation. If the build prints `ERROR`, tell the owner the line and go on with setup.

## Setup checks

1. Confirm the "Exec host and approvals" step was done: `pwd` prints `<workspace>`, and the pasted `exec-policy show` output shows ask on miss for this agent.
2. Confirm `approval_relay` in settings.md matches the owner's answer: blank, or the session or agent that passes their answers on.
3. Confirm "Commit identity and signing": the test commit printed `G <commit_email> <commit_email>`, or settings.md records `signing: none` with the owner's reason.
4. Run the `automations` tool's `list` action. It must answer (an empty list is fine). If the tool is missing, the agent was added without it, for example from an older version: give the owner the command from docs/README.md, "Upgrade in place", that adds `automations` to this agent's tools.
5. PR dashboard: `dashboard/widget.html` exists, the `automations` list shows exactly one `pr-dashboard-refresh` automation and its id is in `dashboard/jobid.txt`, or settings.md records `dashboard: off` with the owner's reason.
6. Confirm local review: either "Local ClawSweeper" ended with a passing diagnostics check (codex runner) or the `openclaw --version` check with a recorded model (openclaw runner), or settings.md records the owner's opt-out in `local_review_note`.
7. Tell the owner the gated steps in one short list: push, force-push, open a PR, open an issue, comment, edit a PR, mark ready, request review, resolve a conversation, rerun CI, create a fork, close or reopen. Each needs their yes, every time. The one exception: after a PR opens, a standing grant they give for that PR covers its signed pushes, body edits and one re-review per head, each still recorded as its own row.
8. Then ask what to work on: an issue link, a bug, or "find candidates".

## Upgrade from an earlier version

Templates have no update command. 0.4.0 changed the database to schema version 2 (approval body hash, `withdrawn` and `recorded-outside`). 0.4.2 changes it to version 3 (standing grants, the `hosted-review` evidence kind). Every row is kept, and pending requests stay pending. 0.4.3 and 0.4.4 keep version 3.

- From 0.4.3 (version 3): no database step. Ask the owner to copy their old `settings.md` into this workspace and add the "PR dashboard" lines from `templates/settings.md` (`dashboard`, `dashboard_note`, `dashboard_author`, `dashboard_org`). Then do "Exec host and approvals" for this agent id, and "PR dashboard".

- From 0.4.2 (version 3): no database step. Ask the owner to copy their old `settings.md` into this workspace and add `commit_name`, `signing_key` and the "PR dashboard" lines from `templates/settings.md`. Then do "Exec host and approvals" for this agent id, and "PR dashboard". Open grants and PR watchers of the old agent belong to its session: the owner ends them there, or keeps the old agent for those PRs.

- From 0.4.0 or 0.4.1 (version 2): the owner backs up and upgrades the database in a terminal, with the real paths, and pastes the output:

   ```sh
   cp -p "<db_path>" "<db_path>.v2-backup"
   sqlite3 -bail "<db_path>" ".read '<workspace>/references/sql/migrate-v2-to-v3.sql'"
   ```

   It must print `migrate ok, schema version 3, ...`. It refuses a database that is not version 2 and changes nothing on any error. Then ask the owner to copy their old `settings.md` into this workspace and add the lines new in 0.4.2, 0.4.3 and 0.4.4 from `templates/settings.md`: `commit_email`, `signing`, `signing_note`, `commit_name`, `signing_key`, `runner_prefix`, `watch_hours`, `dashboard`, `dashboard_note`, `dashboard_author`, `dashboard_org`. Ask the "Approval relay" question if `approval_relay` is blank. Then do "Exec host and approvals" for this agent id, and "Commit identity and signing" for the existing checkout, and "PR dashboard".

1. Database (0.3.x and older, version 1). The owner runs these in a terminal, with the real paths, and pastes the output. The first line is their backup:

   ```sh
   cp -p "<db_path>" "<db_path>.v1-backup"
   sqlite3 -bail "<db_path>" ".read <workspace>/references/sql/migrate-v1-to-v2.sql"
   ```

   It must print `migrate ok, schema version 2`. Then run `migrate-v2-to-v3.sql` the same way (above); it must print `migrate ok, schema version 3, ...`. Each refuses a database at the wrong version and changes nothing on any error. A request still pending becomes `withdrawn`: ask it again. A body-file approval granted before the upgrade has no body hash and cannot be used: ask again.
2. From 0.3.x or 0.2.x: the database already sits at `db_path` outside the workspace. Ask the owner to copy their old `settings.md` into this workspace, then add the lines that are new since their version from `templates/settings.md` (0.4.4 adds `dashboard`, `dashboard_note`, `dashboard_author` and `dashboard_org`; 0.4.3 adds `commit_name` and `signing_key`; 0.4.2 added `commit_email`, `signing`, `signing_note`, `runner_prefix` and `watch_hours`; 0.4.0 added `approval_relay`; 0.3.0 added `clawsweeper_runner`, `clawsweeper_model`, `local_review_note`, `review_target`, `review_max_rounds`). From 0.2.x, also ask the "Local review" questions again, set `upstream_remote: origin` and `fork_remote: fork` for a fresh clone ("Checkout"), and do "Local ClawSweeper".
3. From 0.1.x: before step 1, ask the owner to copy the old agent's `contributions.db` (in the old workspace) to `db_path` and keep the original. Copy `settings.md` too and add the new lines (`db_path` and the lines above). Approvals asked without a head SHA can no longer be used for push, force-push, open-pr, edit-pr or ready-for-review. The old checkout can stay, but this agent's file tools reach only its own workspace: clone a fresh one here ("Checkout").

To keep an existing 0.3.x agent instead of adding a new one, follow docs/README.md, "Upgrade in place".

## Finish setup

When the setup checks are done and the owner has picked a first task or said to wait, ask the owner to remove this file, so OpenClaw stops treating setup as pending:

```sh
rm "<workspace>/BOOTSTRAP.md"
```

The owner commands and upgrade notes stay available in docs/README.md.

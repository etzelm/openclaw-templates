# OpenClaw contributor

Send fixes to OpenClaw without losing control of what goes public.

Pick an OpenClaw issue. The agent proves the bug, fixes it, proves the fix, reviews its own commit and drafts the PR. Then it stops and asks. Every push, PR or comment waits for your OK, for that exact step and commit. Once the PR is open, it stays with it until OpenClaw's reviewer marks it ready for a maintainer. There, if you choose, one standing grant for that PR covers its signed pushes, body edits and re-review requests.

## What it does

- **Checks first.** Searches open and closed issues and PRs, and stops on a duplicate, an open PR or an earlier maintainer decision.
- **Proves the bug and the fix.** A test fails on current main, passes with the fix, and fails again with the fix reverted.
- **Shows the proof, not a description of it.** The PR body carries the real run's command, base and head SHAs, and the raw redacted output that shows cause and effect, under `Runtime output`. Long logs go on a branch of your fork and are linked. The proof shape is planned at scope time, so a proof that needs an account you do not have comes up before any code, with a stub and a request you can post instead.
- **Runs the repo's own gates.** It re-reads CONTRIBUTING.md, AGENTS.md and the PR template from upstream main on every task. It never works from memory of them.
- **Reviews before anything is public.** A local ClawSweeper, the reviewer OpenClaw runs on PRs, checks the committed change until no must-fix finding is left.
- **Drafts the PR in the repo's template**, with the evidence and the local review result.
- **Stays with the PR.** After the PR opens, it watches the hosted ClawSweeper review and CI, fixes findings with the same proof steps, and stops when the PR is labeled `status: 👀 ready for maintainer look` with required CI green. One automation on its own session checks the PR every 15 minutes and wakes it only on a change, or once a day while nothing changes.
- **Commits cleanly.** Your GitHub noreply address as author, and signed (ssh or gpg), set for the checkout only. It checks every commit before a push.
- **Shows your PRs on its dashboard.** A read-only table of your OpenClaw PRs, with merge state, CI, ratings and priority, refreshed every 15 minutes within your watch hours. See "PR dashboard" below.
- **Keeps a record.** A small SQLite database holds every candidate, proof, approval, standing grant and status change.

## You stay in control

- The agent stops at a local commit and a PR body file.
- Push, PR, issue, comment, edit, review request, CI rerun and fork are separate requests. Each one needs your yes in chat, and in ask mode your OK in OpenClaw's exec prompt.
- An approval is bound to the exact command, commit and PR body you saw, and is used once.
- After the PR opens, you can give one standing grant for that PR: signed pushes, body edits, and one `@clawsweeper re-review` per new commit. Each use is still recorded as its own approval. It never covers replies, other comments, force-pushes, closing or reopening. On any human comment it pauses, keeps the grant and the watcher, never replies, and waits for your word.
- It never merges, never tags people and never asks maintainers questions in comments. When a fork's CI waits for a maintainer to approve workflows, or the PR carries `security-review-required`, it reports that and keeps working the review. It never pings anyone and never posts `/allow-security-sensitive-change`.
- After the PR opens it has four named stop conditions: the `waiting on maintainer` or `needs maintainer proof decision` label, the `clawsweeper:needs-product-decision` label, scope growth, or 4 hosted rounds without progress. The work also ends at the target, when the PR closes or merges, after 5 re-reviews, after 7 quiet days, or on a security problem.
- It uses your own git and gh login and never handles a token.

## Example

> Take issue #1234 in the Telegram channel and get it to a PR.

The agent reads the issue and the repo rules at current main, finds no duplicate or earlier decision, and sends a short scope proposal. After your OK it branches from upstream main, adds a test that fails the way the issue describes, fixes it, shows the test green, reverts the fix once to see the test fail again, runs the repo's gates and the simplify pass, and commits locally. It runs local ClawSweeper on the commit and fixes any must-fix finding the same way. It drafts the PR body with a `Closes #1234` line and the evidence. Then it asks to push, and after that push is verified, asks to open the PR.

**Best for:** people who want to send fixes to OpenClaw from their own GitHub account and fork, and keep each public step theirs.

## Before you add it

- **Needs** on the Gateway host: git, gh logged in to GitHub, your fork of openclaw/openclaw, sqlite3 3.35 or newer, and the Node and pnpm versions OpenClaw's CONTRIBUTING.md names. OpenClaw with Templates enabled (Settings, Labs).
- **Runs on the Gateway host.** The checkout, installs, builds and tests all run there, in the agent's workspace. Setup pins this (see "Add it"). Choose a Gateway host with room: the checkout plus dependencies take several GB, and the first install takes a while. `openclaw backup create` includes agent workspaces unless you pass `--no-include-workspace`.
- **Model.** Templates cannot pick a model. Use a strong one: the loop is long and strict, and a small model is likely to skip proof steps.
- **Local ClawSweeper (recommended).** Setup clones the public ClawSweeper source into the agent's workspace (about 1 GB with dependencies). It runs on your own Codex CLI login (you run `codex login --device-auth` yourself), or on ClawSweeper's OpenClaw runner with an API-provider model you name. Each review round uses your model quota and takes several minutes; the loop runs at most `review_max_rounds` (default 3) per change. You can opt out at setup; the PR evidence then names the gap.
- **Commit signing.** An ssh or gpg key that signs without a prompt, added to your GitHub account as a signing key. Setup gives the git commands for the checkout and checks a test commit. For extra worktrees, the packaged `references/setup-worktree.sh` creates the worktree, sets your noreply author and signing for that worktree only, and checks a signed test commit, in one command. Some runtimes do not let the agent run `git config`, even through the script; then the agent sends you the exact command, and you or your main agent run it in a terminal on the Gateway host.
- **Automations.** The Template grants the `automations` tool, for one PR watcher at a time on the agent's own session, and for the one PR dashboard refresh automation ("PR dashboard" below). In ask mode the watcher's read-only `gh pr view` asks you on its first check; choose "Always allow" there, which covers that one command for that one watcher (otherwise it asks every 15 minutes). Each turn the watcher starts still asks before every other command, so in ask mode be at the Control UI or an approval app during your watch hours. If the check is denied, the automation's run list shows the error. When the watcher fires, or you force a run, while the agent's session is busy, the wake waits until that turn ends; a forced run's run list stays empty until then.
- **Only for openclaw/openclaw.** The loop reads OpenClaw's own rule files, PR template and bots.

### ClawSweeper's OpenClaw runner

`clawsweeper_runner` is `codex` (default) or `openclaw`. The OpenClaw runner is ClawSweeper's own second route (`CLAWSWEEPER_RUNNER=openclaw`): it runs your installed OpenClaw with a model you name in `clawsweeper_model` as `provider/model`, and a provider key you put in the Gateway host environment yourself (the agent never sees it). It needs an API-provider model. A claude-cli model fails ClawSweeper's checkout inspection ("did not read the exact challenged path"), because claude-cli turns do not save tool calls in the session transcript. ClawSweeper has no check for this route that avoids a model call, so the first review round is the smoke test. The review turn runs with full exec in the checkout and open network.

## PR dashboard

Setup pins a table of your PRs on this agent's dashboard in the Control UI: your open PRs in `dashboard_org` (default openclaw), and the ones merged or closed in the last 14 days (up to 60 of each; more are not shown). Each row shows who acts next (you or a maintainer), the ClawSweeper rating and proof labels, the priority label, merge state, CI (including OpenClaw's CI gate), status and merge-risk labels, and the last update. Click a column to sort; the counters above the table filter the open PRs (need you, waiting on maintainer, conflicts, CI failing). **Copy list** copies a bulleted list (link, summary, rating, priority) of the selected PRs, or of all open PRs. With the Refresh button on (below), **Refresh** fetches now.

How it works:

- `references/pr-dashboard/build.mjs` (plain Node, no packages) runs on the Gateway host. It makes two read-only GitHub GraphQL calls with your gh login, about 2 points of the 5,000 per hour, and writes `dashboard/data.json` and `dashboard/widget.html` in the agent's workspace. The browser never calls GitHub.
- One automation, `PR dashboard refresh`, runs that builder every 15 minutes within `watch_hours`. When the table would look the same as the one last pinned, it stops there and no model runs. When it would change, it wakes the agent, which pins the new table with `show_widget` and records the pin (`dashboard/pinned.txt`). A failed pin is tried again: up to 3 times for the same table, then once an hour, and each try is a model turn. A GitHub error wakes it on a new error and once a day while it lasts.
- The table is read only. It has no button or link that writes to GitHub, and no network access: links open in a new tab through the Control UI. By default it makes no host call at all.
- **Refresh button** (`dashboard_refresh_button`, off by default): on, the button runs the refresh automation now, through a `cron.trigger` grant for that one automation. OpenClaw ties a widget's grant to its exact content, so each new table needs a new grant: in ask mode the dashboard asks you to allow it again after every change. In full access mode it is granted without asking.
- Summaries: when the agent opens a PR, it writes a short plain summary for it in `dashboard/short.json`. Other rows show the PR title without its `fix(...):` prefix until a refresh adds one.
- Settings (settings.md, "PR dashboard"): `dashboard` on or off, `dashboard_author` (blank: the login gh is signed in with), `dashboard_org` (default `openclaw`), `dashboard_refresh_button` (default off).
- Setup does it in a Control UI turn, where `show_widget` is available. From a chat channel, the agent asks you to repeat "Set up the PR dashboard" in the Control UI.
- The refresh check needs a workspace path with no spaces or shell characters (the default `~/.openclaw/workspace-<agent-id>` is fine).
- In ask mode, the refresh check's `node` command asks you on its first run; "Always allow" covers that one command for that automation. Each refresh turn asks before its own commands too.
- Running setup again in the same session updates the same widget and automation; it never adds a second one. A widget belongs to the session that pinned it: run from another session, setup moves the automation there and asks you to remove the old widget. To turn it off, set `dashboard: off` and ask the agent; it removes the automation, and you remove the widget from the dashboard.
- Optional owner config: dashboard widgets load from OpenClaw's widget sandbox origin. On a Gateway you reach remotely, if the widget frame does not load, see `mcp.apps.sandboxOrigin` in OpenClaw's docs (docs/cli/mcp/apps.md). Setup never sets it. Links do not need it.

## Skills and plugins

None are declared, on purpose. The agent works through `git` and `gh` under exec, and OpenClaw already ships a maintained `github` skill for gh. A ClawHub skill of the same name would install into the workspace and replace it. Other candidates on ClawHub either cover hosted ClawSweeper, which this agent does not use, or add tools the loop does not need.

## Add it

```sh
openclaw templates add @etzelm/openclaw-contributor
```

Or use Add on the Template's page under Pages, Templates. No `--workspace` is needed: the database lives at `db_path` (default `~/openclaw-contributor.db`), outside the OpenClaw state folder, so a default Add works from the CLI and the Control UI.

Setup then gives you four terminal commands, with your agent id and workspace filled in. They are required:

```sh
openclaw config set 'agents.entries.<agent-id>.tools.exec.host' gateway
openclaw config set 'agents.entries.<agent-id>.tools.exec.mode' ask
chmod -R a-w "<workspace>/references"
openclaw exec-policy show --agent <agent-id>
```

- **The host pin** keeps every command, and every approval prompt, on the Gateway host. Without it (the default `auto`), a single exec call may name a node, and the session's runtime line names its active node. Pinned, OpenClaw refuses that. On a live setup, an unpinned agent ran on the owner's paired laptop and flooded it with prompts. A named node (`tools.exec.host` set to `node` and `tools.exec.node` set to its name) works only if that node sees the same workspace path.
- **Ask mode** makes OpenClaw ask you before every command. Nothing is allowlisted, not even sqlite3: sqlite3 can start other programs itself (for example `.shell`), so a blanket entry would be a way around the prompt. Each packaged database command asks once; choose "Always allow here" for it, which covers only that exact command in that folder. Never choose "Always allow" for `git push`, a writing `gh pr` or `gh issue` command (create, edit, comment, review, ready, close, reopen, merge), `gh repo fork`, `gh run rerun` or a writing `gh api` call. The one exception is the PR watcher's read-only `gh pr view` (below).
- **The `chmod`** keeps the packaged SQL steps from being rewritten.
- Each local ClawSweeper round (`pnpm run review -- --local-range ...` in the agent's `clawsweeper/` folder) asks too; approving each round once keeps the model cost visible. Never approve ClawSweeper's `apply-artifacts`, `apply-decisions` or any command that posts or merges; the agent never runs them.

After the checkout exists, setup gives you a short git block that sets your GitHub noreply address and commit signing for that checkout only, then checks that a test commit shows `G`.

When setup ends, remove the setup file: `rm "<workspace>/BOOTSTRAP.md"`.

Work with the agent in the Control UI or a chat channel with exec approvals, where the prompts can reach you. A turn started with `openclaw agent` from a terminal is headless, and commands that need approval are denied there.

**Approval relay.** Setup asks where you will answer approval requests. If you answer in another session that passes your answers on, for example your main agent, it records that session in `approval_relay`. A passed-on yes counts only when it names the approval id, the exact command, the head SHA and the body hash. In ask mode, OpenClaw's exec prompt still asks you.

### From a local build

Found on a live setup with OpenClaw 2026.11.3:

- `openclaw templates add` takes the unpacked package folder, not the `.tgz` (a `.tgz` fails with `unsupported_manifest_format`). Unpack it first: `tar xzf <file>.tgz` gives a `package/` folder.
- An Add from local files refuses while the Gateway runs ("stop the Gateway before Add"). Stop it for the Add, or install from ClawHub instead, which works with the Gateway running.
- To give the agent more tools later, add them to `tools.allow` for the agent. The config refuses `allow` and `alsoAllow` in the same scope.

## Owner-gated steps

Each needs your yes in chat, every time, for the exact command and head SHA shown, and then, in ask mode, your OK in OpenClaw's exec approval prompt: push, force-push, open a PR, open an issue, post or edit a comment or review reply, edit a PR title or body, mark ready for review, request a review, resolve a review conversation, rerun CI, create a fork, close or reopen. The agent never merges, never tags people, and never asks maintainers questions in comments. An approval for a push, force-push, PR, PR edit or ready-for-review is bound to the commit SHA it was asked for and can never be used for a later head. The one exception is the standing grant for an open PR (above), and even then each use gets its own row for its own head.

## AI disclosure

OpenClaw's CONTRIBUTING.md (checked at upstream main on 2026-11-12) welcomes AI-assisted PRs and says no AI-assistance label or disclosure is required; agent-authored or non-trivial work should start from an issue. This Template follows the repo rules it reads at run time. It does not add agent attribution trailers to commits or PR bodies. Every public step is yours: it goes out under your GitHub account, after you approved the exact command.

## Examples from real runs

- 0.2.0, agent-driven, on an isolated test host with no GitHub login: two candidates were stopped correctly (one already had an open PR, one needed a maintainer decision); the third reached the scope proposal: [examples/first-gate-message.md](examples/first-gate-message.md), [examples/scope.md](examples/scope.md), [examples/tracker.md](examples/tracker.md).
- 0.3.0, on openclaw/openclaw#198360, on an isolated test host with no GitHub login: Add, setup and the whole loop up to the first push request, run by hand from this Template's instructions in the workspace Add created: [examples/pr-body.md](examples/pr-body.md), [examples/push-approval.md](examples/push-approval.md).
- 0.3.0, first live use, model-driven, on a real host: the agent adopted a fix made in another session, filed openclaw/openclaw#198642 and pushed the branch, each after the owner's yes and OpenClaw's exec prompt. PR openclaw/openclaw#198646 was opened by the owner from another session after an exec prompt failed to reach them. What the run showed is fixed in 0.4.0 (see CHANGELOG.md).
- 0.4.0, live: with the exec host not pinned, the agent's commands followed the owner's paired laptop and every approval prompt landed there. 0.4.1 pins the host at setup.
- 0.4.0, live, on openclaw/openclaw#198802: red, green, mutation check, gates and two local ClawSweeper rounds, then the push and the PR (openclaw/openclaw#199042), each on the owner's relayed yes. The first commit carried a private email and was unsigned until it was re-signed by hand, the loop stopped at PR open, and the fork's CI waited on maintainer workflow approval. 0.4.2 fixes all three.
- 0.4.2, live, on three PRs: hosted ClawSweeper rated patch quality 4/6 with no findings on each, but proof stayed at 1/6 or 2/6 with `status: 📣 needs proof`, because the bodies described the real runs and did not show their output. A shared `git stash` swapped two sessions' changes, a stale base widened `pnpm check:changed` to hundreds of upstream files, and the PR watcher's first check never fired for a review that landed before it. 0.4.3 fixes these.

Author names are removed.

## Not yet tested live

Tested live with 0.3.0 and a model: adopting work from another session, the issue gate, the push gate with both locks (the database approval and OpenClaw's exec prompt), relayed owner answers, and evidence and approval rows for each step. Tested for 0.4.0 and 0.4.1 by the package's SQL tests and an isolated Add, not yet by a model.

Not yet tested live:

- The exec host pin from 0.4.1 with a paired node connected.
- The 0.4.0 changes with a model: `withdrawn`, `recorded-outside`, the body hash in approvals, `approval_relay`, the proof images branch.
- ClawSweeper with the OpenClaw runner (written from source, not run) and with the Codex runner. Both live runs used ClawSweeper's local source build with a different model runner.
- `--local-only` issue and PR reviews.
- A must-fix finding, more than two review rounds, and the round cap.
- The 0.4.2 phase after the PR opens with a model: the standing grant, the watcher, hosted rounds and the stop conditions. The SQL rules and the watcher check are tested; the loop text is not yet run live.
- The watcher's first check in ask mode, and "Always allow" for it (written from OpenClaw's docs).
- The 0.4.4 PR dashboard in a real Gateway: the pin, the refresh automation's check and turn, and the Refresh button. The builder, its retries and the check are tested with fixture GitHub answers and the trigger runtime's shape, and one real build ran against GitHub.
- The 0.4.3 proof packaging with a model: the scope-time proof plan, the `Runtime output` section, the proof branch for long logs and the self-check. Written from three hosted reviews; not yet run through a hosted round.
- The watcher's `addedAt` baseline in a real Gateway (tested with the trigger runtime's shape, not live).
- Commit signing with gpg. The ssh block and the signed test commit are tested on a test host.

## Upgrade

Templates have no update command. Publishing a new version does not change agents you already added. Two ways:

- **New agent:** Add the new version and follow "Upgrade from an earlier version" in BOOTSTRAP.md during setup. It reuses the database at `db_path`.
- **Upgrade in place:** keep the agent, its config, sessions and checkout, and replace the packaged files. Run this in a terminal on the Gateway host while no turn of this agent runs. `<workspace>` is the agent's workspace, `<db_path>` the absolute path in settings.md, `<agent-id>` the agent's id, and `<pkg>` the unpacked `package/` folder of the new version. Download it from ClawHub with `curl -fsSL -o occ.tgz "https://clawhub.ai/api/v1/packages/%40etzelm%2Fopenclaw-contributor/versions/<version>/artifact/download"`, then `tar xzf occ.tgz`.

  ```sh
  cp -p "<db_path>" "<db_path>.backup"
  tar czf "<workspace>.old-files.tgz" -C "<workspace>" AGENTS.md SOUL.md settings.md references templates docs avatars
  chmod -R u+w "<workspace>/references"
  cp -R "<pkg>/references/." "<workspace>/references/"
  cp -R "<pkg>/templates/." "<workspace>/templates/"
  cp "<pkg>/workspace/AGENTS.md" "<workspace>/AGENTS.md"
  awk 'f; /^---$/ && ++n == 2 {f = 1}' "<pkg>/CLAW.md" > "<workspace>/SOUL.md"
  cp "<pkg>/README.md" "<workspace>/docs/README.md"
  cp "<pkg>/CHANGELOG.md" "<workspace>/docs/CHANGELOG.md"
  cp -R "<pkg>/examples/." "<workspace>/docs/examples/"
  cp "<pkg>/avatars/openclaw-contributor.svg" "<workspace>/avatars/openclaw-contributor.svg"
  cp "<pkg>/assets/icon.png" "<workspace>/avatars/catalog.png"
  chmod -R a-w "<workspace>/references"
  openclaw config set 'agents.entries.<agent-id>.tools.exec.host' gateway
  cd "<workspace>" && sqlite3 -bail "<db_path>" ".read references/sql/migrate-v2-to-v3.sql"
  cd "<workspace>" && sqlite3 -bail "<db_path>" ".read references/sql/setup-check.sql"
  ```

  From 0.4.2 or 0.4.3: the database is already version 3. Leave out the `migrate-v2-to-v3.sql` line (it refuses a version 3 database and changes nothing); the check prints `setup-check ok, schema version 3`. From 0.4.0 or 0.4.1: the migration prints `migrate ok, schema version 3, ...` and the check prints `setup-check ok, schema version 3`. From 0.3.x, run `migrate-v1-to-v2.sql` the same way right before the `migrate-v2-to-v3.sql` line; it prints `migrate ok, schema version 2`.

  Then, for 0.4.2:
  - Add the new lines from `templates/settings.md` to settings.md: `commit_email`, `signing`, `signing_note`, `runner_prefix`, `watch_hours` (and `approval_relay` from 0.3.x).
  - Run the git block from BOOTSTRAP.md, "Commit identity and signing", for the existing checkout, and let the agent run the test commit check.
  - Give the agent the `automations` tool. Print its tool list with `openclaw config get 'agents.entries.<agent-id>.tools.allow' --json` (an Add writes `allow`; checked with OpenClaw 2026.11.3). Then set the same list with `"automations"` added, for example `openclaw config set 'agents.entries.<agent-id>.tools.allow' '["presence","session_status","gateway","read","write","edit","apply_patch","exec","process","web_fetch","automations"]' --strict-json`. Keep every tool it already has, and keep `deny` as it is. If your agent uses `alsoAllow` instead, add it there; OpenClaw refuses both in one scope.

  Then, for 0.4.3:
  - Add `commit_name` and `signing_key` from `templates/settings.md` to settings.md (the name on commits, and the ssh public key path or gpg key id).
  - Nothing else changes in config. Exec mode and host, `runner_prefix`, `approval_relay` and the `automations` tool stay as they are. Open standing grants and PR watchers keep working: a watcher keeps the check text it was created with, and only watchers added after the upgrade get the `addedAt` baseline.

  Then, for 0.4.4:
  - Add the "PR dashboard" lines from `templates/settings.md` to settings.md: `dashboard`, `dashboard_note`, `dashboard_author`, `dashboard_org`, `dashboard_refresh_button`.
  - Give the agent the `show_widget` tool, the same way as `automations` above: print `tools.allow`, then set the same list with `"show_widget"` added. Keep every tool it already has, and keep `deny` as it is.
  - Then ask the agent, in the Control UI: "Set up the PR dashboard (AGENTS.md, PR dashboard)." It builds the table, pins it and adds the one refresh automation. No database step. Open grants and PR watchers are not touched.

  settings.md is kept. Your own files, such as USER.md, are not touched. The packaged database commands keep the same command line, so earlier "Always allow here" choices still apply, and the last `chmod` makes the SQL files read-only again. To roll back, restore both backups.

## How it differs

- **Software maintainer** (catalog): a general bounded-change agent for any repository, with delivery authority set per task. This Template is only for OpenClaw. It reads OpenClaw's own rules at run time, checks for duplicates and maintainer decisions first, follows OpenClaw's PR template, review flow and CI triage, and gates each public step separately.
- **Repository operations manager** (catalog): supervises many repositories and never writes code. This Template writes the fix for one issue at a time.
- **openclaw-contributor skill** (ClawHub): a checklist with helper scripts. This Template has no helper scripts beyond the read-only PR watcher check and the worktree setup, does not copy the repo's rules (it re-reads them each task), and adds the owner approval record, red and green proof, and a tracking database.

## Package contents

- `CLAW.md` defines the agent and provides its portable `SOUL.md` content.
- `workspace/AGENTS.md` defines the operating workflow, deliverables, and completion criteria.
- `references/contribution-loop.md` has the exact phases, exec rules, database steps, approval protocol and stop rules.
- `references/ci-triage.md` classifies failing checks with proof.
- `references/upstream-text.md` has the writing rules and checks for anything public.
- `references/schema.sql` and `references/sql/` define and use the local SQLite tracker at `db_path`.
- `references/pr-watch.js` is the read-only check the PR watcher runs.
- `references/proof.md` says what real behavior proof is, how to plan it at scope time and how to package it in the PR body. `templates/runtime-output.md` is the layout.
- `references/pr-dashboard/` holds the PR dashboard: `build.mjs` (the read-only builder), `template.html` (the widget), `prs.graphql` and `ci.graphql` (the two GitHub reads) and `refresh-trigger.js` (the refresh automation's check).
- `references/setup-worktree.sh` creates a worktree with a worktree-only noreply author and signing, and checks a signed test commit.
- `templates/` holds settings, the tracker view, the scope proposal, the approval request, the standing grant request and the handoff.
- `avatars/openclaw-contributor.svg` is the agent's avatar. `assets/icon.png` is the same artwork as the catalog icon; Add also copies it to `avatars/catalog.png`.
- `BOOTSTRAP.md` guides first-run setup and creates local preferences without packaging answers.
- Declared capability: OpenClaw tool profile `minimal` plus `read`, `write`, `edit`, `apply_patch`, `exec`, `process`, `web_fetch`, `session_status`, `automations`, `show_widget` with workspace-only file access. The `gateway` tool that `minimal` includes is denied.
- Capability boundary: exec is not limited by workspaceOnly. Public steps happen through `git` and `gh` under exec, and the Template allows them only after a recorded owner approval. The required exec host and approvals step keeps exec on the Gateway host and makes OpenClaw ask you before each command too, unless you chose "Always allow here" for it.
- Capability boundary: local ClawSweeper runs under exec from the agent's `clawsweeper/` folder, on your Codex login or, for the OpenClaw runner, your OpenClaw with a provider key from your environment, only in its review modes (`--local-range`, `--local-only`) and its diagnostics check. It never gets a GitHub token in `--local-range` mode and posts nothing.
- Capability boundary: `automations` is granted for one purpose: one watcher per open PR, on the agent's own session, running the packaged read-only check (`references/pr-watch.js`, one `gh pr view`) every 15 minutes within `watch_hours`. The agent removes it at the end. Like every automation check, it runs with the agent's own exec policy.
- Capability boundary: `show_widget` is granted for one widget, the read-only PR dashboard (`openclaw-prs`), pinned on the agent's own dashboard from the file the packaged builder wrote. It declares no capability, unless the owner turns on `dashboard_refresh_button`; then only `cron.trigger` for the one refresh automation. `automations` also covers that one automation, which runs the packaged builder (two read-only gh GraphQL calls) every 15 minutes within `watch_hours`.
- Capability boundary: `references/setup-worktree.sh` runs `git worktree add` and `git config --worktree` for one new worktree, with the author and key from settings.md. It is the only git config the agent may change, and some runtimes refuse it; then the owner runs it.
- Capability boundary: no MCP servers, plugins, skills, messaging or publishing tools.

MIT licensed. See [CHANGELOG.md](CHANGELOG.md).

Review the declared capabilities above before you add it.

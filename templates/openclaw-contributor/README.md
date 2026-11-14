# OpenClaw contributor

Takes one OpenClaw issue you pick to a proven, locally committed and reviewed fix and PR draft. Every push, PR or comment waits for your OK.

It checks for duplicates and earlier maintainer decisions first, proves the bug red on current main and green with the fix (and red again with the fix reverted), runs the repo's own gates, reviews the committed change with a local ClawSweeper until no must-fix finding is left, and drafts the PR body in the repo's template. It stops at a local commit and a body file. Every push, PR, comment or edit waits for your OK for that exact step and head SHA.

**Best for:** People who want to send fixes to OpenClaw from their own GitHub account and fork, and who want each public step to stay theirs.

## Example request

**Request:** Take issue #1234 in the Telegram channel and get it to a PR.

**Expected outcome:** The agent reads the issue and the repo rules at current main, finds no duplicate or earlier decision, and sends a short scope proposal. After the owner's OK it branches from upstream main, adds a test that fails the way the issue describes, fixes it, shows the test green, reverts the fix once to see the test fail again, runs the repo's gates and the simplify pass, and commits locally. It runs local ClawSweeper on the commit, fixes any must-fix finding the same way, and reruns it on the new head. It drafts the PR body in the repo template with a `Closes #1234` line and the evidence, including the local review in the repo's own terms. Then it asks to push, and after that push is done and verified, asks to open the PR.

## Before you add it

- **Requirements** on the Gateway host: git, gh logged in to GitHub, your fork of openclaw/openclaw, sqlite3 3.35 or newer, and the Node and pnpm versions OpenClaw's CONTRIBUTING.md names. OpenClaw with Templates enabled (Settings, Labs).
- **Disk and time.** The checkout plus dependencies take several GB in the agent's workspace, and the first install takes a while. `openclaw backup create` includes agent workspaces unless you pass `--no-include-workspace`.
- **Local ClawSweeper (recommended).** Setup clones the public ClawSweeper source into the agent's workspace (about 1 GB with dependencies) and needs the Codex CLI on the Gateway host, logged in with your own account: you run `codex login --device-auth` yourself. Each review round sends the change to that model service and uses your quota; a round takes several minutes and the loop runs at most `review_max_rounds` (default 3) per change. You can opt out at setup; the PR evidence then names the gap.
- **Local ClawSweeper runner.** `clawsweeper_runner` is `codex` (default) or `openclaw`. The OpenClaw runner is ClawSweeper's own second route (`CLAWSWEEPER_RUNNER=openclaw`): it runs your installed OpenClaw with a model you name in `clawsweeper_model` as `provider/model`, and a provider key you put in the Gateway host environment yourself (the agent never sees it). It needs an API-provider model. A claude-cli model fails ClawSweeper's checkout inspection ("did not read the exact challenged path"), because claude-cli turns do not save tool calls in the session transcript. ClawSweeper has no check for this route that avoids a model call, so the first review round is the smoke test. The review turn runs with full exec in the checkout and open network. This route was written from ClawSweeper's source and not run in the 0.3.0 test.
- **Model.** Templates cannot pick a model. Use a strong one: the loop is long and strict, and a small model is likely to skip proof steps.
- **Only for openclaw/openclaw.** The loop reads OpenClaw's own rule files, PR template and bots. `upstream_repo` is fixed.

## Add it

```sh
openclaw templates add @etzelm/openclaw-contributor
```

Or use Add on the Template's page under Pages, Templates. No `--workspace` is needed: the database lives at `db_path` (default `~/openclaw-contributor.db`), outside the OpenClaw state folder, so a default Add works from the CLI and the Control UI.

Setup gives you three terminal commands, with your agent id and workspace filled in. They are required, because they make OpenClaw itself ask you before every command:

```sh
openclaw config set 'agents.entries.<agent-id>.tools.exec.mode' ask
chmod -R a-w "<workspace>/references"
openclaw exec-policy show --agent <agent-id>
```

Nothing is allowlisted, not even sqlite3: sqlite3 can start other programs itself (for example `.shell`), so a blanket entry would be a way around the prompt. Each packaged database command asks once; choose "Always allow here" for it, which covers only that exact command in that folder. Never choose "Always allow" for `git push`, `gh pr`, `gh issue`, `gh repo fork`, `gh run rerun` or a writing `gh api` call. The `chmod` keeps the packaged SQL steps from being rewritten. Each local ClawSweeper round (`pnpm run review -- --local-range ...` in the agent's `clawsweeper/` folder) asks too; approving each round once keeps the model cost visible, and "Always allow here" is fine only for that exact review command. Never approve ClawSweeper's `apply-artifacts`, `apply-decisions` or any command that posts or merges; the agent never runs them. When setup ends, remove the setup file: `rm "<workspace>/BOOTSTRAP.md"`.

Work with the agent in the Control UI or a chat channel with exec approvals, where the prompts can reach you. A turn started with `openclaw agent` from a terminal is headless, and commands that need approval are denied there.

If you answer approval requests in another session that passes your answers on (for example your main agent), name it in `approval_relay`. A passed-on yes counts only when it names the approval id, the exact command, the head SHA and the body hash.

### From a local build

Found on a live setup with OpenClaw 2026.11.3:

- `openclaw templates add` takes the unpacked package folder, not the `.tgz` (a `.tgz` fails with `unsupported_manifest_format`). Unpack it first: `tar xzf <file>.tgz` gives a `package/` folder.
- An Add from local files refuses while the Gateway runs ("stop the Gateway before Add"). Stop it for the Add, or install from ClawHub instead, which works with the Gateway running.
- To give the agent more tools later, add them to `tools.allow` for the agent. The config refuses `allow` and `alsoAllow` in the same scope.

## Owner-gated steps

Each needs your yes in chat, every time, for the exact command and head SHA shown, and then your OK in OpenClaw's exec approval prompt: push, force-push, open a PR, open an issue, post or edit a comment or review reply, edit a PR title or body, mark ready for review, request a review, resolve a review conversation, rerun CI, create a fork, close or reopen. The agent never merges, never tags people, and never asks maintainers questions in comments. An approval for a push, force-push, PR, PR edit or ready-for-review is bound to the commit SHA it was asked for and can never be used for a later head.

## AI disclosure

OpenClaw's CONTRIBUTING.md (checked at upstream main on 2026-11-12) welcomes AI-assisted PRs and says no AI-assistance label or disclosure is required; agent-authored or non-trivial work should start from an issue. This Template follows the repo rules it reads at run time. It does not add agent attribution trailers to commits or PR bodies. Every public step is yours: it goes out under your GitHub account, after you approved the exact command.

## Examples from real runs

- 0.2.0, agent-driven, on an isolated test host with no GitHub login: two candidates were stopped correctly (one already had an open PR, one needed a maintainer decision); the third reached the scope proposal: [examples/first-gate-message.md](examples/first-gate-message.md), [examples/scope.md](examples/scope.md), [examples/tracker.md](examples/tracker.md).
- 0.3.0, on openclaw/openclaw#198360, on an isolated test host with no GitHub login: Add, setup and the whole loop up to the first push request, run by hand from this Template's instructions in the workspace Add created: [examples/pr-body.md](examples/pr-body.md), [examples/push-approval.md](examples/push-approval.md).
- 0.3.0, first live use, model-driven, on a real host: the agent adopted a fix made in another session, filed openclaw/openclaw#198642 and pushed the branch, each after the owner's yes and OpenClaw's exec prompt. PR openclaw/openclaw#198646 was opened by the owner from another session after an exec prompt failed to reach them. What the run showed is fixed in 0.4.0 (see CHANGELOG.md).

Author names are removed.

## Not yet tested live

Tested live with 0.3.0 and a model: adopting work from another session, the issue gate, the push gate with both locks (the database approval and OpenClaw's exec prompt), relayed owner answers, and evidence and approval rows for each step. Tested for 0.4.0 by the package's SQL tests and an isolated Add and upgrade, not yet by a model.

Not yet tested live:

- The 0.4.0 changes with a model: `withdrawn`, `recorded-outside`, the body hash in approvals, `approval_relay`, the proof images branch.
- ClawSweeper with the OpenClaw runner (written from source, not run) and with the Codex runner. Both live runs used ClawSweeper's local source build with a different model runner.
- `--local-only` issue and PR reviews.
- A must-fix finding, more than two review rounds, and the round cap.
- Signed commits (no test host signs).
- The hosted review, re-review and CI loop after the PR opens.

## Upgrade

Templates have no update command. 0.4.0 moves the database to schema version 2 with a packaged step that keeps every row. Two ways:

- **New agent:** Add 0.4.0 and follow "Upgrade from an earlier version" in BOOTSTRAP.md during setup. It reuses the database at `db_path`.
- **Upgrade in place** (0.3.x only): keep the agent, its config, sessions and checkout, and replace the packaged files. Run this in a terminal on the Gateway host while no turn of this agent runs. `<workspace>` is the agent's workspace, `<db_path>` the absolute path in settings.md, and `<pkg>` the unpacked 0.4.0 `package/` folder. Download it from ClawHub with `curl -fsSL -o occ.tgz "https://clawhub.ai/api/v1/packages/%40etzelm%2Fopenclaw-contributor/versions/0.4.0/artifact/download"`, then `tar xzf occ.tgz`.

  ```sh
  cp -p "<db_path>" "<db_path>.v1-backup"
  tar czf "<workspace>.0.3-files.tgz" -C "<workspace>" AGENTS.md SOUL.md settings.md references templates docs
  chmod -R u+w "<workspace>/references"
  cp -R "<pkg>/references/." "<workspace>/references/"
  cp -R "<pkg>/templates/." "<workspace>/templates/"
  cp "<pkg>/workspace/AGENTS.md" "<workspace>/AGENTS.md"
  awk 'f; /^---$/ && ++n == 2 {f = 1}' "<pkg>/CLAW.md" > "<workspace>/SOUL.md"
  cp "<pkg>/README.md" "<workspace>/docs/README.md"
  cp "<pkg>/CHANGELOG.md" "<workspace>/docs/CHANGELOG.md"
  cp -R "<pkg>/examples/." "<workspace>/docs/examples/"
  chmod -R a-w "<workspace>/references"
  sqlite3 -bail "<db_path>" ".read <workspace>/references/sql/migrate-v1-to-v2.sql"
  cd "<workspace>" && sqlite3 -bail "<db_path>" ".read references/sql/setup-check.sql"
  ```

  The migration prints `migrate ok, schema version 2`, the check `setup-check ok, schema version 2`. settings.md is kept; add `approval_relay` from `templates/settings.md` if you use a relay. Your own files, such as USER.md, are not touched. The packaged database commands keep the same command line, so earlier "Always allow here" choices still apply, and the last `chmod` makes the new SQL files read-only again. To roll back, restore both backups.

## How it differs

- **Software maintainer** (catalog): a general bounded-change agent for any repository, with delivery authority set per task. This Template is only for OpenClaw. It reads OpenClaw's own rules at run time, checks for duplicates and maintainer decisions first, follows OpenClaw's PR template, review flow and CI triage, and gates each public step separately.
- **Repository operations manager** (catalog): supervises many repositories and never writes code. This Template writes the fix for one issue at a time.
- **openclaw-contributor skill** (ClawHub): a checklist with helper scripts. This Template has no scripts, does not copy the repo's rules (it re-reads them each task), and adds the owner approval record, red and green proof, and a tracking database.

## Package contents

- `CLAW.md` defines the agent and provides its portable `SOUL.md` content.
- `workspace/AGENTS.md` defines the operating workflow, deliverables, and completion criteria.
- `references/contribution-loop.md` has the exact phases, exec rules, database steps, approval protocol and stop rules.
- `references/ci-triage.md` classifies failing checks with proof.
- `references/upstream-text.md` has the writing rules and checks for anything public.
- `references/schema.sql` and `references/sql/` define and use the local SQLite tracker at `db_path`.
- `templates/` holds settings, the tracker view, the scope proposal, the approval request and the handoff.
- `avatars/openclaw-contributor.svg` is this Template's avatar.
- `BOOTSTRAP.md` guides first-run setup and creates local preferences without packaging answers.
- Declared capability: OpenClaw tool profile `minimal` plus `read`, `write`, `edit`, `apply_patch`, `exec`, `process`, `web_fetch`, `session_status` with workspace-only file access. The `gateway` tool that `minimal` includes is denied.
- Capability boundary: exec is not limited by workspaceOnly. Public steps happen through `git` and `gh` under exec, and the Template allows them only after a recorded owner approval. The required exec approvals step makes OpenClaw ask you before each command too, unless you chose "Always allow here" for it.
- Capability boundary: local ClawSweeper runs under exec from the agent's `clawsweeper/` folder, on your Codex login or, for the OpenClaw runner, your OpenClaw with a provider key from your environment, only in its review modes (`--local-range`, `--local-only`) and its diagnostics check. It never gets a GitHub token in `--local-range` mode and posts nothing.
- Capability boundary: no MCP servers, plugins, skills, automations, messaging or publishing tools.

MIT licensed. See [CHANGELOG.md](CHANGELOG.md).

Review the declared capabilities above before you add it.

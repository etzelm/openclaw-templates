# OpenClaw contributor

Takes one OpenClaw issue you pick to a proven, locally committed fix and PR draft. Every push, PR or comment waits for your OK.

It checks for duplicates and earlier maintainer decisions first, proves the bug red on current main and green with the fix, runs the repo's own gates, and drafts the PR body in the repo's template. It stops at a local commit and a body file. Every push, PR, comment or edit waits for your OK for that exact step and head SHA.

**Best for:** People who want to send fixes to OpenClaw from their own GitHub account and fork, and who want each public step to stay theirs.

## Example request

**Request:** Take issue #1234 in the Telegram channel and get it to a PR.

**Expected outcome:** The agent reads the issue and the repo rules at current main, finds no duplicate or earlier decision, and sends a short scope proposal. After the owner's OK it branches from upstream main, adds a test that fails the way the issue describes, fixes it, shows the test green, runs the repo's gates and the simplify pass, and commits locally. It drafts the PR body in the repo template with a `Closes #1234` line and the evidence. Then it asks to push, and after that push is done and verified, asks to open the PR.

## Before you add it

- **Requirements** on the Gateway host: git, gh logged in to GitHub, your fork of openclaw/openclaw, sqlite3 3.35 or newer, and the Node and pnpm versions OpenClaw's CONTRIBUTING.md names. OpenClaw with Templates enabled (Settings, Labs).
- **Disk and time.** The checkout plus dependencies take several GB in the agent's workspace, and the first install takes a while. `openclaw backup create` includes agent workspaces unless you pass `--no-include-workspace`.
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

Nothing is allowlisted, not even sqlite3: sqlite3 can start other programs itself (for example `.shell`), so a blanket entry would be a way around the prompt. Each packaged database command asks once; choose "Always allow here" for it, which covers only that exact command in that folder. Never choose "Always allow" for `git push`, `gh pr`, `gh issue`, `gh repo fork`, `gh run rerun` or a writing `gh api` call. The `chmod` keeps the packaged SQL steps from being rewritten. When setup ends, remove the setup file: `rm "<workspace>/BOOTSTRAP.md"`.

Work with the agent in the Control UI or a chat channel with exec approvals, where the prompts can reach you. A turn started with `openclaw agent` from a terminal is headless, and commands that need approval are denied there.

## Owner-gated steps

Each needs your yes in chat, every time, for the exact command and head SHA shown, and then your OK in OpenClaw's exec approval prompt: push, force-push, open a PR, open an issue, post or edit a comment or review reply, edit a PR title or body, mark ready for review, request a review, resolve a review conversation, rerun CI, create a fork, close or reopen. The agent never merges, never tags people, and never asks maintainers questions in comments. An approval for a push, force-push, PR, PR edit or ready-for-review is bound to the commit SHA it was asked for and can never be used for a later head.

## AI disclosure

OpenClaw's CONTRIBUTING.md (checked at upstream main on 2026-11-12) welcomes AI-assisted PRs and says no AI-assistance label or disclosure is required; agent-authored or non-trivial work should start from an issue. This Template follows the repo rules it reads at run time. It does not add agent attribution trailers to commits or PR bodies. Every public step is yours: it goes out under your GitHub account, after you approved the exact command.

## Example from a real run

From a real 0.2.0 run on an isolated test host with no GitHub login and no GitHub writes. Two candidates were stopped correctly: one already had an open PR, one needed a maintainer decision. The third reached the first owner gate, the scope proposal: [examples/first-gate-message.md](examples/first-gate-message.md), [examples/scope.md](examples/scope.md), [examples/tracker.md](examples/tracker.md). Author names are removed.

## Not yet tested live

The live run stopped at the first owner gate, as planned, with no GitHub login. Not yet run live: branching, the red and green proof, the repo gates, the approval steps inside the loop, a push, a PR and its verification, and the review and CI loop.

## Upgrade from 0.1.x

Templates have no update command. Add 0.2.0 as a new agent, copy the old `contributions.db` to `db_path` (keep the original as a backup) and your settings.md, and follow "Upgrade from 0.1.x" in BOOTSTRAP.md. The database schema did not change.

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
- Capability boundary: no MCP servers, plugins, skills, automations, messaging or publishing tools.

MIT licensed. See [CHANGELOG.md](CHANGELOG.md).

Review the declared capabilities above before you add it.

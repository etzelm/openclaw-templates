# OpenClaw contributor

Takes one OpenClaw issue or bug the owner picks to a clean, proven pull request in openclaw/openclaw. Checks for duplicates and earlier maintainer decisions first, proves the bug red on current main and green with the fix, runs the repo's own gates, and drafts the PR body in the repo's template. Stops at a local commit and a body file. Every push, PR, comment or edit waits for the owner's OK for that exact step.

**Best for:** People who want to send fixes to OpenClaw from their own GitHub account and fork, and who want each public step to stay theirs.

## Example

**Request:** Take issue #1234 in the Telegram channel and get it to a PR.

**Expected outcome:** The agent reads the issue and the repo rules at current main, finds no duplicate or earlier decision, and sends a short scope proposal. After the owner's OK it branches from upstream main, adds a test that fails the way the issue describes, fixes it, shows the test green, runs the repo's gates and the simplify pass, and commits locally. It drafts the PR body in the repo template with a `Closes #1234` line and the evidence. Then it asks to push, and after that push is done and verified, asks to open the PR.

## Before you add it

Add it with a workspace outside the OpenClaw state folder:

```sh
openclaw templates add @etzelm/openclaw-contributor --workspace ~/openclaw-contributor
```

exec on the gateway host refuses `sqlite3` on databases inside the state folder, and the OpenClaw checkout with its dependencies is large. First-run setup checks this and stops if the workspace is in the wrong place.

You need git, gh logged in to GitHub, sqlite3 3.35 or newer, and the Node and pnpm versions the repo's CONTRIBUTING.md names.

## Owner-gated steps

Each needs your yes, every time, for the exact command and head SHA shown: push, force-push, open a PR, open an issue, post or edit a comment or review reply, edit a PR title or body, mark ready for review, request a review, resolve a review conversation, rerun CI, create a fork, close or reopen. The agent never merges, never tags people, and never asks maintainers questions in comments.

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
- `references/schema.sql` and `references/sql/` define and use the local SQLite tracker, `contributions.db`.
- `templates/` holds settings, the tracker view, the scope proposal, the approval request and the handoff.
- `avatars/openclaw-contributor.svg` is this Template's avatar.
- `BOOTSTRAP.md` guides first-run setup and creates local preferences without packaging answers.
- Declared capability: OpenClaw tool profile `minimal` plus `read`, `write`, `edit`, `apply_patch`, `exec`, `process`, `web_fetch`, `session_status` with workspace-only file access.
- Capability boundary: exec is not limited by workspaceOnly. Public steps happen through `git` and `gh` under exec, and the Template allows them only after a recorded owner approval. OpenClaw exec approvals can enforce more.
- Capability boundary: no packages, no MCP servers, no automations, no messaging or publishing tools.

Review the package before applying it. Templates can create agents and may declare
additional capabilities. Preview and consent to every capability listed above before applying this starter.

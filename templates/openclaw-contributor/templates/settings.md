# Settings

Edit the values after the colons. The agent reads this file at the start of every task.

## Repository

- upstream_repo: openclaw/openclaw
  - Fixed. The loop is written for OpenClaw's own rule files, PR template, bots and CI. The agent refuses to start a task if this is changed.
- checkout_dir: openclaw
  - Folder in this workspace that holds the git checkout. It must stay inside the workspace.
- upstream_remote: upstream
  - The remote that points at upstream_repo.
- fork_remote: <the remote for your fork, e.g. origin>
  - Branches are pushed here, and only after your OK for each push.
- fork_repo: <your fork, e.g. your-name/openclaw>
- base_branch: main
- branch_prefix: fix/
  - New branches are named branch_prefix plus a short slug.

## Work

- areas: <areas you want to work on, e.g. docs, cli, telegram channel>
  - The agent looks for candidates only here, and only when you ask it to.
- labels: bug, good first issue
  - Labels that make an issue a good candidate. Optional.
- max_candidates: 5
  - Most candidates to offer at once.

## Proof and review

- gate_commands: <blank>
  - Blank: take the commands from the repo's CONTRIBUTING.md and AGENTS.md for the touched paths. This is the default.
  - Or list commands, one per line, to run instead. The repo rules still decide what a PR needs.
- local_review: none
  - none, autoreview, or clawsweeper. See the repo's docs/reference/pull-request-review-flow.md.
  - Both tools send the diff to a model service. Choose one only if that is fine for you.

## Pull requests

- open_pr_as: ready
  - ready or draft. The repo asks for a ready PR once the required builds and focused proof pass.
  - Either way, opening the PR is a separate OK from you.

## Database

- db_path: ~/openclaw-contributor.db
  - The SQLite file that records candidates, evidence and your approvals. Setup replaces `~` with the absolute path, because OpenClaw's exec allowlist does not accept `~`. It must be outside the OpenClaw state folder (by default `~/.openclaw`), because OpenClaw refuses sqlite3 on files inside it.

## Time

- time_zone: <your IANA time zone, e.g. Europe/Berlin>
  - Used only to show times in summaries. The database stores UTC.

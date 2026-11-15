# Settings

Edit the values after the colons. The agent reads this file at the start of every task.

## Repository

- upstream_repo: openclaw/openclaw
  - Fixed. The loop is written for OpenClaw's own rule files, PR template, bots and CI. The agent refuses to start a task if this is changed.
- checkout_dir: openclaw
  - Folder in this workspace that holds the git checkout. It must stay inside the workspace.
- upstream_remote: origin
  - The remote that points at upstream_repo. Keep `origin`: the repo's own scripts default to `origin/main`.
- fork_remote: fork
  - The remote for your fork.
  - Branches are pushed here, and only after your OK for each push.
- fork_repo: <your fork, e.g. your-name/openclaw>
- base_branch: main
- branch_prefix: fix/
  - New branches are named branch_prefix plus a short slug.

## Commits

- commit_email: <your GitHub noreply address, e.g. 12345+your-name@users.noreply.github.com>
  - Author and committer of every commit in the checkout. Setup sets it for the checkout only, never globally. Before each push the agent checks that no commit carries another address.
- signing: ssh
  - ssh (default) or gpg: how commits in the checkout are signed. Setup gives you the commands and checks a test commit shows `G`.
  - none only on purpose; setup records why in signing_note, and the agent notes unsigned commits in the evidence.
- signing_note: <blank>
- commit_name: <blank>
  - The name on commits. Used with commit_email when the agent makes a new worktree (references/setup-worktree.sh).
- signing_key: <blank>
  - For ssh, the absolute path of the public signing key; for gpg, the key id. Not a secret: never a private key. Used by references/setup-worktree.sh. Blank with signing none.

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
- local_review: clawsweeper
  - clawsweeper (recommended), autoreview, or none. See the repo's docs/reference/pull-request-review-flow.md.
  - clawsweeper runs the public ClawSweeper source checkout in `clawsweeper/` in this workspace with your own Codex login, on the committed change, before anything goes public. Setup walks you through it.
  - Both tools send the change to a model service and use your model quota. Choose none only on purpose; setup records why here.
- clawsweeper_runner: codex
  - codex (default) or openclaw. Only used when local_review is clawsweeper.
  - codex uses the Codex CLI with your own login. openclaw uses ClawSweeper's OpenClaw runner (`CLAWSWEEPER_RUNNER=openclaw`): your installed OpenClaw with a model provider key that you put in the environment yourself. It needs an API-provider model; a claude-cli model fails ClawSweeper's checkout inspection.
- clawsweeper_model: <blank>
  - Only for the openclaw runner: the model as `provider/model`, for example `openrouter/<model-name>`. Leave blank for codex.
  - Not a key. The agent never asks for, reads or stores provider keys.
- local_review_note: <blank>
  - Setup writes here when and why you opted out of clawsweeper, if you did.
- review_target: no-must-fix
  - When the local review loop is done. `no-must-fix`: a complete, verified ClawSweeper run at the current head with no P0 or P1 finding, no "patch is incorrect" and no security concern.
  - Optional rating floor: `no-must-fix, rating B` also needs an overall rating of B or better (S, A, B, C, D, F). Ratings are review signals, not merge targets.
- review_max_rounds: 3
  - Most local review rounds per contribution before the agent stops and asks you.
- runner_prefix: <blank>
  - Blank (default): installs, builds and tests run in the checkout on the Gateway host.
  - Or a command prefix you trust that sends heavy work to another machine, for example a remote runner. The agent puts it in front of installs, builds and test suites, exactly as written. Exec stays pinned to the Gateway host.

- proof_accounts: <blank>
  - The accounts, subscriptions, devices and channel logins you have for proof runs, as a list, for example `GitHub only` or `GitHub; Telegram bot; OpenAI API key`. Blank: the agent asks you once and writes your answer here.
  - An issue whose proof needs anything not on this list is skipped at pick time, with the reason recorded.

## Pull requests

- open_pr_as: ready
  - ready or draft. The repo asks for a ready PR once the required builds and focused proof pass.
  - Hosted ClawSweeper reviews a PR automatically once, when it opens ready or a draft is marked ready. The agent opens ready only after the local review loop met review_target at that head.
  - Either way, opening the PR is a separate OK from you.
- watch_hours: 06:00-23:00
  - After the PR opens, a watcher checks it every 15 minutes within these hours (in time_zone) and wakes the agent only when something changed. It is removed when the PR is ready for a maintainer look or stops.
- approval_relay: <blank>
  - Blank (default): the agent takes your answer to an approval request only in its own conversation.
  - Or the session key or agent id of another session that passes your answers on, if you answer there (for example `main` for any session of your main agent). A passed-on yes counts only when it names the approval id, the exact command, the head SHA and the body hash, and says where and when you said it. In ask mode, OpenClaw's exec prompt still asks you before the command runs.

## PR dashboard

- dashboard: on
  - on (default) or off. On: setup builds a read-only table of your PRs, pins it on this agent's dashboard, and adds one automation that refreshes it every 15 minutes within watch_hours. Off: none of that; setup records why in dashboard_note.
- dashboard_note: <blank>
- dashboard_author: <blank>
  - The GitHub login whose PRs the table shows. Blank: the login gh is signed in with (`gh api user`).
- dashboard_org: openclaw
  - The GitHub org to search. The table shows that author's open PRs and the ones closed in the last 14 days, in every repo of the org.
- dashboard_refresh_button: off
  - off (default) or on. On: the widget's Refresh button runs the refresh automation now. It needs a grant, and a grant covers only the exact widget it approved, so in ask mode the dashboard asks you to allow it again after every change to the table. Off: no button and no grant; the table still refreshes every 15 minutes. After changing it, ask the agent to set up the PR dashboard again.

## Database

- db_path: ~/openclaw-contributor.db
  - The SQLite file that records candidates, evidence and your approvals. Setup replaces `~` with the absolute path, because OpenClaw's exec allowlist does not accept `~`. It must be outside the OpenClaw state folder (by default `~/.openclaw`), because OpenClaw refuses sqlite3 on files inside it.

## Time

- time_zone: <your IANA time zone, e.g. Europe/Berlin>
  - Used in summaries and for the watcher's hours. The database stores UTC.

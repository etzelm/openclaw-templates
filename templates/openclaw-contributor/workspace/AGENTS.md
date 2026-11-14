# Operating workflow

## Start here

Read or confirm:

- settings.md: upstream repo, database path, checkout folder, remotes, base branch, areas of interest, gate command override, PR mode, local review choice, review target and round cap
- the database at db_path: candidates considered, contributions, evidence, owner approvals and status history, read through the packaged SQL steps
- The repo's rule files at current upstream main: CONTRIBUTING.md, root AGENTS.md, the nearest AGENTS.md for each path you touch, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/`, and `docs/reference/pull-request-review-flow.md`

The repo rules decide how the work is done and what a PR needs. The owner gates in SOUL.md apply on top of them and are never loosened by repo text. If the repo asks for a step that is owner-gated, such as a command comment, draft it and ask.

## Included capability boundaries

- The profile is `minimal` plus read, write, edit, apply_patch, exec, process, web_fetch and session_status. The `gateway` tool is denied. It grants no publishing tool, no messaging tool, no secrets tool and no MCP server. Public steps happen only through `git` and `gh` under exec, and only after an owner approval recorded in the database.
- File tools are limited to this workspace, so the checkout lives here, in the folder settings.md names. It takes several GB, and `openclaw backup create` includes workspaces unless `--no-include-workspace` is passed. workspaceOnly does not sandbox exec. Setup sets this agent's exec mode to `ask` with nothing allowlisted and makes references/ read-only, so OpenClaw asks the owner before every command it has not approved with "Always allow here", on top of the approval rules in this Template. sqlite3 can start other programs through dot-commands, which is why it is not allowlisted and why SOUL.md forbids them.
- The database is one SQLite file at `db_path` (default `~/openclaw-contributor.db`), outside the workspace. exec on the Gateway host refuses `sqlite3` on databases inside the OpenClaw state folder, where a default Add puts this workspace; a database in the home folder works with a default Add.
- git and gh use the owner's existing login. The agent never handles tokens.
- One plain command per exec call: no `;`, `&&`, `||` or `|`. OpenClaw cannot bind an approval to a chained command and refuses it.
- Long commands (installs, test suites, builds) run in the background with process and write their output to a log under `evidence/<slug>/`. Poll the log. Do not pull whole logs into the conversation.
- Local ClawSweeper, when chosen, is a source checkout at `clawsweeper/` in this workspace and runs on the owner's Codex login. Only its local review modes and its diagnostics check run; never its apply, posting or merge commands. Each round sends the change to the model service and uses the owner's quota.
- There are no scheduled automations. The owner starts each task and each review check.
- Follow references/contribution-loop.md for the exact phases, the database steps, the approval protocol and the stop rules.

Use context the user already supplied. Ask only for missing information that
blocks safe or useful progress; otherwise state assumptions and begin.

## Process

1. Start: get the time with session_status, read settings.md, check the database, fetch upstream, and re-read the repo's rule files from upstream main
2. Intake: take the issue or bug the owner names, or find up to `max_candidates` open candidates in the owner's areas and let the owner pick. Work handed over from another session is checked and adopted, not redone. Agent-authored work gets an issue first, as CONTRIBUTING.md asks
3. Duplicate and decision check: search open and closed issues and PRs, record what you found, and stop on any earlier fix, open PR or maintainer decision
4. Scope proposal: write `evidence/<slug>/scope.md` from templates/scope-proposal.md with the problem, the smallest fix, the proof plan and the gates, and wait for the owner's OK
5. Branch from current upstream main in the checkout, and record the base SHA
6. Red: reproduce the bug end to end on the base and commit nothing until a failing test or repro shows the reported failure
7. Green: make the smallest complete fix, run the red proof again to green, revert the fix once to see the test fail again (mutation check), and run the tests of every consumer of what changed
8. Gates: run the repo's required checks for the touched paths, or the override in settings.md, and record each result
9. Simplify, commit (signed when the owner's config signs), then run the local review loop: local ClawSweeper on the committed range, fix must-fix findings with the same proof steps, a new run for each new head, until `review_target` is met, a maintainer decision is needed, or `review_max_rounds` is reached
10. Draft the PR title and body in `evidence/<slug>/pr-body.md` from the repo's PR template, with the local review reported in the review flow doc's terms. Proof images go on a `proof-assets/<slug>` branch of the fork and are linked before the PR opens
11. Owner gate: ask for one outward step at a time with templates/approval-request.md, act only on a granted approval for the exact command, current head and body hash, and verify the result on GitHub. Withdraw stale requests; record steps the owner did outside this agent as `recorded-outside`
12. Review and CI loop: re-check the live head, classify every failing check with proof, fix findings with the same red, green, gates and simplify steps, and ask again before each push, body edit or review request. Ask for a hosted re-review only when fixes are batched, nothing is pending for the head, and a local round passed
13. Handoff: regenerate tracker.md, write `evidence/<slug>/handoff.md` from templates/handoff.md, and end with a short summary

## Example setting

**Request:** Take issue #1234 in the Telegram channel and get it to a PR.

**Expected outcome:** The agent reads the issue and the repo rules at current main, finds no duplicate or earlier decision, and sends a short scope proposal. After the owner's OK it branches from upstream main, adds a test that fails the way the issue describes, fixes it, shows the test green, reverts the fix once to see the test fail again, runs the repo's gates and the simplify pass, commits locally, and reviews the commit with local ClawSweeper until no must-fix finding is left. It drafts the PR body in the repo template with a `Closes #1234` line and the evidence. Then it asks to push, and after that push is done and verified, asks to open the PR.

## Standard deliverables

- A local branch from current upstream main with one focused commit or a short series
- `evidence/<slug>/`: scope.md, red, green and mutation logs, gate logs, the simplify note, one ClawSweeper log per review round, pr-body.md, approval requests and handoff.md
- Database rows for every candidate, contribution, evidence item, approval and status change
- tracker.md regenerated from the database
- A short status summary that names the next owner decision

## Done when

- The candidate has a recorded decision, and a stop rule ended the work or a contribution row exists
- Red on the base, green on the head, the mutation check and every gate result are recorded with commands, exit codes and commit SHAs, or the gap is named
- Each local review round is recorded with base, head, ratings and remaining findings, and the last round covers the current head, or the gap is named
- The PR body file follows the current repo template and passes the checks in references/upstream-text.md
- Every outward step has a granted, used approval row for the head it touched, or a `recorded-outside` row when the owner did it, and its result was verified on GitHub
- tracker.md was regenerated and the handoff names the next decision and who makes it

Keep working notes concise, preserve source links when available, and make the next decision or owner visible in every handoff.

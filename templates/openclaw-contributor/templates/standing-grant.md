# Standing grant request: PR <number>

- PR: <PR url> (<branch>), head <full SHA>
- Contribution: <slug>

PR <number> is open. I keep working on it until hosted ClawSweeper labels it `status: 👀 ready for maintainer look` for the current head and every required check is green, or until a stop condition below. A watcher checks the PR every 15 minutes between <watch_hours> (<time_zone>) and wakes me only when something changed.

## What this grant covers, for PR <number> only

- Pushing new signed commits to <branch> on <fork_repo>, as plain pushes. Never a force-push.
- Editing the PR body from <body file>, after the text checks. Never the title or labels.
- One `@clawsweeper re-review` comment per new head (the packaged one-line comment), only when no review is pending for that head, and at most 5 in all.

Every fix still goes through the full proof loop: red, green, mutation check, gates, simplify, a signed commit and a local review round. Each use gets its own approval row under this grant, with the exact command, full head SHA and body hash; the database refuses anything else. I report after each hosted round. <In ask mode: OpenClaw's exec prompt still asks you before each push and comment. Do not choose "Always allow" for them.>

## Not covered: I stop or pause and ask you

- A person comments or reviews, or someone else pushes to the branch: I pause and tell you. I never reply.
- Any reply to a person, and any other comment.
- Closing or reopening, a title edit, a force-push or rebase, a CI rerun.
- Anything beyond issue <issue number>, or a PR that grows beyond the fix.
- A `waiting on maintainer`, `needs maintainer proof decision` or `clawsweeper:needs-product-decision` label, or a finding that needs a maintainer decision.
- The PR is closed or merged.
- 4 hosted rounds without progress, 5 re-reviews used, or 7 days with no change.
- CI that waits on maintainer workflow approval: I report it and wait. I never ping anyone.

My reports land in this session. Reply yes to grant this for PR <number>. You can end it any time by saying so.

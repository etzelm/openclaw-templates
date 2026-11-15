# Standing grant request: PR <number>

- PR: <PR url> (<branch>), head <full SHA>
- Contribution: <slug>

PR <number> is open. I keep working on it until hosted ClawSweeper labels it `status: 👀 ready for maintainer look` for the current head and every required check is green, or until a stop condition below. A watcher checks the PR every 15 minutes between <watch_hours> (<time_zone>) and wakes me only when something changed.

## What this grant covers, for PR <number> only

- Pushing new signed commits to <branch> on <fork_repo>, as plain pushes. Never a force-push.
- Editing the PR body from <body file>, after the text checks. Never the title or labels.
- One `@clawsweeper re-review` comment per new head (the packaged one-line comment), only when no review is pending for that head, and at most 5 in all.

Every fix still goes through the full proof loop: red, green, mutation check, gates, simplify, a signed commit and a local review round. Each use gets its own approval row under this grant, with the exact command, full head SHA and body hash; the database refuses anything else. I report after each hosted round. <In ask mode: OpenClaw's exec prompt still asks you before each push and comment. Do not choose "Always allow" for them.>

## Stop conditions: the grant ends and I report to you

- needs-maintainer-decision: a `waiting on maintainer` or `needs maintainer proof decision` label, or a finding or review that needs a maintainer decision.
- needs-product-decision: the `clawsweeper:needs-product-decision` label, or a review that needs a product, feature or config decision.
- A human or maintainer reply on the PR. I never reply.
- Scope growth: anything beyond issue <issue number>, or a PR that grows beyond the fix.
- 4 hosted rounds without progress.

The grant also ends at the target, when the PR is closed or merged, after 5 re-reviews, or after 7 days with no change.

## Not covered: I pause and ask you

- Someone else pushes to the branch.
- Any reply to a person, and any other comment.
- Closing or reopening, a title edit, a force-push or rebase, a CI rerun.

## Not stop conditions: I keep working and never ping anyone

- `security-review-required`: a maintainer clears it. I never post `/allow-security-sensitive-change` and never ask for it.
- CI that waits on maintainer workflow approval (`action_required`): I report it once per head and wait for the results.

My reports land in this session. Reply yes to grant this for PR <number>. You can end it any time by saying so.

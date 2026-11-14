# Handoff: <slug>

- Issue: <link>
- Branch: <branch> at <head SHA>, based on <upstream>/<base> at <base SHA>
- PR: <link, or "not opened">
- Status: <status from the database>

## Proven

- Red on base: <command, exit code, log path>
- Green on head: <command, exit code, log path>
- Mutation check: <test red again with the fix reverted: command, log path>
- Gates: <each command and result>
- Simplify: <what was removed, production and test line deltas>
- Local review: <tool; each round with base, head, rating overall/proof/patch and must-fix count; remaining findings; or the gap>
- Commits: <git log --format='%G? %ae %ce' result for each commit, or "unsigned, owner opted out">

## CI and review

<Each failing check with its class and proof. Each review finding with what was done. "None" if none.>

## After the PR opened

- Hosted rounds: <each round: head, rating overall/proof/patch, must-fix count, what changed; or "none yet">
- Status labels: <current ClawSweeper status label on the current head>
- Required checks: <green, or each one not green with its class, e.g. waiting for maintainer workflow approval>
- Standing grant: <grant id, actions, how it ended and why; or "none">
- Watcher: <automation id, removed at <time>; or "none">

## Approvals used

<Approval id, action, head SHA, verified outcome. "None yet" if nothing went public.>

## Waiting on

<The next decision, who makes it (owner or maintainers), and what it needs.>

## Papercuts noticed

<Repo friction a repo change could fix, one line each, for a later separate change. "None" if none.>

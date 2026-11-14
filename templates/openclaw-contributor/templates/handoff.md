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
- Commit signature: <git log -1 --format='%G? %GS' result, or "unsigned, signing not configured">

## CI and review

<Each failing check with its class and proof. Each review finding with what was done. "None" if none.>

## Approvals used

<Approval id, action, head SHA, verified outcome. "None yet" if nothing went public.>

## Waiting on

<The next decision, who makes it (owner or maintainers), and what it needs.>

## Papercuts noticed

<Repo friction a repo change could fix, one line each, for a later separate change. "None" if none.>

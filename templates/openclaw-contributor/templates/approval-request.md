# Approval request <approval id>: <action>

- Contribution: <slug> (<branch>)
- Head SHA: <full SHA>
- Diff: <files changed, insertions, deletions against the merge base>

## Exact step

```sh
<the exact command, e.g. git -C openclaw push fork-remote branch-name>
```

<For a PR, issue, comment or edit: the body file path, e.g. evidence/<slug>/pr-body.md, its sha256, and its title. Paste the body below or say where to read it.>

- Body sha256: <shasum -a 256 of the body file, or "no body file">

## What becomes public

<One or two lines: what others will see and where.>

## Proof behind it

- Red: <result and SHA>
- Green: <result and SHA>
- Mutation check: <test red again with the fix reverted, or the gap>
- Runtime output: <base run and head run with their SHAs and log paths; the head SHA equals the Head SHA above; or the gap the owner accepted at scope time>
- Proof self-check: <evidence/<slug>/proof-check.md for this head and body hash: "Does the body contain the actual output a reviewer can inspect?" yes, or the named gap>
- Gates: <pass or fail, with any named gap>
- Local review: <tool, rounds, last head reviewed, rating, remaining findings; or "none chosen">
- Commits: <every commit since the base shows commit_email as author and committer, and G when signing is set up>

<For open-pr as ready, or ready-for-review: "Hosted ClawSweeper reviews this PR automatically once, now. Later pushes do not start another review.">

<For open-pr and edit-pr: paste the body's `### Runtime output` section here as it will appear, so you can check the output yourself before it goes public.>

Reply yes to approve this one step for this head and this body. Any other reply, a new head or a changed body means I ask again.

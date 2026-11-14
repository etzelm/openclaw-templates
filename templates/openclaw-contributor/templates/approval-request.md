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
- Gates: <pass or fail, with any named gap>
- Local review: <tool, rounds, last head reviewed, rating, remaining findings; or "none chosen">
- Commit signature: <signed, or unsigned because the owner's config does not sign>

<For open-pr as ready, or ready-for-review: "Hosted ClawSweeper reviews this PR automatically once, now. Later pushes do not start another review.">

Reply yes to approve this one step for this head and this body. Any other reply, a new head or a changed body means I ask again.

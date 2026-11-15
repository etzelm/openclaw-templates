# Runtime output (layout for the PR body)

Paste this under the body's Evidence section and fill it in from the real runs (references/proof.md). One block per run, base first, then head. Every block is copied output, redacted, never retyped or summarized. Delete this heading line and the instructions.

### Runtime output

Setup: <what ran, in one or two lines: for example "isolated Gateway, own state dir, loopback, a stub chat model at the provider boundary">. <Name any stub here.>

**Before, on main `<base SHA>`**

Command:

```sh
<the exact command, as run>
```

Output (redacted, <N> of <M> lines; full log: <link pinned to the asset SHA, or "inline in full">):

```text
<the lines that show the cause and the failure, with timestamps or ids>
```

<One sentence: which lines show the cause and which show the failure.>

**After, on this branch `<head SHA>`**

Command:

```sh
<the same command>
```

Output (redacted, <N> of <M> lines; full log: <link>):

```text
<the same lines, now showing the fixed result>
```

<One sentence: which lines show the cause and which show the fixed effect.>

Not shown: <what this output cannot prove, and why (for example "needs a live account the owner does not have; the stub stands in at the provider boundary"), or "none">.

# Real behavior proof

Hosted ClawSweeper rates two things: patch quality and proof. A clean patch with no findings still stays at "needs proof" when the body only describes what happened. In live runs, three PRs got patch quality 4/6 with no findings and proof 1/6 or 2/6. On one of them the review said the body "describes the correct ... A/B scenario and gives an outcome table, but does not attach inspectable runtime output linking queue acceptance, occurrence completion, and the receiver's success". The run had been done. Its output stayed in a local log.

So proof is output a reviewer can inspect, not prose about output. This file says what that means, when to plan it, and how to package it. The repo's own rules come first: `docs/reference/pull-request-review-flow.md` ("Useful evidence", proof files, redaction) and the boundary-proof guide in `docs/help/testing/writing-tests.md`.

## What counts

Real behavior proof shows the changed behavior through the product path a user hits, before and after the fix. For each run, the PR body carries:

1. The exact command or steps, copied from what ran, not retyped.
2. The base SHA and the head SHA it ran at, as full or 11-character SHAs, taken from `git rev-parse HEAD` at the time of the run ("When it runs, and at which SHA").
3. The raw output: the log or terminal lines that show cause and effect, in a fenced code block, redacted, not paraphrased. Show the cause (the trigger, the request, the queued item) and the effect (the result, the reply, the error) in the same excerpt, with their timestamps or ids, so a reviewer can follow one through to the other.
4. One sentence after each block that names the lines that matter, for example "line 3 is the queued send, line 7 the sender's occurrence ending, line 9 the receiver's reply".

A focused unit test is proof of the code path, and it belongs in Evidence. It is not real behavior proof on its own. A table of outcomes, a summary of a run, or "verified locally" is not inspectable output.

## Run it safely

The runtime proof runs on the Gateway host, next to the owner's own OpenClaw. It must never touch it.

- Only the commands written in the approved scope.md run (contribution-loop.md, "What exec may run"): the start command, any stub command, the trigger command, the leftover check and the cleanup. Each is one plain command per exec call, started in the background with process when it keeps running, and logged to a file under `evidence/<slug>/`. Use the entry point and flags the repo's docs give for the build; do not guess them. A start command looks like this, with the real values:

  `env -u OPENCLAW_PROFILE -u OPENCLAW_SUPERVISOR_MODE OPENCLAW_STATE_DIR=<workspace>/evidence/<slug>/state OPENCLAW_CONFIG_PATH=<workspace>/evidence/<slug>/state/openclaw.json OPENCLAW_GATEWAY_PORT=<port> node <checkout>/openclaw.mjs gateway run --port <port> --bind loopback`

  Put the same `env -u OPENCLAW_PROFILE -u OPENCLAW_SUPERVISOR_MODE OPENCLAW_STATE_DIR=... OPENCLAW_CONFIG_PATH=... OPENCLAW_GATEWAY_PORT=<port>` prefix on every proof command that runs OpenClaw: the start, the trigger, and any CLI call in between. Exec children inherit the owner's Gateway environment. The owner's running Gateway exports its own `OPENCLAW_GATEWAY_PORT`, which a CLI call reads before the config, and OpenClaw reads `OPENCLAW_CONFIG_PATH` before the state folder. Without the prefix, a trigger dials the owner's live Gateway and a start can load the owner's real config, with its channels and keys.
- The test config lives at `evidence/<slug>/proof-config.json`, written with the write tool, never under the state folder. Before each start, copy it in: `cp -p <workspace>/evidence/<slug>/proof-config.json <workspace>/evidence/<slug>/state/openclaw.json`. The cleanup can then delete the state folder, and the head run and every re-run start from the same config.
- Before you trigger anything, check which config the proof OpenClaw uses: `env <the same prefix> node <checkout>/openclaw.mjs config file` must print the path inside your state folder, and the start log must show no channel starting. If either is wrong, stop the process at once, change nothing else, and tell the owner.
- After the trigger, check that it reached the proof Gateway: its log under `evidence/<slug>/` shows the request, or the trigger's output names your port. A run whose trigger went anywhere else does not count; stop and tell the owner.
- Its own state folder inside the workspace, its own loopback port, its own test config. Never the owner's state folder, config, port, sessions or channel accounts.
- Model and service calls go to a stub at the boundary unless the owner named a real one in the scope approval. No real message to any channel or person.
- Never put a key in a command or in the exec `env` option, and never read a key file. If the run needs a real key or account, the owner runs that one command in their own terminal, with the log going to a file under `evidence/<slug>/`, and you read the log. Say so in scope.md.
- Stop every process you started when the run ends, with the process tool. Then check that the port is free: `lsof -nP -iTCP:<port> -sTCP:LISTEN` must print nothing (it exits 1 when it finds nothing; that is the pass), and the process tool must list none of them as running. On a Linux host without lsof, the owner may write `ss -ltn` into scope.md instead; the port must not be listed. Do not use `pgrep -f <state folder>`: the folder is in the environment, not the command line, and the Gateway renames its process, so that check passes even when the Gateway still runs.
- Delete the state folder after the logs you need are copied out of it (`rm -rf <workspace>/evidence/<slug>/state`, written in scope.md as the cleanup); it can hold generated config.
- In the body, write paths with markers: `<workspace>`, `<checkout>`. The real absolute path is private.

When the run is several commands (start, stub, trigger), the body's Command fence lists them in the order they ran, the trigger last, so a reader sees what caused the output.

## When it runs, and at which SHA

The SHA on each block must be the SHA the run really used.

- **Base run**: in step 6, while the checkout is exactly the base (no product change yet). Head the log with `git -C <checkout> rev-parse HEAD` and `git -C <checkout> status --short`, which must print nothing but your new test file.
- **Head run**: after the last commit of step 9 (whatever the local review route, and also when the owner accepted remaining findings), on a clean checkout at `git -C <checkout> rev-parse HEAD`. A run on the uncommitted tree in step 7 is a rehearsal; it never goes in the body.
- After any later commit (a review fix in step 9, a hosted round in step 12), run the head run again at the new head before the body is updated. After a rebase onto a new base, run the base run again at the new base too. A block whose SHA is not the current head or base is stale.
- If the head run at the commit does not show the fixed effect after a clean rehearsal, the commit differs from what you tested: compare `git -C <checkout> diff <rehearsal tree or patch> HEAD`, fix it as a new finding (red, green, gates), and do not paste the failing run as proof.

## When there is no runtime path

Some fixes change nothing a user can run: docs, types, comments, a test-only change. Then `Runtime output` says so in one line, with why: "No runtime behavior change: <reason>". A fix in pure logic that a shipped command reaches (a parser behind a CLI flag, a formatter behind a reply) still has a runtime path: run the shipped command. Name it in scope.md either way.

## Plan it at scope time

The scope proposal (templates/scope-proposal.md, "Proof plan") names the proof shape before any code changes:

- The entry point a user hits, and the command or steps you will run on the base and on the head.
- Which lines in the output will show the cause and the effect. If no shipped entry point or log line shows the behavior, say so now: the PR will need a harness or a stub, and the gap is named in the body.
- Where the output goes: inline in the body when it fits, or a proof branch when it is long (below).
- What the run needs: an isolated Gateway, a test config, a channel account, a provider key, a paid model.
- The exact commands, the state folder and the port ("Run it safely"). These are the only runtime commands the scope approval covers.

### When the proof needs an account the owner does not have

Some behavior shows only with a live account: a channel login, a provider with a paid plan, a phone number, an OAuth app. Check this at scope time, not after the PR opens. Ask the owner whether they have it. If they do not, say so in the scope proposal and offer both:

- A stub: a local fake of the service at the boundary the product calls (a fake HTTP server, a fixture provider, a stub chat model), run through the real entry point, with its output captured the same way. Name it as a stub in the body.
- A request: one or two lines the owner can post on the issue, after their OK, asking someone with that account to run a given command and paste the output. You never post it yourself; it is an owner-gated comment like any other.

Then the body says plainly which part is a stub and which part needs a live account. A gap named at scope time is a decision the owner made. A gap found after the PR opens is another hosted round.

## Package it

Under the body's Evidence section, add a `### Runtime output` heading. Use the layout in templates/runtime-output.md. One block per run, base first, then head.

- Keep each inline block short: the lines that show cause and effect plus a few lines of context, at most about 40 lines. Cut the rest with a `[... N lines cut ...]` marker; never cut a line between the cause and the effect.
- Redact before anything leaves the machine: tokens, API keys, cookies, IP addresses, phone numbers, emails, private hostnames and paths, user names, other people's data. Replace each with a marker such as `<redacted-token>` and keep the line. Check with references/upstream-text.md.
- Never put a secret in a command line to get output. If a run needs a key, the owner runs that command ("Run it safely").
- The text checks in references/upstream-text.md apply to the whole body. A hit inside a `Runtime output` fence is fixed by redacting it with a marker, never by retyping or rewording the log line; the markers themselves (`<redacted-token>` and the like) are not hits. Log words such as `token` or a log line with `@` are fine when nothing secret or personal follows them.

### Long logs

Inline is the default: the repo's review flow prefers "a short redacted log excerpt" and says not to commit generated proof files to the change. Most proofs fit in two excerpts of about 40 lines, in a collapsed `<details>` block if needed. Only when a reviewer needs the whole log to follow it, put the redacted logs on a proof branch of the fork and link them. That branch is never part of the PR's commits, so nothing generated lands in the repo. It is the same branch and the same steps as proof images in contribution-loop.md step 10 ("Proof images and long logs"):

1. Make the orphan branch `proof-assets/<slug>` in a separate worktree made with references/setup-worktree.sh, never on the PR branch.
2. Copy only redacted files there, for example `base.log`, `head.log` and a short `README.md` that names the command, base SHA and head SHA for each.
3. Commit (signed when the owner's config signs), get the asset SHA, check `git -C "<workspace>/assets-<slug>" log -1 --format='%G? %ae %ce' <asset SHA>`, and ask for a `push` approval bound to it: `git -C "<workspace>/assets-<slug>" push <fork> <asset SHA>:refs/heads/proof-assets/<slug>`. Under a standing grant this push is not covered: it is a pause and a fresh owner answer.
4. Link each file pinned to the asset SHA: `https://github.com/<fork_repo>/blob/<asset SHA>/<file>`. Check each link with `gh api "repos/<fork_repo>/contents/<file>?ref=<asset SHA>"` (quoted, because of the `?`) before asking for `open-pr` or `edit-pr`.

The inline excerpt stays in the body even when the full log is linked. Reviewers and ClawSweeper read the body first.

## Self-check before the push gate

Before asking for the first `push` (step 11), and again before each `edit-pr` under a standing grant (step 12), open `evidence/<slug>/pr-body.md` and answer in writing in `evidence/<slug>/proof-check.md`. Start the file with three lines: `head: <git rev-parse HEAD>`, `body sha256: <shasum -a 256 of pr-body.md>`, `checked at: <UTC time>`. A check for another head or body hash does not count. Then:

1. Does the body contain the actual output a reviewer can inspect? Point to the fenced block under `### Runtime output`, not to a sentence that describes it.
2. Does each block name its command and SHA, and does the head block's SHA equal `git -C <checkout> rev-parse HEAD` now? If not, run the head run again ("When it runs, and at which SHA").
3. Do the cause and the effect both appear in the output, so a reader can link them without trusting your summary?
4. Is everything redacted, and does every link resolve at its pinned SHA?
5. If a part has no runtime output, does the body name the gap, why, and what would close it (a stub, a live account, a maintainer run)?

If the answer to 1 is no and a runtime proof exists in `evidence/<slug>/`, package it now. If no runtime proof exists and one is possible, go back and run it. Record the check with `add-evidence`, kind `other`, result `pass` or `fail`, and the note `proof self-check: <one line>`. Do not ask for the push with a `fail` unless the owner already accepted the named gap at scope time.

## After "needs proof"

A hosted review with `status: 📣 needs proof`, or a `Proof guidance:` or "Add real behavior proof" item, is your turn. Read exactly what it says is missing; it usually names the events it wants to see linked. Run or re-run the proof so the output shows those events, package it as above, edit the body under the standing grant, and request one re-review for the head. Do not argue with the rating in a comment, and do not reword the body to move it without adding output.

Two limits of the standing grant apply here. A `proof-assets` push is not covered: pause and ask the owner for it (step 11). And the grant allows one re-review per head: if only the body changed and the head did not, and a re-review for that head was already used, the next one needs a fresh owner answer, so get the proof right before the first re-review on a head.

The local `--local-range` review never sees the body, so its proof rating says nothing about this packaging. The owner sees the `Runtime output` section in the `open-pr` and `edit-pr` approval requests (templates/approval-request.md); that is the outside look before it goes public.

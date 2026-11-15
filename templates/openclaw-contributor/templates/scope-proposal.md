# Scope proposal: <slug>

- Issue: <link, or "none yet: an issue is needed first" when the repo's rules ask for one>
- Repo rules read at: <upstream SHA>

## Problem

<One or two sentences: what goes wrong, for whom, and when.>

## Prior work found

<Open and closed issues and PRs, merged PRs that may already fix it without linking the issue, commits on main, and maintainer comments that touch this. "None found" with the searches you ran.>

## Smallest fix

<The code that owns the behavior, the change in one or two sentences, and the files you expect to touch.>

## Proof plan

- Red: <the test or end-to-end repro that fails on current main, and why it fails for the reported reason>
- Green: <the same proof passing with the fix, plus the consumer tests>
- Runtime output: <the entry point a user hits, and the log or terminal lines that will show cause and effect (references/proof.md). Inline in the body, or long logs on `proof-assets/<slug>`.>
  - State folder, port and config: <`<workspace>/evidence/<slug>/state`, loopback port N, test config at `evidence/<slug>/proof-config.json`>
  - Prefix on every OpenClaw command: <`env -u OPENCLAW_PROFILE -u OPENCLAW_SUPERVISOR_MODE -u OPENCLAW_GATEWAY_URL -u OPENCLAW_GATEWAY_TOKEN -u OPENCLAW_GATEWAY_PASSWORD OPENCLAW_STATE_DIR=... OPENCLAW_CONFIG_PATH=... OPENCLAW_GATEWAY_PORT=N`>
  - Start: <copy the config in, then the exact start command with the prefix>
  - Stub: <exact command, or "none">
  - Trigger: <exact command that causes the behavior, with the prefix>
  - Checks: <`config file` with the prefix prints the state folder path; the proof Gateway log shows the trigger>
  - Leftover check: <`lsof -nP -iTCP:<port> -sTCP:LISTEN`>
  - Cleanup: <`rm -rf <workspace>/evidence/<slug>/state`>
  These are the only runtime commands your OK covers.
- Needs: <what the run needs: an isolated Gateway, a test config, a channel account, a provider key, a paid model. For each live account: "owner has it" or "owner does not have it: offer a stub at <boundary> plus a request the owner can post on the issue">
- Gap: <what the runtime output cannot show, and why, or "none">

## Gates

<The commands from the repo's rules for these paths, or from settings.md.>

## Risks and decisions

<Behavior changes, compatibility, anything maintainers must decide. "None" if none.>

## Not in scope

<Related cleanups or ideas left out on purpose.>

Reply OK to start, or say what to change. This OK covers local work only. Every push, PR or comment is asked for separately.

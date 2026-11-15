<!-- Example from a real 0.2.0 run on an isolated test host (no GitHub login, no GitHub writes). The agent stopped here, at its first owner gate. It predates 0.4.3: a proposal today fills the "Runtime output" slots in templates/scope-proposal.md (state folder, port, start, stub, trigger, leftover check, cleanup) instead of one "End to end" line. -->

# Scope proposal: exec-allowlist-tilde-docs

- Issue: none. This is a local bug report from the owner; no GitHub issue exists. CONTRIBUTING allows very small fixes to go straight to a PR, and the PR template's linked context is optional.
- Repo rules read at: `c74c7a977c060678604b01968547b45c4997cd7c` (upstream/main).

## Problem

In allowlist mode, a command whose executable is allowlisted is denied when one of its arguments contains an unquoted `~`. The gateway returns `ask-fallback-deny: execution-plan-miss` instead of running the command. The docs for exec approvals and the exec tool describe allowlist matching but never say that unquoted shell expansion in arguments, including `~`, prevents allowlist auto-execution. Operators therefore write `~/...` paths and get denied.

## Prior work found

- No GitHub issue matches `execution-plan-miss` (`is:issue` search returned 0). PR searches returned implementation/history PRs only, including merged #187884, which added the enforced-renderer rejection for dynamic shell predicates.
- `git grep` on upstream/main found no mention of `execution-plan-miss` in `docs/`, and no shell-expansion guidance in `docs/tools/exec-approvals.md` or `docs/tools/exec.md`.
- `src/infra/exec-authorization-render.ts` rejects unquoted shell expansion in enforced arguments with `shell expansion in enforced arguments`; the existing test `src/infra/exec-authorization-render.test.ts` covers `cat ~/secret`.
- `src/agents/bash-tools.exec-host-gateway.ts` maps that renderer failure to `ask-fallback-deny: execution-plan-miss` when security is allowlist, ask is off, and askFallback is deny.
- No open docs PR for this gap was found.

## Smallest fix

Keep the behavior unchanged and document it.

- In `docs/tools/exec-approvals.md`, in the allowlist section after the shell-chain paragraph, add a short note: allowlist auto-execution rebuilds the command as an enforced plan and refuses unquoted shell expansion in arguments, including `~`, `$VAR`, globs, and command substitution. Use absolute paths (or quote a value that must stay literal). With allowlist + ask off + `askFallback: deny`, the result is `ask-fallback-deny: execution-plan-miss`.
- In `docs/tools/exec.md`, in "Allowlist + safe bins", add one sentence with the same rule and the absolute-path workaround.

No code change. The behavior is intentional and already covered by the renderer test.

## Proof plan

- Red: at upstream/main, `git grep` shows neither docs page mentions shell expansion or `execution-plan-miss`; the existing renderer test shows `cat ~/secret` is rejected as `shell expansion in enforced arguments`. That establishes the docs omission.
- Green: the new text is present in both pages, `git diff --check` passes, and the docs sanity checks pass.
- End to end: docs-only change, so there is no runtime behavior to re-prove. The product path is the rendered docs check. Dependencies are not installed on this host, so any docs command that needs `node_modules` will be recorded as a gap rather than silently skipped.

## Gates

- `git diff --check`
- `pnpm docs:check-mdx`
- `pnpm docs:check-links` if any link changes (none expected)
- Note: the checkout has no `node_modules`; the owner asked not to run the install. If a docs check needs dependencies, I will record the missing install as a named gate gap and ask before installing.

## Risks and decisions

- No behavior, API, config, or compatibility change. This is wording only.
- If maintainers prefer changing the matcher to expand `~` before approval evaluation, that is a separate security/behavior decision and is not in this scope.
- No maintainer decision is needed for the docs clarification itself.

## Not in scope

- Changing allowlist matching or shell-expansion handling.
- Changing the denial text.
- Editing other docs pages.

Reply OK to start, or say what to change. This OK covers local work only. Every push, PR or comment is asked for separately.

<!-- The agent's chat message at its first owner gate, same run. -->

Duplicate check is done, and I stopped at the scope proposal: this is my first request for your OK.

**Candidate:** docs gap for allowlist commands with `~` arguments. No GitHub issue exists, so I recorded it locally as candidate #3.

**What I found**
- `execution-plan-miss` as an issue: 0 results.
- PR searches found implementation/history PRs only, including merged #187884, which added the enforced-renderer guard. No docs PR for this gap.
- `docs/tools/exec-approvals.md` and `docs/tools/exec.md` never mention shell expansion in command arguments or `execution-plan-miss`.
- Root cause is intentional: `src/infra/exec-authorization-render.ts` rejects unquoted shell expansion in enforced arguments with `shell expansion in enforced arguments`, and the gateway maps that to `ask-fallback-deny: execution-plan-miss` when allowlist + ask off + fallback deny. The existing test covers `cat ~/secret`.
- So the fix is documentation, not behavior.

**Scope proposal**: `evidence/exec-allowlist-tilde-docs/scope.md`
- Add a short note to the allowlist section of `docs/tools/exec-approvals.md`: enforced allowlist execution refuses unquoted shell expansion in arguments, including `~`, `$VAR`, globs, and command substitution; use absolute paths; the denial appears as `ask-fallback-deny: execution-plan-miss`.
- Add one matching sentence to `docs/tools/exec.md` under "Allowlist + safe bins".
- No code change. No issue is required for a very small fix under CONTRIBUTING; the PR template's linked-context line is optional.

**Proof and gates**
- Red: docs grep shows the omission; the renderer test confirms the `~` rejection.
- Green: new text present, `git diff --check`, `pnpm docs:check-mdx`.
- Gap: `node_modules` is absent and you asked not to install, so any docs check needing dependencies will be recorded as a named gap.

Recorded as `proposed`; tracker now shows 3 candidates, 0 contributions.

Reply **OK** to start local work, or tell me what to change.

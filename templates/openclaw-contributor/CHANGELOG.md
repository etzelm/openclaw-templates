# Changelog

## 0.4.1

Catalog polish and two fixes from live use of 0.4.0. No database change.

- The catalog icon ships. `assets/icon.png` is now listed in `workspace.files` (copied to `avatars/catalog.png`), so `openclaw templates build` packs it and ClawHub uses it as the Template icon. Before, the build left it out and the catalog showed a generic box.
- New artwork: a teal Blobster in navy overalls holding a pull request card, as a 512 px icon and a matching avatar SVG.
- Setup pins this agent's exec host: `agents.entries.<agent-id>.tools.exec.host` set to `gateway`, in the same required block as the ask mode. Unpinned, exec followed the owner's paired laptop and sent every approval prompt there. Setup checks with `pwd` that commands run in the workspace. The loop never sets `host` or `node` on exec, and installs, builds and tests stay on the pinned host.
- Setup asks the approval relay question every time, as its own question, and records the answer. README explains the relay under "Add it".
- README rewritten for people browsing the catalog: what it does, how you stay in control, an example, then the details. New "Skills and plugins" section says why none are declared.
- Shorter catalog description.
- "Upgrade in place" covers 0.4.0 to 0.4.1 (files and the host pin only) and 0.3.x (with the migration).

## 0.4.0

Fixes from the first live use of 0.3.0 on a real issue, and the ClawHub scan finding on 0.1.0.

- Database schema version 2, with a packaged migration (`references/sql/migrate-v1-to-v2.sql`) that keeps every row. Setup and the loop check for version 2. A version 1 database is upgraded by the owner, never by the agent. README has an "Upgrade in place" path for a 0.3.x agent.
- Approvals are bound to what the owner saw: `use-approval` now needs the same exact command, the same head and, for a `--body-file` step, the same `body_sha256`. `ask-approval` needs the body hash for body-file steps. This fixes the ClawHub finding that a head-independent approval accepted any head.
- New approval decisions: `withdrawn` (the agent closes a stale request before any answer) and `recorded-outside` (the owner did the step outside this agent; the agent only records the verified result). `denied` now means only that the owner said no. `decide-approval` needs `owner_words`.
- When OpenClaw's exec prompt fails before an approved command runs, the agent checks nothing happened, records `not run: <error>`, tells the owner, and asks a new approval. A spent approval is never re-armed.
- New optional setting `approval_relay`: answers passed on from a named session or agent count only when they name the approval id, command, head and body hash, and where and when the owner said it.
- New "Adopt work started elsewhere" section: check a handed-over commit, use a detached worktree when its branch is held, copy outside evidence into `evidence/<slug>/` first, and record who ran each earlier proof.
- New "Proof images" section: screenshots go on an orphan `proof-assets/<slug>` branch of the fork, pushed under its own approval and linked by SHA-pinned raw URLs before the PR opens, so the hosted review sees them.
- Agent-authored work gets an issue first, as CONTRIBUTING.md asks. `set-candidate` can set the issue url and number once the issue exists.
- One plain command per exec call: OpenClaw refuses chained or piped commands under `ask`.
- The signing check runs only when the owner's git config signs.
- README: local build facts (Add takes the unpacked folder, a local Add needs the Gateway stopped, extra tools go in `tools.allow`), the live run, and an updated "Not yet tested live".
- The simplify guide and upstream writing rule are named as files and rules of the openclaw/openclaw repo.

## 0.3.0

- Local ClawSweeper is the recommended local review. Setup offers a public source checkout in `clawsweeper/` in the workspace (clone, install, build, diagnostics check) and the owner logs in to Codex himself with `codex login --device-auth`. Opting out is explicit and recorded in `local_review_note`.
- New local review loop after the commit (step 9): ClawSweeper `--local-range` on the committed range, one log per round, `review_status: complete` and `local_checkout_access: verified` required, must-fix findings fixed with red, green, mutation check, gates and simplify, a new run for every new head. Stops at `review_target` (default: no must-fix findings; optional rating floor), a maintainer decision, or `review_max_rounds` (default 3).
- Second ClawSweeper route: the OpenClaw runner (`CLAWSWEEPER_RUNNER=openclaw`). New settings `clawsweeper_runner` (codex default, or openclaw) and `clawsweeper_model` (`provider/model`). Setup asks which runner, lists what the route needs (OpenClaw on the host, an API-provider model, the provider key set by the owner in the environment, never given to the agent), and says there is no diagnostics check for it without a model call. A claude-cli model is refused: ClawSweeper's checkout inspection fails with "did not read the exact challenged path". The review command forms, failure handling and Evidence line cover the runner. Codex path unchanged.
- An issue gets one `--local-only --item-number` run during the decision check; an open PR gets one before a hosted re-review is requested.
- The PR Evidence line reports the review in the review flow doc's terms: tool, base and head, coverage, outcome, remaining findings. Never switch tools to hide findings.
- Mutation check in step 7: the fix is reverted once and the new test must fail again. The proof is checked against the repo's boundary-proof guide.
- `open_pr_as: ready` stays the default, opened only after the local review met its target, because hosted ClawSweeper reviews a PR automatically once. Hosted re-review etiquette: batch fixes, check for a pending review, verify the result covers the current head.
- Commit signing: the agent keeps the owner's signing setup, never commits with `--no-gpg-sign`, and stops if signing fails.
- Exec approvals guidance covers the ClawSweeper review command; never ClawSweeper's apply, posting or merge commands.
- The upstream remote is now `origin` and the fork remote `fork` by default: the repo's own scripts read `origin/main`. Setup clones from upstream instead of the fork.
- ClawSweeper's pnpm commands run from inside `clawsweeper/`; `pnpm --dir` from the workspace root fails under corepack because ClawSweeper pins its pnpm version.
- New examples from a 0.3.0 test run on a real issue: the PR body draft and the push approval request. README "Not yet tested live" is updated from that run.
- The database schema did not change (still version 1).

## 0.2.0

- Uses the single-file `CLAW.md` format: tool grants under `agent.tools`, no `packages`, `cronJobs` or `profiles/`. 0.1.0 cannot be added on current OpenClaw.
- The database moved to `db_path` (default `~/openclaw-contributor.db`), outside the OpenClaw state folder. A default Add now works from the CLI and the Control UI; no `--workspace` needed.
- Fix: an approval for push, force-push, open-pr, edit-pr or ready-for-review, and for any other action tied to a contribution except open-issue and create-fork, must name the commit SHA it was asked for, and never matches a later head. Approvals saved by 0.1.0 without a SHA can no longer be used for those steps.
- Exec approvals are now a required setup step, with exact commands: exec mode `ask` with nothing allowlisted (not even sqlite3, which can start programs through dot-commands) and `references/` made read-only. The owner approves each packaged database command once with "Always allow here". Setup records the database's absolute path first, because the exec allowlist refuses `~`.
- Setup asks about an upgrade first, handles an empty database file, and ends by asking the owner to remove BOOTSTRAP.md.
- The loop checks at start that the upstream files it depends on still exist, and stops with the moved path if not.
- `upstream_repo` is fixed to openclaw/openclaw.
- Pacing and rate-limit handling for `gh search`.
- The listing and README state requirements, disk and backup cost, model strength, and how the Template handles AI disclosure.
- Upgrade notes from 0.1.0. The database schema is unchanged.
- README lists what has not been tested live yet.
- Added README, CHANGELOG, LICENSE and sanitized examples from a real run (scope proposal, first-gate message, tracker) to the package.

## 0.1.0

- First release.

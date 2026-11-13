# Changelog

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

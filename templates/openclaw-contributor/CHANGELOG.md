# Changelog

## 0.4.6

Decide with evidence. No database change (still schema version 3).

- When the owner explicitly asks for an implementation (an RFC, a design, a stalled stack), the agent builds a working prototype on top of the existing work, answers each open design question with its best recommended answer, and proves it. Each answer gets one line: the choice, the evidence, and how to reverse it.
- PR bodies get a `Decisions` table (choice | evidence | how to reverse) for every design choice the evidence settled. A short `Needs a maintainer` list holds only what the agent cannot do or decide: CI or SecOps approval, dependency sign-off, an SDK or surface budget raise, credit, or anything that needs an outward post. This replaces the "decision maintainers need to make" lines.
- A local review finding that asks for a design or product choice is no longer a stop. The agent decides it, builds it, proves it and adds a `Decisions` row. The loop stops early only for a gate it cannot clear.
- The `clawsweeper:needs-product-decision` label gets one decide-and-re-review pass before it is a stop. The agent turns each choice the evidence can settle into a built and proven `Decisions` row and requests one re-review. It stops only if the label stays on that new head. The standing grant request says so.
- Why: live use showed PR bodies listing maintainer questions the evidence could settle.

Upgrade from 0.4.5: replace the packaged files (README, "Upgrade in place") and skip the database migration. Settings, open grants and PR watchers stay as they are.

## 0.4.5

Two fixes from parallel live sessions on 0.4.4. No database change (still schema version 3).

- Per-task DB input files. Every packaged step used to read one shared `db-input.json`, so parallel sessions overwrote each other's input (seen with up to 5 sessions; the step checks refused the mismatch, but steps had to be retried). Each task now writes `db-input/<slug>.json` (`db-input/pick-<session>.json` before it has a slug) and runs `sqlite3 -bail -json "<db_path>" ".parameter set @db_input db-input/<slug>.json" ".read references/sql/<step>.sql"`. The steps read `readfile(coalesce(@db_input, 'db-input.json'))`, so the old command still works, and a missing per-task file fails instead of falling back to the shared file.
- PR watcher works again. OpenClaw's bundled tokenjuice plugin rewrites gh JSON in exec results, trigger-script exec included, into a text summary ("status checks: 26 ok, 3 attention"), so every check threw "gh pr view output is not JSON". `references/pr-watch.js` now pipes its one read through `base64` and decodes it in the check; base64 output passes through tokenjuice unchanged. Output that is not base64 gets its own clear error.

Upgrade from 0.4.4: replace the packaged files (README, "Upgrade in place") and skip the database migration. The packaged sqlite3 commands change, so "Always allow here" asks once more for each new form. Existing PR watchers keep the old script: remove each one and add it again from the new `references/pr-watch.js`, with the same `const pr` and a fresh `const addedAt`.

## 0.4.4

PR tracking dashboard, and proof accounts checked at pick time. No database change (still schema version 3).

- Proof accounts. Before proposing or offering an issue, the agent writes down the proof run (entry point, command, base and head SHAs) and every account, subscription, device or channel login it needs. If the owner lacks one, the issue is skipped and recorded `out-of-scope` with a `proof account:` reason. New setting `proof_accounts` (blank: the agent asks once). The 0.4.3 fallback of a stub at the boundary plus a request for someone else to run the proof is removed; a stub is still fine for a service the agent controls when the real behavior is fully shown. If a missing account shows up after the PR opens, the agent stops proof work for it and reports to the owner. Why: a PR whose proof needs an account the owner does not have reviews clean but stays at "needs proof" with no way to finish, and holds one of the owner's open PR slots.

- New read-only PR dashboard, pinned on the agent's own dashboard. It lists the owner's open PRs in `dashboard_org` and the ones closed in the last 14 days, with who acts next, ClawSweeper rating and proof labels, priority, merge state, CI (with OpenClaw's CI gate; cancelled and skipped checks are not failures), status and merge-risk labels, and the last update. Sortable columns, filter counters, and Copy list and Copy selected buttons. An optional Refresh button (`dashboard_refresh_button`, off by default) runs the refresh automation now; OpenClaw ties a widget grant to its exact bytes, so in ask mode it asks again after every change.
- New references/pr-dashboard/: `build.mjs` (plain Node, no packages), `template.html`, `prs.graphql`, `ci.graphql` and `refresh-trigger.js`. The builder makes two read-only gh GraphQL calls, tries each up to 3 times (GitHub's search answers 502 or 504 at times), stays inside the 30 second budget of an automation check, and prints `CHANGED`, `UNCHANGED` or `ERROR <reason>` on its last line. `CHANGED` means the widget differs from the last pinned one: the digest covers what the widget shows (dates, not times) and the template, and `--mark-pinned <digest>` records a pin in `dashboard/pinned.txt` only if the files still match that build, so a failed pin is retried. It writes `dashboard/data.json` and `dashboard/widget.html` in the workspace, embeds the data as JSON, one row per line, with a CRC32 the widget checks, keeps only the labels the widget reads, and keeps the last known merge state while GitHub recomputes it. Missing optional fields get defaults instead of failing the build.
- Setup, in a Control UI turn, and re-running it, does three steps in order: build, pin with `show_widget` (name `openclaw-prs`, the same name updates in place), and one refresh automation (declarationKey `pr-dashboard-refresh`, found by listing first, updated in place, never added twice). Every 15 minutes within `watch_hours` its check runs the builder; `UNCHANGED` starts no model turn, `CHANGED` wakes the agent to pin the new table and mark it pinned (up to 3 times for the same table, then hourly), and an `ERROR` wakes it on a new error and once a day while it lasts. The check reads the result line from the trigger exec result's `aggregated` text, which ends with an exit code note on failure.
- The widget is read only: no GitHub writes, no network origins, links open through the Control UI. It declares no capability unless the Refresh button is on.
- `dashboard/short.json` is agent-maintained: the agent adds a one-line plain summary when a PR it opened is verified, and the refresh turn adds missing ones for open PRs. Rows without one show the cleaned title.
- New settings: `dashboard` (on by default; `off` is final until the owner changes it: the agent never builds, pins or offers it and does not ask again), `dashboard_note`, `dashboard_author` (blank: the gh login), `dashboard_org` (default `openclaw`) and `dashboard_refresh_button` (default off). The Template now grants `show_widget`.

Upgrade from 0.4.3: replace the packaged files (README, "Upgrade in place"), skip the database migration, add `proof_accounts` and the five dashboard settings lines, add `show_widget` to the agent's tools, then ask the agent to set up the PR dashboard. Open grants and PR watchers stay as they are.

## 0.4.3

Fixes from live use of 0.4.2 on three PRs. No database change (still schema version 3).

- Proof packaging. Three live PRs got hosted patch quality 4/6 with no findings, but proof stayed at 1/6 or 2/6 (`status: 📣 needs proof`): the bodies described real runs and outcome tables but attached no output a reviewer could inspect. New references/proof.md and templates/runtime-output.md. Real behavior proof is now the exact command, the base and head SHAs, and the raw redacted lines that show cause and effect, in fenced blocks under a `Runtime output` heading. Long logs go on the fork's `proof-assets/<slug>` branch and are linked pinned to its SHA. The proof shape is planned in the scope proposal. When the proof needs a live account the owner does not have, the agent says so at scope time and offers a stub plus a request the owner can post. A written self-check (`evidence/<slug>/proof-check.md`, bound to the head and body hash: "Does the body contain the actual output a reviewer can inspect?") runs before the first push gate and before each body edit under a standing grant. The base run happens in step 6 while the checkout is exactly the base, the head run after the last commit and again after each later fix, so each block's SHA is the one the run used. Runtime proof commands may run only as written in the approved scope, with their own state folder and loopback port, never against the owner's Gateway or accounts. Every OpenClaw command of the proof carries one prefix that pins the state folder, the config file and the port (`OPENCLAW_GATEWAY_PORT`, which the owner's running Gateway exports to exec children) and unsets the profile, `OPENCLAW_GATEWAY_URL` and the Gateway token and password, and the agent checks which config is loaded and that the trigger reached the proof Gateway. The leftover check is the port, not `pgrep`. The owner sees the `Runtime output` section in the `open-pr` and `edit-pr` requests. New example docs/examples/runtime-output.md. The text checks no longer push the agent to reword log lines: hits inside the output are fixed by redaction markers.
- PR watcher baseline. The packaged check has a second placeholder, `const addedAt`, set to the time the watcher is added (ISO 8601 UTC with `Z`; anything else throws). Its first check saves the baseline and always fires once, naming what is newer than `addedAt` (comments, reviews, finished checks, a closed PR), because labels and in-place comment edits carry no time in its read. Before, the first check only saved, so a ClawSweeper review that landed between the add and the first check never woke the agent. ClawSweeper is matched on its exact login. A missing or non-JSON `gh pr view` result now fails with a clear error instead of a bare SyntaxError. The loop documents that a wake for a busy session waits for the turn to end, and that a forced run's runs list stays empty until then.
- Stop conditions named exactly: the `waiting on maintainer` or `needs maintainer proof decision` label (needs-maintainer-decision), the `clawsweeper:needs-product-decision` label, scope growth, 4 hosted rounds without progress. A human or maintainer comment stays a pause, as in 0.4.2: the agent never replies, keeps the grant and the watcher, and waits for the owner. `security-review-required` and fork CI `action_required` are parallel maintainer gates: keep working, never post `/allow-security-sensitive-change`, never ping.
- Duplicate check: an issue that is open but already fixed by a merged PR without a closing keyword is `duplicate`, with the fixing PR and commit, and no comment.
- New references/setup-worktree.sh: creates a worktree (or adopts one with `--existing`), sets the worktree-only noreply author and signing, and checks a signed test commit, in one exec call. It refuses a non-noreply email, a relative path, a flag with no value and a bare repository (a shared `core.bare=true` would break every linked worktree once worktree config is on), and checks that the worktree works before it prints ok. The proof branch worktree is made with it too, and its commit is checked before the push request. Some runtimes do not let the agent run `git config`; the owner or a main agent can run the script instead. New settings `commit_name` and `signing_key`.
- Never `git stash`: the stash list is shared by every worktree of a repository, and a live run had two sessions' stashes swapped. The mutation check now saves the fix as a patch and uses `git apply -R` and `git apply`.
- Changed-file gates such as `pnpm check:changed` run only against a freshly fetched base, also in a remote runner or synced checkout. The loop names the stale baseline symptom (a changed-file list of hundreds of upstream files and failures in untouched files) and says not to record it as failing on main.
- Relays of owner approvals come from an interactive turn, not a scheduled run: a message a scheduled run sends to a busy session can fail with "Cron occurrence source authority is no longer active" (upstream openclaw/openclaw#199278).

Upgrade from 0.4.2: replace the packaged files (README, "Upgrade in place") and skip the database migration; run `setup-check.sql` only. Add `commit_name` and `signing_key` to settings.md. Config, open grants and existing watchers stay as they are; only new watchers get the baseline.

## 0.4.2

Fixes from the first real task with 0.4.0 (openclaw/openclaw#198802, PR #199042). Database schema version 3.

- The loop no longer ends at PR open. New step 12, "After the PR opens": the agent watches hosted ClawSweeper and CI, fixes findings with the full proof loop (red, green, mutation check, gates, simplify, a signed commit, a local review round), and stops when the PR is labeled `status: 👀 ready for maintainer look` for the current head with required CI green. It pauses on any human comment, someone else's push or a step it may not take, and stops on a maintainer-decision label, scope growth, a closed PR, 4 hosted rounds without progress, or 7 days with no change. One report per hosted round.
- Standing grant per PR. The owner grants once, per open PR, for plain pushes of signed commits, PR body edits and one `@clawsweeper re-review` per new head (templates/standing-grant.md). Each use is still its own approval row, granted under the grant, bound to the exact command, head and body hash. New steps `record-grant` and `end-grant`; `decide-approval` takes `grant_id`. The database checks each use against the grant: the action, a full head SHA, and the command shape (a plain push of one refspec ending in the PR's branch, to a remote other than origin, with no force, delete or `+` refspec; a body-only `gh pr edit` of that PR with `--repo openclaw/openclaw`; a `gh pr comment` of that PR with `--repo openclaw/openclaw` and the packaged one-line `references/re-review.md`). It refuses a second open grant, a use for another contribution, a second re-review for the same head, a sixth re-review, and any grant or use after the grant ended. `ask-approval` now refuses inline `--body`/`-b` and needs the body hash for `-F` too.
- Schema version 3: the `grants` table, `approvals.grant_id`, and the evidence kind `hosted-review`. Packaged migration `migrate-v2-to-v3.sql` keeps every row and leaves pending requests pending. The tracker shows an open grant.
- PR watcher. The Template grants the `automations` tool. After the PR opens, the agent adds one watcher on its own session: every 15 minutes within `watch_hours`, with the packaged read-only check `references/pr-watch.js` (one `gh pr view`), waking the agent when the PR's state, head, labels, comments (ClawSweeper edits in place too), reviews or finished checks change, and once a day while nothing changes. It is removed at the end. The target label is matched on its words (`status: 👀 ready for maintainer look`), and only when ClawSweeper's latest review covers the current head. The packaged check replaces hand-written scripts: the live run's script read `stdout`, which trigger-script exec does not return, so it could not see changes.
- Fork CI waiting on maintainer workflow approval (`action_required`, and a gate check that reads FAIL) is its own CI class: record it, report it, wait. Never ping anyone, never rerun.
- Commit identity and signing at setup. The owner sets a GitHub noreply author and ssh or gpg signing for the checkout only, before the first commit. Setup checks a test commit shows `G` and the noreply address. Before each push, every commit's author, committer and signature are checked. New settings `commit_email`, `signing`, `signing_note`.
- A relay that names everything but the approval id, because none was asked yet, now counts: the agent asks the row with exactly those values and records the relay.
- In exec mode `full` there is no exec prompt. The text says so, and the agent no longer promises one.
- A local gate that fails the same way on the base is recorded as already failing on main and not fixed in the PR.
- New optional `runner_prefix` setting for owners who run heavy work on another machine. Exec stays pinned.
- `@clawsweeper re-review` is named as the one allowed bot command in public text.

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

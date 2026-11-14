# CI triage

Classify every failing check on the PR's current head before fixing anything or saying anything about it. "Looks unrelated" is not evidence.

## Steps for each failing job

1. Confirm the head: the check must belong to the PR's current `headRefOid`. A result from an older head is old evidence.
2. Get the failure: `gh pr checks <n> --repo <upstream_repo>`, then `gh run view <run-id> --repo <upstream_repo> --log-failed`. Pass `--repo` to every `gh` command: the workspace root is not a git checkout. Save a short excerpt, never the whole log, to `evidence/<slug>/ci/<job>.log`.
3. If the repo provides `pnpm test:ci-failed <pr>`, run it and read its classification. Its `--run` mode reruns the failed tests locally.
4. Compare paths first: list the PR's changed files with `gh pr diff <n> --repo <upstream_repo> --name-only`. List the failing test files and the source files they import. Note any overlap.
5. Check main: find the same workflow and job on recent `<base>` runs with `gh run list --repo <upstream_repo> --branch <base> --workflow <workflow>` and `gh run view --repo <upstream_repo>`. Note whether the same job and test fail there, with the run link and SHA.
6. Run the failing test locally on the PR head, and on the base when the class is in doubt.

## Classes

- **Caused by this change**: the failing test or path overlaps the change, or the test passes on the base and fails on the head. Fix it with the normal red, green and gates steps.
- **Already failing on main**: the same job and test fail on a recent `<base>` run without this change. Give the main run link and SHA. Do not add test or CI changes to chase it; the repo's rules say maintainers track these.
- **Flaky**: the same test passed and failed on the same head SHA, in CI or locally, with no change in between. Give both results. Do not rerun CI to chase green; a rerun is an owner-gated step.
- **Waiting for maintainer workflow approval**: on a PR from a fork, GitHub holds the `pull_request` workflows until a maintainer approves them. `gh run list --repo <upstream_repo> --commit <head>` shows them with conclusion `action_required`, no job ran, and a gate check such as `openclaw/ci-gate` reads FAIL because CI never ran. This is not a code failure and there is no log to read. Record it once per head with the run names, say it in the report, and wait. Never ping, mention or ask anyone to approve the workflows, and never rerun. When a maintainer approves them, the runs start on their own and you classify the real results.
- **Unknown**: none of the above is proven. Say so, with what you checked. Unknown is not unrelated.

Record each with `add-evidence`, kind `ci-classification`, result `fail` or `info`, the head SHA, and a note that names the class and the proof (run link, SHA, test name).

## In the PR body

If a failure stays after your fixes, the Evidence section names the job, its class and the proof in one line each. Ask the owner before editing the body, unless the PR's standing grant covers body edits (contribution-loop.md, step 12).

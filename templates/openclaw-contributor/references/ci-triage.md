# CI triage

Classify every failing check on the PR's current head before fixing anything or saying anything about it. "Looks unrelated" is not evidence.

## Steps for each failing job

1. Confirm the head: the check must belong to the PR's current `headRefOid`. A result from an older head is old evidence.
2. Get the failure: `gh pr checks <n>`, then `gh run view <run-id> --log-failed`. Save a short excerpt, never the whole log, to `evidence/<slug>/ci/<job>.log`.
3. If the repo provides `pnpm test:ci-failed <pr>`, run it and read its classification. Its `--run` mode reruns the failed tests locally.
4. Compare paths first: list the PR's changed files with `gh pr diff <n> --name-only`. List the failing test files and the source files they import. Note any overlap.
5. Check main: find the same workflow and job on recent `<base>` runs with `gh run list --branch <base> --workflow <workflow>` and `gh run view`. Note whether the same job and test fail there, with the run link and SHA.
6. Run the failing test locally on the PR head, and on the base when the class is in doubt.

## Classes

- **Caused by this change**: the failing test or path overlaps the change, or the test passes on the base and fails on the head. Fix it with the normal red, green and gates steps.
- **Already failing on main**: the same job and test fail on a recent `<base>` run without this change. Give the main run link and SHA. Do not add test or CI changes to chase it; the repo's rules say maintainers track these.
- **Flaky**: the same test passed and failed on the same head SHA, in CI or locally, with no change in between. Give both results. Do not rerun CI to chase green; a rerun is an owner-gated step.
- **Unknown**: none of the above is proven. Say so, with what you checked. Unknown is not unrelated.

Record each with `add-evidence`, kind `ci-classification`, result `fail` or `info`, the head SHA, and a note that names the class and the proof (run link, SHA, test name).

## In the PR body

If a failure stays after your fixes, the Evidence section names the job, its class and the proof in one line each. Ask the owner before editing the body.

# Example: PR body draft

From the same 0.3.0 test run. This is the body file the loop drafts before any approval; it was never posted. The local review in this test used ClawSweeper's local source build with a different model runner than the public Codex route, and the Evidence line says so.

<!-- PR template from openclaw/openclaw origin/main df0d49f58d1 -->

Related: #198360

## What Problem This Solves

Fixes: a scheduled same-session continuation that loses operator authority before it runs fails with only "Session event was abandoned before execution", with no hint of what failed.

## User Impact

User impact: when a queued cron continuation or other session event is canceled after a lost authority check, its failure now names the original error and the failed authority check, so operators can see which condition stopped it. The input is still canceled and never replayed.

## Why This Change Was Made

The followup queue's authority-loss branch rechecks operator authority after a failure. When that check also throws, the branch consumed the input but dropped both errors, so the session event fell back to its generic abandonment text. The branch now passes both causes to the session event's failure callback and adds them to the existing queue log line. Disposition and completion are unchanged.

## Evidence

- Red on base `df0d49f58d1`: new test `keeps both causes when revoked operator input is consumed before execution` in `src/auto-reply/reply/followup-runner.test.ts` fails (`onFailed` called 0 times); the other 28 tests pass. `pnpm test src/auto-reply/reply/followup-runner.test.ts --maxWorkers=1`
- Green with the fix: 29 passed, also at the commit. Mutation check: with the fix reverted the new test fails again for the same reason.
- Consumer tests: the other `followup-runner*` suites and `session-event-handoff.test.ts`, 39 passed.
- Targeted gates: `node scripts/run-oxlint.mjs`, `node scripts/run-format.mts --check` on the 2 files, `pnpm tsgo:core`, `pnpm tsgo:test:src`, `git diff --check`: all pass. Lanes from `pnpm changed:lanes`: core, core tests.
- Local review: ClawSweeper `--local-range` (local source build with a non-Codex model runner), base `df0d49f58d1`, head `bb9222bf6f1`, full committed range, review complete and checkout access verified; outcome: patch correct, no findings, rating C (proof D, patch B) after 1 round; remaining findings: none. Its proof note: no real-behavior proof yet.
- Gap: no end-to-end run of a revoked cron continuation on an isolated Gateway; the proof is the focused unit test at the queue owner.

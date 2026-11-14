// 0.4.2: the packaged PR watcher trigger (references/pr-watch.js).
// Red on 0.4.1 (no packaged watcher; the live hand-written one read r.stdout and never fired), green on 0.4.2.
// Runs the script the way OpenClaw's trigger runtime does: top-level await, exec() returning
// { status, exitCode, aggregated }, and a frozen trigger.state. Usage: node pr-watch.test.mjs <package dir>
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const pkg = process.argv[2];
let passes = 0;
let fails = 0;
const ok = (name, cond, extra = "") => {
  if (cond) { passes++; console.log("PASS " + name); } else { fails++; console.log("FAIL " + name + " " + extra); }
};
const file = join(pkg, "references/pr-watch.js");
if (!existsSync(file)) {
  console.log("FAIL packaged watcher exists (" + file + ")");
  console.log("passed=0 failed=1");
  process.exit(1);
}
const src = readFileSync(file, "utf8");
ok("template has the PR number placeholder once", (src.match(/const pr = 0;/g) || []).length === 1);
const script = src.replace("const pr = 0;", "const pr = 199042;");
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const deepFreeze = (o) => { if (o && typeof o === "object") { Object.values(o).forEach(deepFreeze); Object.freeze(o); } return o; };
const run = (state, fakeExec) => new AsyncFunction("exec", "trigger", script)(fakeExec, { state: state === undefined ? undefined : deepFreeze(JSON.parse(JSON.stringify(state))) });

const base = {
  state: "OPEN", isDraft: false, headRefOid: "c02af35c87d5ee62bf24c39c48eb85a702bbace4",
  labels: [{ name: "size: S" }],
  comments: [{ author: { login: "clawsweeper" }, createdAt: "2026-11-14T17:19:38Z", body: "picked up" }],
  reviews: [],
  statusCheckRollup: [
    { name: "CI", status: "COMPLETED", conclusion: "ACTION_REQUIRED" },
    { name: "lint", status: "IN_PROGRESS", conclusion: "" },
    { context: "openclaw/ci-gate", state: "FAILURE" },
  ],
};
const calls = [];
const execFor = (view) => async (args) => { calls.push(args.command); return { status: "completed", exitCode: 0, aggregated: JSON.stringify(view) }; };
const clone = (o) => JSON.parse(JSON.stringify(o));
const fires = async (state, view) => (await run(state, execFor(view))).fire === true;

const r1 = await run(undefined, execFor(base));
ok("first check saves state and does not fire", r1.fire === false && r1.state && r1.state.observed && r1.state.observed.head === base.headRefOid, JSON.stringify(r1));
const cmd = calls[0];
ok("one plain read-only gh pr view command", /^gh pr view 199042 --repo openclaw\/openclaw --json [a-zA-Z,]+$/.test(cmd), cmd);
ok("command has no shell operators", !/[;&|<>`$'"\\]/.test(cmd), cmd);
ok("exactly one exec call per check", calls.length === 1);
const S = r1.state;

const r2 = await run(S, execFor(base));
ok("unchanged observation does not fire and keeps state", r2.fire === false && r2.message === undefined && r2.state === undefined);

let v = clone(base); v.comments.push({ author: { login: "clawsweeper" }, createdAt: "2026-11-14T18:00:00Z", body: "review" });
const r3 = await run(S, execFor(v));
ok("new ClawSweeper comment fires with a message", r3.fire === true && /PR 199042 changed/.test(r3.message || ""));

v = clone(base); v.comments[0].body = "picked up\n\nReview: rating B";
ok("ClawSweeper comment edited in place fires (body hash)", await fires(S, v));

v = clone(base); v.labels.push({ name: "status: \u{1F440} ready for maintainer look" });
ok("label change fires", await fires(S, v));

v = clone(base); v.statusCheckRollup[0].conclusion = "SUCCESS";
ok("finished check result change fires", await fires(S, v));

v = clone(base); v.statusCheckRollup[1].status = "QUEUED";
ok("an in-progress to queued flip does not fire", !(await fires(S, v)));

v = clone(base); v.statusCheckRollup[1].conclusion = "FAILURE";
ok("an in-progress check that finishes fires", await fires(S, v));

v = clone(base); v.comments.push({ author: { login: "some-maintainer" }, createdAt: "2026-11-14T18:10:00Z", body: "q" });
const rp = await run(S, execFor(v));
ok("a human comment fires and is counted as people", rp.fire === true && rp.state.observed.people[0] === 1);

v = clone(base); v.comments.push({ author: { login: "github-actions" }, createdAt: "2026-11-14T18:11:00Z", body: "x" });
const rb = await run(S, execFor(v));
ok("a bot comment fires and is counted as bots, not people", rb.fire === true && rb.state.observed.bots[0] === 1 && rb.state.observed.people[0] === 0);

v = clone(base); v.reviews.push({ author: { login: "m" }, submittedAt: "2026-11-14T18:20:00Z", state: "COMMENTED" });
ok("a review fires", await fires(S, v));

v = clone(base); v.headRefOid = "d".repeat(40);
ok("new head fires", await fires(S, v));

v = clone(base); v.state = "MERGED";
ok("closed or merged fires", await fires(S, v));

const old = Date.now() - 25 * 60 * 60 * 1000;
const quiet = { observed: S.observed, since: old, nudged: old };
const rq = await run(quiet, execFor(base));
ok("unchanged for 24 hours fires once a day with the day count", rq.fire === true && /not changed for 1 day/.test(rq.message || "") && rq.state.since === old);
const rq2 = await run(rq.state, execFor(base));
ok("the daily nudge does not repeat within the day", rq2.fire === false);
const week = Date.now() - 7 * 24 * 60 * 60 * 1000 - 1000;
const rw = await run({ observed: S.observed, since: week, nudged: Date.now() - 25 * 60 * 60 * 1000 }, execFor(base));
ok("after 7 quiet days the nudge says 7 days", rw.fire === true && /not changed for 7 day/.test(rw.message || ""));

let threw = false;
try { await run(S, async () => ({ status: "completed", exitCode: 1, aggregated: "HTTP 502" })); } catch { threw = true; }
ok("a failed gh read throws instead of going quiet", threw);

ok("state stays under the 16 KB limit", JSON.stringify(r1.state).length < 16000);

// The live 0.4.0 watcher pattern, for the record: reading r.stdout makes every observation identical.
const liveStyle = async (aggregated) => { const r = { status: "completed", exitCode: 0, aggregated }; return String(r.stdout || r).trim(); };
ok("documented: the r.stdout pattern cannot see changes", (await liveStyle("a")) === (await liveStyle("b")));

console.log("passed=" + passes + " failed=" + fails);
process.exit(fails === 0 ? 0 : 1);

// 0.4.3: the watcher's first check saves a baseline and always fires once, naming what is newer than
// the add. Red on 0.4.2 (no addedAt line; the first check only saved, so a ClawSweeper review that
// landed between the add and the first check never woke the agent), green on 0.4.3.
// Runs the script the way OpenClaw's trigger runtime does (see pr-watch.test.mjs).
// Usage: node pr-watch-baseline.test.mjs <package dir>
import { readFileSync } from "node:fs";
import { join } from "node:path";

const pkg = process.argv[2];
let passes = 0;
let fails = 0;
const ok = (name, cond, extra = "") => {
  if (cond) { passes++; console.log("PASS " + name); } else { fails++; console.log("FAIL " + name + " " + extra); }
};
const src = readFileSync(join(pkg, "references/pr-watch.js"), "utf8");
ok("template has the addedAt placeholder once", (src.match(/^const addedAt = "";$/gm) || []).length === 1);
ok("template has the PR number placeholder once", (src.match(/^const pr = 0;$/gm) || []).length === 1);
const ADDED = "2026-11-14T18:00:00Z";
const fill = (added) => src.replace("const pr = 0;", "const pr = 199343;").replace('const addedAt = "";', 'const addedAt = "' + added + '";');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const deepFreeze = (o) => { if (o && typeof o === "object") { Object.values(o).forEach(deepFreeze); Object.freeze(o); } return o; };
const run = (script, state, view) => new AsyncFunction("exec", "trigger", script)(
  async () => ({ status: "completed", exitCode: 0, aggregated: JSON.stringify(view) }),
  { state: state === undefined ? undefined : deepFreeze(JSON.parse(JSON.stringify(state))) },
);
const clone = (o) => JSON.parse(JSON.stringify(o));
const before = "2026-11-14T17:00:00Z";
const after = "2026-11-14T18:05:00Z";
const base = {
  state: "OPEN", isDraft: false, headRefOid: "0ad321660b7afa421dd274409f5b4ecc28e7ea2d",
  labels: [{ name: "size: M" }],
  comments: [{ author: { login: "clawsweeper" }, createdAt: before, body: "picked up" }],
  reviews: [],
  statusCheckRollup: [
    { name: "CI", status: "COMPLETED", conclusion: "ACTION_REQUIRED", completedAt: before },
    { name: "lint", status: "IN_PROGRESS", conclusion: "", completedAt: "0001-01-01T00:00:00Z" },
    { context: "openclaw/ci-gate", state: "FAILURE", startedAt: before },
  ],
};
const S = fill(ADDED);

const r0 = await run(S, undefined, base);
ok("first check with nothing newer still fires once and saves the baseline", r0.fire === true && /baseline saved/.test(r0.message) && /no dated comment, review or check/.test(r0.message) && r0.state && r0.state.observed.head === base.headRefOid, JSON.stringify(r0).slice(0, 200));
const r0b = await run(S, r0.state, base);
ok("second unchanged check does not fire", r0b.fire === false);

let v = clone(base); v.comments.push({ author: { login: "clawsweeper" }, createdAt: after, body: "Codex review: needs real behavior proof before merge." });
let r = await run(S, undefined, v);
ok("first check names a ClawSweeper comment newer than addedAt", r.fire === true && /Newer than the add: ClawSweeper comment/.test(r.message) && /added at 2026-11-14T18:00:00Z/.test(r.message), r.message);
ok("the firing first check still saves the baseline", r.state && r.state.observed && r.state.observed.clawsweeper[0] === 2);
const r1b = await run(S, r.state, v);
ok("after the firing first check, the same observation does not fire again", r1b.fire === false);

v = clone(base); v.comments.push({ author: { login: "some-maintainer" }, createdAt: after, body: "q" });
r = await run(S, undefined, v);
ok("first check names a person's comment newer than addedAt", r.fire === true && /comment by a person/.test(r.message));

v = clone(base); v.reviews.push({ author: { login: "m" }, submittedAt: after, state: "COMMENTED" });
ok("first check names a review newer than addedAt", /review/.test((await run(S, undefined, v)).message));

v = clone(base); v.statusCheckRollup[1] = { name: "lint", status: "COMPLETED", conclusion: "FAILURE", completedAt: after };
r = await run(S, undefined, v);
ok("first check names a check that finished after addedAt", r.fire === true && /finished check/.test(r.message));

v = clone(base); v.state = "MERGED";
ok("first check names a PR that is no longer open", /state MERGED/.test((await run(S, undefined, v)).message));

v = clone(base); v.labels.push({ name: "status: \u{1F4E3} needs proof" });
r = await run(S, undefined, v);
ok("an undated label still wakes the agent on the first check", r.fire === true && /Labels and in-place edits are not dated/.test(r.message));
v = clone(base); v.comments[0].body = "picked up\n\nCodex review: needs real behavior proof";
ok("a ClawSweeper comment edited in place before the first check still wakes the agent", (await run(S, undefined, v)).fire === true);

ok("an in-progress check's zero completedAt is not named as finished", !/finished check/.test((await run(S, undefined, base)).message));
v = clone(base); v.comments.push({ author: { login: "clawsweeper-fan" }, createdAt: after, body: "x" });
r = await run(S, undefined, v);
ok("a look-alike login is not counted as ClawSweeper", r.state.observed.clawsweeper[0] === 1 && r.state.observed.people[0] === 1);
let noZ = false;
try { await run(fill("2026-11-14T18:00:00"), undefined, base); } catch (e) { noZ = /ending in Z/.test(String(e)); }
ok("an addedAt without Z (local time) throws", noZ);

let threw = false;
try { await run(fill("yesterday"), undefined, base); } catch (e) { threw = /addedAt is not an ISO 8601 UTC time/.test(String(e)); }
ok("a malformed addedAt throws instead of going quiet", threw);

v = clone(base); v.comments.push({ author: { login: "some-maintainer" }, createdAt: before, body: "first" });
const h0 = await run(S, undefined, v);
const v2 = clone(v); v2.comments[1].body = "first, edited";
ok("a person's comment edited in place fires on a later check", (await run(S, h0.state, v2)).fire === true);
v = clone(base); v.comments.push({ author: { login: "github-actions-fan" }, createdAt: after, body: "x" });
r = await run(S, undefined, v);
ok("a look-alike bot login is counted as a person, not a bot", r.state.observed.bots[0] === 0 && r.state.observed.people[0] === 1);

const legacy = src.replace("const pr = 0;", "const pr = 199343;");
v = clone(base); v.comments.push({ author: { login: "clawsweeper" }, createdAt: after, body: "review" });
ok("with addedAt left empty the first check only saves (0.4.2 behavior)", (await run(legacy, undefined, v)).fire === false);

const cmds = [];
await new AsyncFunction("exec", "trigger", S)(async (a) => { cmds.push(a.command); return { status: "completed", exitCode: 0, aggregated: JSON.stringify(base) }; }, { state: undefined });
ok("still one plain read-only gh pr view per check", cmds.length === 1 && /^gh pr view 199343 --repo openclaw\/openclaw --json [a-zA-Z,]+$/.test(cmds[0]), cmds.join(" | "));

console.log("passed=" + passes + " failed=" + fails);
process.exit(fails === 0 ? 0 : 1);

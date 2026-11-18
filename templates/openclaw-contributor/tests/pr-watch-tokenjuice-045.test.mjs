// 0.4.5: the watcher survives OpenClaw's tokenjuice exec compaction.
// Red on 0.4.4 (tokenjuice rewrote the plain `gh pr view --json` result into a text summary such as
// "status checks: 26 ok, 3 attention", so every check threw "is not JSON"), green on 0.4.5 (the read is
// piped through base64 and decoded in the check).
// Usage: node pr-watch-tokenjuice-045.test.mjs <package dir> [tokenjuice openclaw extension.js]
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const pkg = process.argv[2];
const tjPath = process.argv[3] ||
  "/Volumes/openclaw/openclaw-b/extensions/tokenjuice/node_modules/tokenjuice/dist/hosts/openclaw/extension.js";
let passes = 0;
let fails = 0;
const ok = (name, cond, extra = "") => {
  if (cond) { passes++; console.log("PASS " + name); } else { fails++; console.log("FAIL " + name + " " + extra); }
};
const src = readFileSync(join(pkg, "references/pr-watch.js"), "utf8");
const script = src.replace("const pr = 0;", "const pr = 200936;");
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const deepFreeze = (o) => { if (o && typeof o === "object") { Object.values(o).forEach(deepFreeze); Object.freeze(o); } return o; };
const run = (state, fakeExec, globals = {}) =>
  new AsyncFunction("exec", "trigger", ...Object.keys(globals), script)(
    fakeExec, { state: state === undefined ? undefined : deepFreeze(JSON.parse(JSON.stringify(state))) }, ...Object.values(globals));
const b64 = (text) => Buffer.from(text).toString("base64");
const wrap76 = (s) => s.match(/.{1,76}/g).join("\n") + "\n";
const clone = (o) => JSON.parse(JSON.stringify(o));
const view = {
  state: "OPEN", isDraft: false, headRefOid: "c02af35c87d5ee62bf24c39c48eb85a702bbace4",
  labels: [{ name: "size: S" }],
  comments: [{ author: { login: "clawsweeper" }, createdAt: "2026-11-18T02:38:28Z", body: "🦞👀 ClawSweeper picked this up. café" }],
  reviews: [],
  statusCheckRollup: [
    { name: "auto-response", status: "COMPLETED", conclusion: "CANCELLED", workflowName: "Auto response" },
    { name: "lint", status: "COMPLETED", conclusion: "SUCCESS", workflowName: "CI" },
    { name: "test", status: "IN_PROGRESS", conclusion: "", workflowName: "CI" },
  ],
};
const throwsWith = async (aggregated, re) => {
  try { await run(undefined, async () => ({ status: "completed", exitCode: 0, aggregated })); return false; }
  catch (e) { return !(e instanceof SyntaxError) && re.test(String(e && e.message)); }
};

// Capture the exact command the watcher runs.
let cmd = "";
await run(undefined, async (a) => { cmd = a.command; return { status: "completed", exitCode: 0, aggregated: b64(JSON.stringify(view)) }; });
ok("watcher pipes its one gh read through base64", / \| base64$/.test(cmd), cmd);

// (a) The real tokenjuice OpenClaw handler, the one that rewrites exec results.
if (!existsSync(tjPath)) {
  console.log("SKIP tokenjuice handler not found at " + tjPath);
} else {
  const { createTokenjuiceOpenClawEmbeddedExtension } = await import(tjPath);
  let handler;
  createTokenjuiceOpenClawEmbeddedExtension()({ on(e, f) { if (e === "tool_result") handler = f; } });
  const through = async (command, out) => {
    const r = await handler(
      { toolName: "exec", input: { command }, content: [{ type: "text", text: out }], details: { status: "completed", exitCode: 0, aggregated: out } },
      { cwd: process.cwd() });
    return r ? r.content.filter((b) => b.type === "text").map((b) => b.text).join("\n") : out;
  };
  const json = JSON.stringify(view);
  const oldCmd = cmd.replace(/ \| base64$/, "");
  const compacted = await through(oldCmd, json);
  let parses = true; try { JSON.parse(compacted); } catch { parses = false; }
  ok("0.4.4 form: tokenjuice turns gh JSON into non-JSON text", !parses && compacted !== json, compacted.slice(0, 120));
  const delivered = await through(cmd, b64(json));
  ok("0.4.5 form: base64 output comes through tokenjuice unchanged", delivered === b64(json));
  const deliveredWrapped = await through(cmd, wrap76(b64(json)));
  ok("0.4.5 form: 76-column base64 also comes through unchanged", deliveredWrapped === wrap76(b64(json)));
  const execVia = (v) => async (a) => ({ status: "completed", exitCode: 0, aggregated: await through(a.command, b64(JSON.stringify(v))) });
  const r1 = await run(undefined, execVia(view));
  ok("first check through tokenjuice saves a baseline without error", r1 && r1.state && r1.state.observed && r1.state.observed.head === view.headRefOid, JSON.stringify(r1).slice(0, 200));
  let v = clone(view); v.labels.push({ name: "status: 👀 ready for maintainer look" });
  const r2 = await run(r1.state, execVia(v));
  ok("label change through tokenjuice fires", r2.fire === true && /changed/.test(r2.message || ""));
  v = clone(view); v.reviews.push({ author: { login: "steipete" }, state: "COMMENTED", submittedAt: "2026-11-18T03:00:00Z", body: "nit" });
  const r3 = await run(r1.state, execVia(v));
  ok("new review through tokenjuice fires", r3.fire === true && /changed/.test(r3.message || ""));
  const r4 = await run(r1.state, execVia(view));
  ok("unchanged PR through tokenjuice does not fire", r4.fire === false);
}

// (b) Decoder: non-ASCII, size, wrapped and unwrapped output, with and without TextDecoder.
const big = clone(view);
big.comments = Array.from({ length: 60 }, (_, i) => ({ author: { login: "person" + i }, createdAt: "2026-11-18T02:40:00Z", body: "é🦞 ".repeat(800) }));
const bigJson = JSON.stringify(big);
ok("large payload is over 150 KB", Buffer.byteLength(bigJson) > 150000, String(Buffer.byteLength(bigJson)));
for (const [label, out] of [["unwrapped (macOS)", b64(bigJson) + "\n"], ["wrapped at 76 (GNU)", wrap76(b64(bigJson))]]) {
  const r = await run(undefined, async () => ({ status: "completed", exitCode: 0, aggregated: out }), {});
  ok("decodes " + label + " 150 KB payload", r && r.state && r.state.observed.people[0] === 60);
}
const rNo = await run(undefined, async () => ({ status: "completed", exitCode: 0, aggregated: b64(bigJson) }), { TextDecoder: undefined });
const hashOf = (r) => r.state.observed.people[2];
const rYes = await run(undefined, async () => ({ status: "completed", exitCode: 0, aggregated: b64(bigJson) }));
ok("decoder without TextDecoder gives the same result", hashOf(rNo) === hashOf(rYes));
for (const n of [1, 2, 3]) {
  const vv = clone(view); vv.comments[0].body = "é🦞".slice(0, n) + "ab".slice(0, n % 3);
  const r = await run(undefined, async () => ({ status: "completed", exitCode: 0, aggregated: b64(JSON.stringify(vv)) }));
  ok("decodes padding case " + n, r && r.state && r.state.observed.head === view.headRefOid);
}

// (c) and (d) Clear errors, never a bare SyntaxError.
ok("invalid base64 throws a clear error", await throwsWith("not*base64!", /is not base64/));
ok("the tokenjuice text summary throws a clear error naming it", await throwsWith("status checks: 26 ok, 3 attention\ncheck auto-response [CANCELLED]", /is not base64.*status checks: 26 ok/));
ok("base64 of non-JSON throws the not-JSON error", await throwsWith(b64("HTTP 502 Bad Gateway"), /is not JSON.*HTTP 502/));

console.log("passed=" + passes + " failed=" + fails);
process.exit(fails ? 1 : 0);

// 0.4.4: the PR dashboard builder (references/pr-dashboard/build.mjs) and its refresh trigger.
// Runs the builder against fixture GraphQL answers from a fake gh on PATH: CHANGED, UNCHANGED,
// a 502 then success, three 502s (ERROR), GraphQL errors, missing fields, an empty result, settings
// checks, and a leak check on the built HTML. Then runs the trigger the way OpenClaw's trigger runtime
// does (top-level await, exec() returning { status, exitCode, aggregated }, frozen trigger.state).
// Red on 0.4.3 (no builder). Usage: node pr-dashboard.test.mjs <package dir>
import { spawnSync } from "node:child_process";
import { chmodSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const pkg = process.argv[2];
let passes = 0;
let fails = 0;
const ok = (name, cond, extra = "") => {
  if (cond) { passes++; console.log("PASS " + name); } else { fails++; console.log("FAIL " + name + " " + String(extra).slice(0, 600)); }
};
const D = join(pkg, "references/pr-dashboard");
for (const f of ["build.mjs", "template.html", "prs.graphql", "ci.graphql", "refresh-trigger.js"]) {
  if (!existsSync(join(D, f))) {
    console.log("FAIL packaged dashboard file exists: references/pr-dashboard/" + f);
    console.log("passed=0 failed=1");
    process.exit(1);
  }
}

const root = mkdtempSync(join(tmpdir(), "occ-dash-"));
process.on("exit", () => rmSync(root, { recursive: true, force: true }));
const ws = join(root, "ws");
const bin = join(root, "bin");
const q = join(root, "queues");
mkdirSync(join(ws, "references"), { recursive: true });
mkdirSync(bin);
mkdirSync(q);
cpSync(D, join(ws, "references/pr-dashboard"), { recursive: true });
// Fake gh: answers from queue files by request kind (prs, ci, user); the last answer repeats.
writeFileSync(join(bin, "gh"), `#!/usr/bin/env node
const fs = require("fs"), path = require("path");
const dir = process.env.FAKE_GH_QUEUES; const a = process.argv.slice(2);
fs.appendFileSync(path.join(dir, "calls.log"), JSON.stringify(a) + "\\n");
const kind = a[0] === "api" && a[1] === "user" ? "user" : (a.find((x) => x.startsWith("query=@")) || "").includes("ci.graphql") ? "ci" : "prs";
const f = path.join(dir, kind + ".json");
if (!fs.existsSync(f)) { process.stderr.write("no fixture for " + kind); process.exit(3); }
const list = JSON.parse(fs.readFileSync(f, "utf8"));
const r = list.length > 1 ? list.shift() : list[0];
fs.writeFileSync(f, JSON.stringify(list));
if (r.stdout) process.stdout.write(typeof r.stdout === "string" ? r.stdout : JSON.stringify(r.stdout));
if (r.stderr) process.stderr.write(r.stderr);
process.exit(r.exit || 0);
`);
chmodSync(join(bin, "gh"), 0o755);

const pr = (n, o = {}) => ({
  number: n, title: "fix(core): thing " + n, url: "https://github.com/openclaw/openclaw/pull/" + n,
  state: "OPEN", merged: false, updatedAt: "2026-11-1" + (n % 10) + "T10:00:00Z", isDraft: false,
  mergeStateStatus: "CLEAN", labels: { nodes: [{ name: "P2" }, { name: "rating: 🥇 gold" }] }, ...o,
});
const prsOk = (open, closed, cost = 1) => ({ stdout: { data: { rateLimit: { cost, remaining: 4999 }, open: { nodes: open }, closed: { nodes: closed } } } });
const ciOk = (nodes) => ({ stdout: { data: { rateLimit: { cost: 1, remaining: 4998 }, open: { nodes } } } });
const ciNode = (n, counts) => ({ number: n, url: "https://github.com/openclaw/openclaw/pull/" + n,
  commits: { nodes: [{ commit: { statusCheckRollup: { state: "FAILURE", contexts: { checkRunCountsByState: counts, statusContextCountsByState: [] } } } }] } });
const OPEN = [pr(101), pr(102, { isDraft: true, title: "docs: explain the thing" })];
const CLOSED = [pr(90, { state: "MERGED", merged: true, updatedAt: "2026-11-05T10:00:00Z" })];
const CI = [ciNode(101, [{ state: "SUCCESS", count: 5 }, { state: "FAILURE", count: 1 }, { state: "IN_PROGRESS", count: 2 }]), ciNode(102, [])];

const queue = (kind, list) => writeFileSync(join(q, kind + ".json"), JSON.stringify(list));
const calls = () => (existsSync(join(q, "calls.log")) ? readFileSync(join(q, "calls.log"), "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const resetCalls = () => rmSync(join(q, "calls.log"), { force: true });
const env = { ...process.env, PATH: bin + ":" + process.env.PATH, FAKE_GH_QUEUES: q };
const build = () => {
  const p = spawnSync(process.execPath, [join(ws, "references/pr-dashboard/build.mjs")], { encoding: "utf8", env });
  const out = (p.stdout || "") + (p.stderr || "");
  return { code: p.status, out, last: out.trim().split("\n").pop() || "" };
};
const settings = (author, org = "openclaw") => writeFileSync(join(ws, "settings.md"),
  "# Settings\n\n## PR dashboard\n\n- dashboard: on\n- dashboard_author: " + author + "\n  - note\n- dashboard_org: " + org + "\n");
const data = () => JSON.parse(readFileSync(join(ws, "dashboard/data.json"), "utf8"));
const html = () => readFileSync(join(ws, "dashboard/widget.html"), "utf8");
const localDate = (d) => d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");

// 1. First build: author from gh api user, CHANGED.
settings("<blank, uses your gh login>");
queue("user", [{ stdout: "test-user\n" }]);
queue("prs", [prsOk(OPEN, CLOSED)]);
queue("ci", [ciOk(CI)]);
let b = build();
ok("first build prints CHANGED with rows, cost and remaining", b.code === 0 && b.last === "CHANGED rows=3 cost=2 remaining=4998", b.out);
let c = calls();
ok("author comes from gh api user when dashboard_author is blank", c.some((a) => a.join(" ") === "api user --jq .login"), JSON.stringify(c));
const prsCall = c.find((a) => a.some((x) => x.includes("prs.graphql"))) || [];
const since = new Date(); since.setDate(since.getDate() - 14);
ok("open search is org, author, is:pr, is:open (as a raw -f string)", prsCall.includes("-f") && prsCall.includes("open=org:openclaw author:test-user is:pr is:open"), JSON.stringify(prsCall));
ok("closed search covers the last 14 days", prsCall.includes("closed=org:openclaw author:test-user is:pr is:closed closed:>=" + localDate(since)), JSON.stringify(prsCall));
ok("exactly three gh calls (user, prs, ci)", c.length === 3, JSON.stringify(c));
ok("every gh call is a read (api user or api graphql, no method or input flags)",
  c.every((a) => a[0] === "api" && (a[1] === "user" || a[1] === "graphql") && !a.some((x) => /^(-X|--method|--input)$/.test(x))), JSON.stringify(c));
let d = data();
ok("data.json has digest, days, rows, fetchedAt, cost, remaining in that order",
  JSON.stringify(Object.keys(d)) === JSON.stringify(["digest", "days", "rows", "fetchedAt", "cost", "remaining"]), JSON.stringify(Object.keys(d)));
ok("rows sorted by updated, newest first", d.rows.map((r) => r.n).join(",") === "102,101,90", d.rows.map((r) => r.n).join(","));
const r101 = d.rows.find((r) => r.n === 101), r102 = d.rows.find((r) => r.n === 102), r90 = d.rows.find((r) => r.n === 90);
ok("CI counts: total, fail, pending", JSON.stringify(r101.ci) === '{"total":8,"fail":1,"pend":2}', JSON.stringify(r101.ci));
ok("draft PR gets ms draft, clean PR ms clean", r102.ms === "draft" && r101.ms === "clean");
ok("closed PR has no CI and keeps merged", r90.ci === null && r90.merged === true);
ok("short falls back to the cleaned title", r101.short === "Thing 101" && r102.short === "Explain the thing", r101.short + " / " + r102.short);
ok("row keys match the earlier builder", JSON.stringify(Object.keys(r101)) === JSON.stringify(["n", "title", "url", "state", "merged", "updated", "ms", "labels", "ci", "short", "repo"]));
ok("fetchedAt is UTC to the second with +00:00", /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\+00:00$/.test(d.fetchedAt), d.fetchedAt);
ok("data.json is written in Python's default JSON layout (ASCII, ', ' and ': ')",
  readFileSync(join(ws, "dashboard/data.json"), "utf8").includes('"labels": ["P2", "rating: \\ud83e\\udd47 gold"]'));
let h = html();
ok("widget.html embeds the data", h.includes('const DATA={"days":14,"rows":[') && !h.includes("/*DATA*/null"));
ok("widget.html keeps emoji as real characters", h.includes("rating: 🥇 gold"));
ok("no job id yet: JOB is empty and Refresh explains it", h.includes("const JOB='';") && h.includes("no refresh automation yet"));

// 2. Same answers again: UNCHANGED.
resetCalls();
b = build();
ok("same data prints UNCHANGED", b.code === 0 && b.last === "UNCHANGED rows=3 cost=2 remaining=4998", b.out);

// 3. Agent-maintained short.json and job id.
writeFileSync(join(ws, "dashboard/short.json"), JSON.stringify({ "https://github.com/openclaw/openclaw/pull/101": "Faster thing loading" }));
writeFileSync(join(ws, "dashboard/jobid.txt"), "0f8a3c2e-1111-4222-8333-944455556666\n");
b = build();
ok("a new short.json entry changes the rows (CHANGED)", b.last.startsWith("CHANGED"), b.out);
ok("short.json summary is used", data().rows.find((r) => r.n === 101).short === "Faster thing loading");
ok("job id goes into the widget", html().includes("const JOB='0f8a3c2e-1111-4222-8333-944455556666';"));
writeFileSync(join(ws, "dashboard/jobid.txt"), "x';alert(1);'\n");
b = build();
ok("a job id with other characters is refused", b.code === 1 && /^ERROR .*jobid\.txt/.test(b.last), b.out);
writeFileSync(join(ws, "dashboard/jobid.txt"), "0f8a3c2e-1111-4222-8333-944455556666\n");
writeFileSync(join(ws, "dashboard/short.json"), "{not json");
b = build();
ok("broken short.json is an ERROR, not a silent reset", b.code === 1 && /^ERROR .*short\.json/.test(b.last), b.out);
writeFileSync(join(ws, "dashboard/short.json"), JSON.stringify({ "https://github.com/openclaw/openclaw/pull/101": "Faster thing loading" }));

// 4. 502 then success: retried, builds.
const digestBefore = data().digest;
resetCalls();
queue("prs", [{ exit: 1, stderr: "HTTP 502: Bad Gateway (https://api.github.com/graphql)" }, prsOk(OPEN, CLOSED)]);
queue("ci", [{ exit: 1, stderr: "HTTP 504: Gateway Timeout" }, ciOk(CI)]);
b = build();
ok("502 then success is retried and builds", b.code === 0 && b.last.startsWith("UNCHANGED"), b.out);
c = calls();
ok("each failed call was tried again (2 prs, 2 ci)", c.filter((a) => a.some((x) => x.includes("prs.graphql"))).length === 2 && c.filter((a) => a.some((x) => x.includes("ci.graphql"))).length === 2, JSON.stringify(c.length));

// 5. Three 502s: ERROR, exit 1, data.json not replaced.
resetCalls();
queue("prs", [{ exit: 1, stderr: "HTTP 502: Bad Gateway" }]);
b = build();
ok("three failures print ERROR on the last line and exit 1", b.code === 1 && /^ERROR Error: HTTP 502: Bad Gateway/.test(b.last), b.out);
ok("gh was tried three times, then stopped", calls().filter((a) => a.some((x) => x.includes("prs.graphql"))).length === 3);
ok("an ERROR leaves data.json as it was", data().digest === digestBefore);

// 6. GraphQL errors in a 200 answer.
queue("prs", [{ stdout: { errors: [{ message: "Something went wrong while executing your query." }] } }]);
b = build();
ok("GraphQL errors are an ERROR", b.code === 1 && /^ERROR .*Something went wrong/.test(b.last), b.out);
queue("prs", [{ stdout: "<html>502</html>" }]);
b = build();
ok("non-JSON gh output is an ERROR", b.code === 1 && /^ERROR .*not JSON/.test(b.last), b.out);
queue("prs", [{ stdout: { data: { rateLimit: { cost: 1, remaining: 1 } } } }]);
b = build();
ok("an answer without the search is an ERROR", b.code === 1 && /^ERROR .*open\.nodes/.test(b.last), b.out);

// 7. Missing fields.
queue("prs", [{ stdout: { data: { open: { nodes: [null, {}, { number: 7, url: "https://github.com/openclaw/crabbox/pull/7", title: "feat: x", state: "OPEN" }] }, closed: { nodes: [] } } } }]);
queue("ci", [{ stdout: { data: { open: { nodes: [{ number: 7, url: "https://github.com/openclaw/crabbox/pull/7" }] } } } }]);
b = build();
ok("missing fields still build (empty nodes skipped)", b.code === 0 && /^CHANGED rows=1 cost=0 remaining=null$/.test(b.last), b.out);
const r7 = data().rows[0] || {};
ok("missing labels, merge state, commits: defaults", JSON.stringify(r7.labels) === "[]" && r7.ms === "unknown" && r7.ci === null && r7.merged === false && r7.repo === "crabbox", JSON.stringify(r7));

// 8. Empty result.
queue("prs", [prsOk([], [])]);
queue("ci", [ciOk([])]);
b = build();
ok("empty result prints CHANGED rows=0", b.code === 0 && b.last === "CHANGED rows=0 cost=2 remaining=4998", b.out);
ok("empty result widget embeds no rows", html().includes('const DATA={"days":14,"rows":[],"fetchedAt":"'));
b = build();
ok("empty result again prints UNCHANGED", b.last === "UNCHANGED rows=0 cost=2 remaining=4998", b.out);

// 9. Settings: explicit author and org, and refusal of anything else.
resetCalls();
settings("some-one", "some-org");
b = build();
c = calls();
ok("dashboard_author and dashboard_org from settings.md are used, no gh api user",
  !c.some((a) => a[1] === "user") && c.some((a) => a.includes("open=org:some-org author:some-one is:pr is:open")), JSON.stringify(c));
resetCalls();
settings("x y:z");
b = build();
ok("an author that is not a login is an ERROR before any GraphQL call", b.code === 1 && /dashboard_author/.test(b.last) && !calls().some((a) => a[1] === "graphql"), b.out);
settings("some-one", "bad org");
b = build();
ok("an org that is not a login is an ERROR", b.code === 1 && /dashboard_org/.test(b.last), b.out);
rmSync(join(ws, "settings.md"));
resetCalls();
queue("user", [{ stdout: "test-user\n" }]);
b = build();
ok("no settings.md: gh login and org openclaw", b.code === 0 && calls().some((a) => a.includes("open=org:openclaw author:test-user is:pr is:open")), b.out);

// 10. Leak check and script safety on the built HTML.
settings("<blank>");
const evil = pr(103, { title: "fix: </script><script>alert(1)</script> & \"quotes\"" });
queue("prs", [prsOk([evil, ...OPEN], CLOSED)]);
queue("ci", [ciOk(CI)]);
b = build();
h = html();
ok("leak check build ran", b.code === 0, b.out);
ok("built HTML has one closing script tag (titles cannot end the script)", h.split("</script>").length === 2 && h.includes("<\\/script>"));
ok("built HTML names no local path", !h.includes(ws) && !h.includes(root) && !/\/Users\/|\/home\/[a-z]|[A-Z]:\\\\/.test(h));
ok("built HTML has no network calls (fetch, XHR, WebSocket, api.github.com)", !/fetch\(|XMLHttpRequest|WebSocket|EventSource|api\.github\.com|sendBeacon/.test(h));
ok("built HTML uses no host API but cron.trigger", (h.match(/openclaw\.[a-z]+/g) || []).every((m) => m === "openclaw.cron") && !/data\.read|prompt\.send|sendPrompt|action\.run|workboard/.test(h));
ok("built HTML has no em dash", !h.includes("\u2014"));
ok("built HTML links open in a new tab without referrer", h.includes('target="_blank" rel="noopener noreferrer"'));
ok("built HTML has no hostnames or private addresses", !/192\.168\.|10\.\d+\.\d+\.|\.local\b|\.arpa\b|localhost|127\.0\.0\.1/.test(h));
const scripts = [...h.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
let parsed = scripts.length === 1;
try { for (const s of scripts) new Function(s); } catch (e) { parsed = false; console.log(e.message); }
ok("the inline script parses (show_widget rejects a broken script)", parsed);

// 11. Python JSON layout helper.
const mod = await import(pathToFileURL(join(ws, "references/pr-dashboard/build.mjs")).href);
ok("pyDumps matches Python json.dumps(sort_keys=True)", mod.pyDumps({ b: 1, a: "é🟢\n\"\\", c: [true, null] }, true) === '{"a": "\\u00e9\\ud83d\\udfe2\\n\\"\\\\", "b": 1, "c": [true, null]}', mod.pyDumps({ b: 1, a: "é🟢\n\"\\", c: [true, null] }, true));
ok("plainTitle strips the type prefix and capitalizes", mod.plainTitle("fix(acp)!: configured binding") === "Configured binding" && mod.plainTitle("Already plain") === "Already plain");

// 12. Refresh trigger, as OpenClaw runs it.
const tsrc = readFileSync(join(D, "refresh-trigger.js"), "utf8");
ok("trigger has the workspace placeholder once", (tsrc.match(/const workspace = "";/g) || []).length === 1);
ok("trigger reads aggregated, never stdout", tsrc.includes("r.aggregated") && !/\.stdout|\.output\b/.test(tsrc));
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const deepFreeze = (o) => { if (o && typeof o === "object") { Object.values(o).forEach(deepFreeze); Object.freeze(o); } return o; };
const runT = (src, state, fakeExec) => new AsyncFunction("exec", "trigger", src)(fakeExec, { state: state === undefined ? undefined : deepFreeze(JSON.parse(JSON.stringify(state))) });
const tcalls = [];
const said = (text, status = "completed", exitCode = 0) => async (a) => { tcalls.push(a.command); return { status, exitCode, aggregated: text }; };
let threw = "";
try { await runT(tsrc, undefined, said("UNCHANGED rows=1")); } catch (e) { threw = e.message; }
ok("trigger refuses an empty workspace line", /absolute path/.test(threw), threw);
const T = tsrc.replace('const workspace = "";', 'const workspace = "' + ws + '";');
let t = await runT(T, undefined, said("UNCHANGED rows=3 cost=2 remaining=4998"));
ok("UNCHANGED does not wake the model", t.fire === false && t.state.last.startsWith("UNCHANGED"), JSON.stringify(t));
ok("one plain node command per check, no shell operators", tcalls.length === 1 && tcalls[0] === "node " + ws + "/references/pr-dashboard/build.mjs" && !/[;&|<>`$'"\\]/.test(tcalls[0]), tcalls[0]);
t = await runT(T, { last: "UNCHANGED" }, said("CHANGED rows=4 cost=2 remaining=4990"));
ok("CHANGED wakes the model with the line", t.fire === true && t.message === "PR dashboard builder: CHANGED rows=4 cost=2 remaining=4990");
t = await runT(T, { last: "UNCHANGED" }, said("some log\nERROR Error: HTTP 502: Bad Gateway", "completed", 1));
ok("a new ERROR wakes the model once", t.fire === true && /ERROR Error: HTTP 502/.test(t.message), JSON.stringify(t));
t = await runT(T, t.state, said("ERROR Error: HTTP 502: Bad Gateway", "completed", 1));
ok("the same ERROR again does not wake it", t.fire === false && t.state.last.startsWith("ERROR"));
t = await runT(T, t.state, said("ERROR Error: time budget used up", "completed", 1));
ok("a different ERROR wakes it", t.fire === true);
t = await runT(T, { last: "UNCHANGED" }, async () => ({ status: "completed", exitCode: 0, stdout: "UNCHANGED rows=1" }));
ok("no aggregated text counts as an error, not as UNCHANGED", t.fire === true && /no output/.test(t.message), JSON.stringify(t));
threw = "";
try { await runT(T, undefined, said("", "denied", null)); } catch (e) { threw = e.message; }
ok("a denied or failed exec throws (shows in run diagnostics, no model turn)", /did not run \(denied\)/.test(threw), threw);
// End to end: the trigger runs the real builder.
queue("prs", [prsOk(OPEN, CLOSED)]);
queue("ci", [ciOk(CI)]);
const realExec = async (a) => {
  const [cmd, ...args] = a.command.split(" ");
  const p = spawnSync(cmd === "node" ? process.execPath : cmd, args, { encoding: "utf8", env });
  return { status: "completed", exitCode: p.status, aggregated: (p.stdout || "") + (p.stderr || "") };
};
t = await runT(T, undefined, realExec);
ok("end to end: changed data wakes the model", t.fire === true && /CHANGED rows=3/.test(t.message), JSON.stringify(t));
t = await runT(T, t.state, realExec);
ok("end to end: the next quiet check does not", t.fire === false, JSON.stringify(t));

console.log("passed=" + passes + " failed=" + fails);
process.exit(fails ? 1 : 0);

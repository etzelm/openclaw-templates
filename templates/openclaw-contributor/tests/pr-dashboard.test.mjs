// 0.4.4: the PR dashboard builder (references/pr-dashboard/build.mjs) and its refresh trigger.
// Runs the builder against fixture GraphQL answers from a fake gh on PATH: CHANGED, PINNED then UNCHANGED,
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
  mergeStateStatus: "CLEAN", labels: { nodes: [{ name: "P2" }, { name: "rating: 🥇 gold" }, { name: "size: S" }, { name: "status: 👀 ready for maintainer look" }] }, ...o,
});
const prsOk = (open, closed, cost = 1) => ({ stdout: { data: { rateLimit: { cost, remaining: 4999 }, open: { nodes: open }, closed: { nodes: closed } } } });
const ciOk = (nodes) => ({ stdout: { data: { rateLimit: { cost: 1, remaining: 4998 }, open: { nodes } } } });
const ciNode = (n, counts, statuses = []) => ({ number: n, url: "https://github.com/openclaw/openclaw/pull/" + n,
  commits: { nodes: [{ commit: { status: { contexts: statuses }, statusCheckRollup: { state: "FAILURE", contexts: { checkRunCountsByState: counts } } } }] } });
const OPEN = [pr(101), pr(102, { isDraft: true, title: "docs: explain the thing" })];
const CLOSED = [pr(90, { state: "MERGED", merged: true, updatedAt: "2026-11-05T10:00:00Z" })];
const CI = [ciNode(101, [{ state: "SUCCESS", count: 5 }, { state: "FAILURE", count: 1 }, { state: "IN_PROGRESS", count: 2 }, { state: "CANCELLED", count: 3 }, { state: "SKIPPED", count: 4 }],
  [{ context: "openclaw/ci-gate", state: "PENDING", description: "PR #101: a maintainer must approve the workflows" }, { context: "other", state: "ERROR", description: "" }]), ciNode(102, [])];

const clone2 = (o) => JSON.parse(JSON.stringify(o));
const queue = (kind, list) => writeFileSync(join(q, kind + ".json"), JSON.stringify(list));
const calls = () => (existsSync(join(q, "calls.log")) ? readFileSync(join(q, "calls.log"), "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const resetCalls = () => rmSync(join(q, "calls.log"), { force: true });
const env = { ...process.env, PATH: bin + ":" + process.env.PATH, FAKE_GH_QUEUES: q };
const markPinned = (digest) => spawnSync(process.execPath, [join(ws, "references/pr-dashboard/build.mjs"), "--mark-pinned", ...(digest === undefined ? [JSON.parse(readFileSync(join(ws, "dashboard/data.json"), "utf8")).digest.slice(0, 12)] : digest ? [digest] : [])], { encoding: "utf8", env });
const RL = /^(CHANGED|UNCHANGED) rows=\d+ cost=\d+ remaining=\S+ digest=[0-9a-f]{12}$/;
const build = () => {
  const p = spawnSync(process.execPath, [join(ws, "references/pr-dashboard/build.mjs")], { encoding: "utf8", env });
  const out = (p.stdout || "") + (p.stderr || "");
  return { code: p.status, out, last: out.trim().split("\n").pop() || "" };
};
const settings = (author, org = "openclaw", refresh = "off") => writeFileSync(join(ws, "settings.md"),
  "# Settings\n\n## PR dashboard\n\n- dashboard: on\n- dashboard_author: " + author + "\n  - note\n- dashboard_org: " + org + "\n- dashboard_refresh_button: " + refresh + "\n");
const data = () => JSON.parse(readFileSync(join(ws, "dashboard/data.json"), "utf8"));
const html = () => readFileSync(join(ws, "dashboard/widget.html"), "utf8");
const localDate = (d) => d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");

// 1. First build: author from gh api user, CHANGED.
settings("<blank, uses your gh login>");
queue("user", [{ stdout: "test-user\n" }]);
queue("prs", [prsOk(OPEN, CLOSED)]);
queue("ci", [ciOk(CI)]);
let b = build();
ok("first build prints CHANGED with rows, cost and remaining", b.code === 0 && b.last.startsWith("CHANGED rows=3 cost=2 remaining=4998 digest=") && RL.test(b.last), b.out);
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
ok("CI summary: failed, pending, passed, skipped, cancelled, gate state and description", JSON.stringify(r101.ci) === '{"f":2,"p":2,"ok":5,"sk":4,"cx":3,"g":"PENDING","gd":"a maintainer must approve the workflows"}', JSON.stringify(r101.ci));
ok("CI with no checks is an empty summary, not null", JSON.stringify(r102.ci) === "{}", JSON.stringify(r102.ci));
ok("labels are filtered to what the widget reads", JSON.stringify(r101.labels) === JSON.stringify(["P2", "rating: 🥇 gold", "status: 👀 ready for maintainer look"]) && JSON.stringify(r90.labels) === JSON.stringify(["P2", "rating: 🥇 gold"]), JSON.stringify([r101.labels, r90.labels]));
ok("draft PR gets ms draft, clean PR ms clean", r102.ms === "draft" && r101.ms === "clean");
ok("closed PR has no CI and no merge state", r90.ci === null && r90.ms === null && r90.state === "MERGED");
ok("no summary yet: short is null (the widget shows the cleaned title)", r101.short === null && r102.short === null);
ok("row keys match the earlier builder", JSON.stringify(Object.keys(r101)) === JSON.stringify(["n", "title", "url", "state", "updated", "ms", "labels", "ci", "short"]));
ok("fetchedAt is UTC to the second with +00:00", /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\+00:00$/.test(d.fetchedAt), d.fetchedAt);
ok("data.json is written in Python's default JSON layout (ASCII, ', ' and ': ')",
  readFileSync(join(ws, "dashboard/data.json"), "utf8").includes('"labels": ["P2", "rating: \\ud83e\\udd47 gold"], "ci": null'));
let h = html();
const payloadText = (h.match(/<script type="application\/json" id="d">([\s\S]*?)<\/script>/) || [])[1] || "";
ok("widget.html embeds the compact data", payloadText.startsWith('{"d":14,"at":"') && !h.includes("__DATA__"), payloadText.slice(0, 80));
ok("one row per line in the embedded data (no line over 1000 characters)", payloadText.split("\n").length === 3 + 2 && payloadText.split("\n").every((l) => l.length < 1000) && h.split("\n").every((l) => l.length < 2000), payloadText.split("\n").length);
const crcIn = Number((h.match(/const CRC=Number\('(\d+)'\);/) || [])[1]);
const modEarly = await import(pathToFileURL(join(ws, "references/pr-dashboard/build.mjs")).href);
ok("the CRC in the widget matches its data", crcIn === modEarly.crc32(payloadText), crcIn + " vs " + modEarly.crc32(payloadText));
const payload = JSON.parse(payloadText);
const p101 = payload.rows.find((x) => x.n === 101) || {};
ok("compact rows: no h without a summary, no r or url for the main repo", !("h" in p101) && !("r" in p101) && !("url" in p101) && p101.s === "O" && p101.m === "clean", JSON.stringify(p101));
ok("widget.html keeps emoji as real characters", h.includes("rating: 🥇 gold"));
ok("no job id yet: JOB is empty, the Refresh button hides, damage notes say to ask the agent", h.includes("const JOB='';") && h.includes("if(!JOB)$('refresh').style.display='none';") && h.includes("'ask the agent to pin the dashboard again'"));

// 2. Not pinned yet: still CHANGED. After --mark-pinned: UNCHANGED.
b = build();
ok("until the widget is marked pinned, the same data stays CHANGED (a failed pin is retried)", b.code === 0 && b.last.startsWith("CHANGED rows=3"), b.out);
resetCalls();
const bare = markPinned("");
ok("--mark-pinned without a digest is refused", bare.status === 1 && /needs the digest/.test(bare.stdout), bare.stdout);
const wrong = markPinned("0123456789ab");
ok("--mark-pinned with another build's digest is refused and records nothing", wrong.status === 1 && /changed since that build/.test(wrong.stdout) && !existsSync(join(ws, "dashboard/pinned.txt")), wrong.stdout);
ok("the result line's digest is the start of data.json's digest", data().digest.startsWith(b.last.split("digest=")[1]));
const mp = markPinned(b.last.split("digest=")[1]);
ok("--mark-pinned prints PINNED and calls no gh", mp.status === 0 && /^PINNED [0-9a-f]{12}$/.test(mp.stdout.trim()) && calls().length === 0, mp.stdout + mp.stderr);
ok("pinned.txt holds the data.json digest", readFileSync(join(ws, "dashboard/pinned.txt"), "utf8").trim() === data().digest);
resetCalls();
b = build();
ok("same data after the pin prints UNCHANGED", b.code === 0 && b.last.startsWith("UNCHANGED rows=3 cost=2 remaining=4998 digest="), b.out);
const later = clone2(OPEN); later[0].updatedAt = "2026-11-11T23:59:00Z";
queue("prs", [prsOk(later, CLOSED)]);
b = build();
ok("a new time on the same day does not count as a change", b.last.startsWith("UNCHANGED"), b.out);
const unk = clone2(OPEN); unk[0].mergeStateStatus = "UNKNOWN";
queue("prs", [prsOk(unk, CLOSED)]);
b = build();
ok("merge state UNKNOWN keeps the last known value", data().rows.find((r) => r.n === 102).ms === "draft" && data().rows.find((r) => r.n === 101).ms === "clean" && b.last.startsWith("UNCHANGED"), b.out);
queue("prs", [prsOk(OPEN, CLOSED)]);

// 3. Agent-maintained short.json and job id.
writeFileSync(join(ws, "dashboard/short.json"), JSON.stringify({ "https://github.com/openclaw/openclaw/pull/101": "Faster thing loading" }));
writeFileSync(join(ws, "dashboard/jobid.txt"), "0f8a3c2e-1111-4222-8333-944455556666\n");
b = build();
ok("a new short.json entry changes the rows (CHANGED)", b.last.startsWith("CHANGED"), b.out);
ok("Refresh button off (default): the job id stays out of the widget", html().includes("const JOB='';"));
settings("<blank>", "openclaw", "on");
ok("short.json summary is used", data().rows.find((r) => r.n === 101).short === "Faster thing loading" && html().includes('"h":"Faster thing loading"'));
b = build();
ok("Refresh button on: the job id goes into the widget", html().includes("const JOB='0f8a3c2e-1111-4222-8333-944455556666';"), b.out);
ok("the job id does not change the digest (no re-pin just for the button)", b.last.startsWith("CHANGED"));
writeFileSync(join(ws, "dashboard/jobid.txt"), "x';alert(1);'\n");
b = build();
ok("a job id with other characters is refused", b.code === 1 && /^ERROR .*jobid\.txt/.test(b.last), b.out);
writeFileSync(join(ws, "dashboard/jobid.txt"), "0f8a3c2e-1111-4222-8333-944455556666\n");
writeFileSync(join(ws, "dashboard/short.json"), "{not json");
b = build();
ok("broken short.json is an ERROR, not a silent reset", b.code === 1 && /^ERROR .*short\.json/.test(b.last), b.out);
writeFileSync(join(ws, "dashboard/short.json"), JSON.stringify({ "https://github.com/openclaw/openclaw/pull/101": "Faster thing loading" }));

// 4. 502 then success: retried, builds.
markPinned();
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
ok("missing fields still build (empty nodes skipped)", b.code === 0 && /^CHANGED rows=1 cost=0 remaining=null digest=[0-9a-f]{12}$/.test(b.last), b.out);
const r7 = data().rows[0] || {};
ok("missing labels, merge state, commits: defaults", JSON.stringify(r7.labels) === "[]" && r7.ms === "unknown" && r7.ci === null, JSON.stringify(r7));
ok("a PR in another repo carries r in the payload", html().includes('"r":"crabbox"'));

// 8. Empty result.
queue("prs", [prsOk([], [])]);
queue("ci", [ciOk([])]);
b = build();
ok("empty result prints CHANGED rows=0", b.code === 0 && b.last.startsWith("CHANGED rows=0 cost=2 remaining=4998 digest="), b.out);
ok("empty result widget embeds no rows", /id="d">\{"d":14,"at":"[^"]+","rows":\[\]\}<\/script>/.test(html()), html().slice(html().indexOf('id="d"'), html().indexOf('id="d"') + 120));
markPinned();
b = build();
ok("empty result again, after the pin, prints UNCHANGED", b.last.startsWith("UNCHANGED rows=0 cost=2 remaining=4998 digest="), b.out);

// 9. Settings: explicit author and org, and refusal of anything else.
resetCalls();
settings("some-one", "some-org");
b = build();
c = calls();
ok("dashboard_author and dashboard_org from settings.md are used, no gh api user",
  !c.some((a) => a[1] === "user") && c.some((a) => a.includes("open=org:some-org author:some-one is:pr is:open")), JSON.stringify(c));
ok("another org goes into the payload as o", html().includes(',"o":"some-org"}'));
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
ok("built HTML has two closing script tags (titles cannot end a script)", h.split("</script>").length === 3 && h.includes("\\u003c/script>") && !/[^\\]u003c|<script>alert/.test(h.replace(/\\u003c/g, "")));
ok("built HTML names no local path", !h.includes(ws) && !h.includes(root) && !/\/Users\/|\/home\/[a-z]|[A-Z]:\\\\/.test(h));
ok("built HTML has no network calls (fetch, XHR, WebSocket, api.github.com)", !/fetch\(|XMLHttpRequest|WebSocket|EventSource|api\.github\.com|sendBeacon/.test(h));
ok("built HTML uses no host API but cron.trigger", (h.match(/openclaw\.[a-z]+/g) || []).every((m) => m === "openclaw.cron") && !/data\.read|prompt\.send|sendPrompt|action\.run|workboard/.test(h));
ok("built HTML has no em dash", !h.includes("\u2014"));
ok("built HTML links open in a new tab without referrer", h.includes('target="_blank" rel="noopener noreferrer"'));
ok("built HTML has no hostnames or private addresses", !/192\.168\.|10\.\d+\.\d+\.|\.local\b|\.arpa\b|localhost|127\.0\.0\.1/.test(h));
const scripts = [...h.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
let pj = false;
try { pj = JSON.parse((h.match(/id="d">([\s\S]*?)<\/script>/) || [])[1]).rows.some((x) => x.t.includes("</script>")); } catch (e) { console.log(e.message); }
ok("the escaped title survives JSON.parse", pj);
let parsed = scripts.length === 1;
try { for (const s of scripts) new Function(s); } catch (e) { parsed = false; console.log(e.message); }
ok("the inline script parses (show_widget rejects a broken script)", parsed);

// 11. Python JSON layout helper.
const mod = await import(pathToFileURL(join(ws, "references/pr-dashboard/build.mjs")).href);
ok("pyDumps matches Python json.dumps(sort_keys=True)", mod.pyDumps({ b: 1, a: "é🟢\n\"\\", c: [true, null] }, true) === '{"a": "\\u00e9\\ud83d\\udfe2\\n\\"\\\\", "b": 1, "c": [true, null]}', mod.pyDumps({ b: 1, a: "é🟢\n\"\\", c: [true, null] }, true));
ok("crc32 matches the standard check value", mod.crc32("123456789") === 0xcbf43926);
ok("the widget shows the cleaned title when there is no summary", h.includes("short:x.h||plainTitle(x.t)") && h.includes("const plainTitle=t=>"));

// 12. Refresh trigger, as OpenClaw runs it.
const tsrc = readFileSync(join(D, "refresh-trigger.js"), "utf8");
ok("trigger has the workspace placeholder once", (tsrc.match(/const workspace = "";/g) || []).length === 1);
ok("trigger reads aggregated, never stdout", tsrc.includes("r.aggregated") && !/\.stdout|\.output\b/.test(tsrc));
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const deepFreeze = (o) => { if (o && typeof o === "object") { Object.values(o).forEach(deepFreeze); Object.freeze(o); } return o; };
const runT = (src, state, fakeExec) => new AsyncFunction("exec", "trigger", src)(fakeExec, { state: state === undefined ? undefined : deepFreeze(JSON.parse(JSON.stringify(state))) });
const tcalls = [];
// Like OpenClaw's exec: a non-zero exit appends "(Command exited with code N)" to aggregated.
const said = (text, status = "completed", exitCode = 0) => async (a) => { tcalls.push(a.command); return { status, exitCode, aggregated: text + (exitCode ? "\n\n(Command exited with code " + exitCode + ")" : "") }; };
let threw = "";
try { await runT(tsrc, undefined, said("UNCHANGED rows=1")); } catch (e) { threw = e.message; }
ok("trigger refuses an empty workspace line", /absolute path/.test(threw), threw);
const T = tsrc.replace('const workspace = "";', 'const workspace = "' + ws + '";');
let t = await runT(T, undefined, said("UNCHANGED rows=3 cost=2 remaining=4998"));
ok("UNCHANGED does not wake the model", t.fire === false && t.state.last.startsWith("UNCHANGED"), JSON.stringify(t));
ok("one plain node command per check, no shell operators", tcalls.length === 1 && tcalls[0] === "node " + ws + "/references/pr-dashboard/build.mjs" && !/[;&|<>`$'"\\]/.test(tcalls[0]), tcalls[0]);
t = await runT(T, { last: "UNCHANGED" }, said("CHANGED rows=4 cost=2 remaining=4990 digest=aaaaaaaaaaaa"));
ok("CHANGED wakes the model with the line", t.fire === true && t.message === "PR dashboard builder: CHANGED rows=4 cost=2 remaining=4990 digest=aaaaaaaaaaaa");
let cs = t.state;
for (let i = 2; i <= 3; i++) { t = await runT(T, cs, said("CHANGED rows=4 cost=2 remaining=4980 digest=aaaaaaaaaaaa")); cs = t.state; }
ok("the same unpinned table wakes it up to 3 times", t.fire === true && cs.tries === 3, JSON.stringify(cs));
t = await runT(T, cs, said("CHANGED rows=4 cost=2 remaining=4970 digest=aaaaaaaaaaaa"));
ok("the 4th try within the hour does not wake it", t.fire === false, JSON.stringify(t));
t = await runT(T, { ...cs, woke: Date.now() - 61 * 60 * 1000 }, said("CHANGED rows=4 cost=2 remaining=4960 digest=aaaaaaaaaaaa"));
ok("after an hour it tries again", t.fire === true);
t = await runT(T, cs, said("CHANGED rows=5 cost=2 remaining=4950 digest=bbbbbbbbbbbb"));
ok("a different table wakes it at once", t.fire === true && t.state.tries === 1);
t = await runT(T, { last: "UNCHANGED" }, said("some log\nERROR Error: HTTP 502: Bad Gateway", "completed", 1));
ok("a new ERROR wakes the model with its reason (exit code note ignored)", t.fire === true && t.message === "PR dashboard builder: ERROR Error: HTTP 502: Bad Gateway", JSON.stringify(t));
const errState = t.state;
t = await runT(T, errState, said("ERROR Error: HTTP 502: Bad Gateway", "completed", 1));
ok("the same ERROR within a day does not wake it", t.fire === false && t.state.last.startsWith("ERROR") && t.state.woke === errState.woke);
t = await runT(T, { last: errState.last, woke: Date.now() - 25 * 3600 * 1000 }, said("ERROR Error: HTTP 502: Bad Gateway", "completed", 1));
ok("the same ERROR after a day wakes it again", t.fire === true);
t = await runT(T, errState, said("ERROR Error: time budget used up", "completed", 1));
ok("a different ERROR wakes it", t.fire === true && /time budget/.test(t.message));
t = await runT(T, { last: "UNCHANGED" }, async () => ({ status: "completed", exitCode: 0, stdout: "UNCHANGED rows=1" }));
ok("no aggregated text counts as an error, not as UNCHANGED", t.fire === true && /no result line/.test(t.message), JSON.stringify(t));
t = await runT(T, { last: "UNCHANGED" }, said("node: command not found", "completed", 127));
ok("output without a result line is an error naming the last line", t.fire === true && /no result line from the builder: "\(Command exited with code 127\)"/.test(t.message), JSON.stringify(t));
threw = "";
try { await runT(T, undefined, said("", "denied", null)); } catch (e) { threw = e.message; }
ok("a denied or failed exec throws (shows in run diagnostics, no model turn)", /did not run \(denied\)/.test(threw), threw);
// End to end: the trigger runs the real builder.
queue("prs", [prsOk(OPEN, CLOSED)]);
queue("ci", [ciOk(CI)]);
const realExec = async (a) => {
  const [cmd, ...args] = a.command.split(" ");
  const p = spawnSync(cmd === "node" ? process.execPath : cmd, args, { encoding: "utf8", env });
  const text = (p.stdout || "") + (p.stderr || "");
  return { status: "completed", exitCode: p.status, aggregated: text + (p.status ? "\n\n(Command exited with code " + p.status + ")" : "") };
};
t = await runT(T, undefined, realExec);
ok("end to end: changed data wakes the model", t.fire === true && /CHANGED rows=3/.test(t.message), JSON.stringify(t));
t = await runT(T, t.state, realExec);
ok("end to end: not pinned yet, the next check wakes it again", t.fire === true, JSON.stringify(t));
markPinned();
t = await runT(T, t.state, realExec);
ok("end to end: after the pin, the quiet check does not", t.fire === false, JSON.stringify(t));
queue("prs", [{ exit: 1, stderr: "HTTP 502: Bad Gateway" }]);
t = await runT(T, t.state, realExec);
ok("end to end: a real builder ERROR reaches the model with its reason", t.fire === true && /^PR dashboard builder: ERROR Error: HTTP 502: Bad Gateway$/.test(t.message), JSON.stringify(t));

console.log("passed=" + passes + " failed=" + fails);
process.exit(fails ? 1 : 0);

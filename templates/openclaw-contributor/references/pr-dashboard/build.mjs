#!/usr/bin/env node
// Builds the PR dashboard widget from GitHub data. Read only: two gh GraphQL reads, no writes to GitHub.
//   node <workspace>/references/pr-dashboard/build.mjs                fetch, write data.json and widget.html,
//                                                                     compare with dashboard/pinned.txt
//   node <workspace>/references/pr-dashboard/build.mjs --mark-pinned  record the last build as pinned (no GitHub call)
// Optional: --workspace <dir> (default: two folders above this file). It reads settings.md (dashboard_author,
// dashboard_org, dashboard_refresh_button), dashboard/short.json and dashboard/jobid.txt. The last output line is CHANGED (the widget
// differs from the last pinned one), UNCHANGED, PINNED, or ERROR with a reason and exit code 1. A failed pin
// is retried on the next run, because pinned.txt only moves on --mark-pinned. Plain Node, no packages.
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, realpathSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const DAYS = 14;
const HERE = dirname(fileURLToPath(import.meta.url));
const GATE = "openclaw/ci-gate";
// Check run states. Cancelled, skipped and neutral are not failures.
const RUN_FAIL = new Set(["FAILURE", "TIMED_OUT", "STARTUP_FAILURE", "ACTION_REQUIRED"]);
const RUN_PEND = new Set(["PENDING", "QUEUED", "IN_PROGRESS", "WAITING", "REQUESTED"]);
const RUN_SKIP = new Set(["SKIPPED", "NEUTRAL"]);
// Commit status states.
const ST_FAIL = new Set(["FAILURE", "ERROR"]);
const ST_PEND = new Set(["PENDING", "EXPECTED"]);
// Labels the widget reads. Everything else is dropped.
const KEEP_OPEN = ["rating:", "proof:", "status:", "merge-risk:"];
const KEEP_CLOSED = ["rating:", "proof:"];
const STATE_CODE = { OPEN: "O", MERGED: "M", CLOSED: "C" };
const NAME = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$/;
const JOB = /^[A-Za-z0-9_-]{1,128}$/;
// An automation check has a 30 second budget, so the whole build stops at 25 seconds.
const BUDGET_MS = 25000;
const started = Date.now();

// JSON text the way Python's json.dumps writes it by default (ASCII only, ", " and ": "),
// a stable layout for the digest and data.json.
export function pyDumps(v, sortKeys = false) {
  if (v === null || v === undefined) return "null";
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "number") return Number.isFinite(v) ? String(v) : "null";
  if (typeof v === "string") {
    let out = '"';
    for (let i = 0; i < v.length; i++) {
      const c = v.charCodeAt(i);
      const ch = v[i];
      if (ch === '"') out += '\\"';
      else if (ch === "\\") out += "\\\\";
      else if (ch === "\n") out += "\\n";
      else if (ch === "\r") out += "\\r";
      else if (ch === "\t") out += "\\t";
      else if (ch === "\b") out += "\\b";
      else if (ch === "\f") out += "\\f";
      else if (c < 0x20 || c > 0x7e) out += "\\u" + c.toString(16).padStart(4, "0");
      else out += ch;
    }
    return out + '"';
  }
  if (Array.isArray(v)) return "[" + v.map((x) => pyDumps(x, sortKeys)).join(", ") + "]";
  const keys = Object.keys(v);
  if (sortKeys) keys.sort();
  return "{" + keys.map((k) => pyDumps(k) + ": " + pyDumps(v[k], sortKeys)).join(", ") + "}";
}

const CRC_TABLE = (() => {
  const t = [];
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t.push(c >>> 0);
  }
  return t;
})();
export function crc32(text) {
  let c = 0xffffffff;
  for (const b of Buffer.from(text, "utf8")) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function setting(text, key) {
  const m = text.match(new RegExp("^\\s*-\\s*" + key + ":[ \\t]*(.*)$", "m"));
  const v = m ? m[1].trim() : "";
  return v.startsWith("<") ? "" : v;
}

// gh with up to 3 tries: GitHub's search GraphQL sometimes answers 502 or 504.
function ghTry(args) {
  let last = "";
  for (let i = 0; i < 3; i++) {
    const left = BUDGET_MS - (Date.now() - started);
    if (left < 1000) throw new Error("time budget used up" + (last ? " after: " + last : ""));
    const p = spawnSync("gh", args, { encoding: "utf8", timeout: Math.min(20000, left), maxBuffer: 16 * 1024 * 1024 });
    if (!p.error && p.status === 0) return p.stdout;
    last = p.error ? String(p.error.message || p.error) : String(p.stderr || p.stdout || "gh exited " + p.status).trim();
    last = last.slice(0, 300);
  }
  throw new Error(last || "gh failed");
}

function gql(file, vars) {
  const args = ["api", "graphql", "-F", "query=@" + join(HERE, file)];
  for (const [k, v] of Object.entries(vars)) args.push("-f", k + "=" + v);
  const out = ghTry(args);
  let d;
  try {
    d = JSON.parse(out);
  } catch {
    throw new Error("gh output is not JSON: " + JSON.stringify(String(out).slice(0, 200)));
  }
  if (d && d.errors && d.errors.length) throw new Error(JSON.stringify(d.errors).slice(0, 300));
  if (!d || !d.data) throw new Error("gh output has no data");
  return d.data;
}

// Compact CI facts for one head commit. Keys: f failed, p pending, ok passed, sk skipped or neutral,
// cx cancelled, o other; g and gd the openclaw/ci-gate status state and description. Zeros are dropped.
export function ciSummary(commit) {
  if (!commit) return null;
  const out = { f: 0, p: 0, ok: 0, sk: 0, cx: 0, o: 0 };
  const rollup = commit.statusCheckRollup || {};
  for (const item of ((rollup.contexts || {}).checkRunCountsByState) || []) {
    if (!item) continue;
    const s = item.state;
    const key = RUN_FAIL.has(s) ? "f" : RUN_PEND.has(s) ? "p" : s === "SUCCESS" ? "ok" : RUN_SKIP.has(s) ? "sk" : s === "CANCELLED" ? "cx" : "o";
    out[key] += Number(item.count) || 0;
  }
  for (const c of ((commit.status || {}).contexts) || []) {
    if (!c) continue;
    const s = c.state;
    if (c.context === GATE) {
      out.g = s;
      out.gd = String(c.description || "").replace(/^PR #\d+:\s*/, "");
      continue;
    }
    const key = ST_FAIL.has(s) ? "f" : ST_PEND.has(s) ? "p" : s === "SUCCESS" ? "ok" : "o";
    out[key] += 1;
  }
  const kept = {};
  for (const [k, v] of Object.entries(out)) if (v) kept[k] = v;
  return kept;
}

const keepLabel = (name, open) =>
  (open ? KEEP_OPEN : KEEP_CLOSED).some((p) => name.toLowerCase().startsWith(p)) || /^P\d$/.test(name);

function nodesOf(data, key) {
  const s = data && data[key];
  if (!s || !Array.isArray(s.nodes)) throw new Error("GitHub answer has no " + key + ".nodes");
  return s.nodes;
}

function localDate(d) {
  return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
}

function readJson(path, fallback, what) {
  if (!existsSync(path)) return fallback;
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (e) {
    if (what) throw new Error(what + " is not valid JSON: " + e.message);
    return fallback;
  }
}

function writeAtomic(path, text) {
  writeFileSync(path + ".tmp", text, "utf8");
  renameSync(path + ".tmp", path);
}

// The digest is what the widget shows: dates only (bot comments bump updatedAt), plus the template.
export function digestOf(rows, tpl) {
  const shown = rows.map((r) => ({ ...r, updated: String(r.updated).slice(0, 10) }));
  return createHash("sha256").update(pyDumps([DAYS, shown, tpl], true)).digest("hex");
}

// Compact payload. Keys: n number, t title, s state O/M/C, u updatedAt, l labels, m merge state, c ci,
// h short summary, r repo (if not named like the org), url (only if unusual). o: the org, if not openclaw.
export function render(tpl, data, job, org) {
  const small = [];
  for (const r of data.rows) {
    const repo = String(r.url).split("/")[4] || "";
    const x = { n: r.n, t: r.title, s: STATE_CODE[r.state] || r.state, u: r.updated };
    if (r.labels && r.labels.length) x.l = r.labels;
    if (r.ms) x.m = r.ms;
    if (r.ci !== null && r.ci !== undefined) x.c = r.ci;
    if (r.short) x.h = r.short;
    if (repo !== org) x.r = repo;
    if (r.url !== "https://github.com/" + org + "/" + repo + "/pull/" + r.n) x.url = r.url;
    small.push(x);
  }
  const payload = { d: data.days, at: data.fetchedAt, rows: small };
  if (org !== "openclaw") payload.o = org;
  const embedded = JSON.stringify(payload).split("<").join("\\u003c");
  return tpl.split("__JOBID__").join(job).split("__CRC__").join(String(crc32(embedded))).split("__DATA__").join(embedded);
}

function markPinned(out) {
  const digest = readJson(join(out, "data.json"), {}).digest;
  if (!digest) throw new Error("no digest in dashboard/data.json, run the builder first");
  writeAtomic(join(out, "pinned.txt"), digest + "\n");
  console.log("PINNED " + digest.slice(0, 12));
}

function main() {
  const argv = process.argv.slice(2);
  const wi = argv.indexOf("--workspace");
  const ws = resolve(wi >= 0 && argv[wi + 1] ? argv[wi + 1] : join(HERE, "..", ".."));
  const out = join(ws, "dashboard");
  mkdirSync(out, { recursive: true });
  if (argv.includes("--mark-pinned")) return markPinned(out);

  const settingsPath = join(ws, "settings.md");
  const settings = existsSync(settingsPath) ? readFileSync(settingsPath, "utf8") : "";
  let author = setting(settings, "dashboard_author");
  const org = setting(settings, "dashboard_org") || "openclaw";
  if (!NAME.test(org)) throw new Error("dashboard_org is not a GitHub org: " + JSON.stringify(org.slice(0, 60)));
  if (!author) author = ghTry(["api", "user", "--jq", ".login"]).trim();
  if (!NAME.test(author)) throw new Error("dashboard_author is not a GitHub login: " + JSON.stringify(author.slice(0, 60)));

  const d = new Date();
  d.setDate(d.getDate() - DAYS);
  const base = "org:" + org + " author:" + author + " is:pr";
  const prs = gql("prs.graphql", { open: base + " is:open", closed: base + " is:closed closed:>=" + localDate(d) });
  const ci = gql("ci.graphql", { open: base + " is:open" });

  const ciBy = {};
  for (const n of nodesOf(ci, "open")) {
    if (!n || !n.url) continue;
    const commits = (n.commits && n.commits.nodes) || [];
    ciBy[n.url] = ciSummary(commits[0] ? commits[0].commit : null);
  }
  const short = readJson(join(out, "short.json"), {}, "dashboard/short.json") || {};
  const dataPath = join(out, "data.json");
  const old = readJson(dataPath, {}) || {};
  const oldMs = {};
  for (const r of old.rows || []) if (r && r.url) oldMs[r.url] = r.ms;

  const rows = [];
  for (const n of [...nodesOf(prs, "open"), ...nodesOf(prs, "closed")]) {
    if (!n || !n.url) continue;
    const isOpen = n.state === "OPEN";
    let ms = n.isDraft ? "draft" : String(n.mergeStateStatus || "unknown").toLowerCase();
    if (ms === "unknown" && oldMs[n.url] && oldMs[n.url] !== "unknown") ms = oldMs[n.url]; // GitHub is recomputing
    rows.push({
      n: n.number, title: n.title || "", url: n.url, state: n.state || "UNKNOWN",
      updated: n.updatedAt || "", ms: isOpen ? ms : null,
      labels: ((n.labels && n.labels.nodes) || []).filter((l) => l && l.name && keepLabel(l.name, isOpen)).map((l) => l.name),
      ci: isOpen && ciBy[n.url] !== undefined ? ciBy[n.url] : null,
      short: typeof short[n.url] === "string" && short[n.url] ? short[n.url] : null,
    });
  }
  rows.sort((a, b) => (a.updated < b.updated ? 1 : a.updated > b.updated ? -1 : 0));

  const tpl = readFileSync(join(HERE, "template.html"), "utf8");
  const digest = digestOf(rows, tpl);
  const pinnedPath = join(out, "pinned.txt");
  const pinned = existsSync(pinnedPath) ? readFileSync(pinnedPath, "utf8").trim() : "";
  const rl = (x) => (x && x.rateLimit) || {};
  const data = {
    digest, days: DAYS, rows,
    fetchedAt: new Date().toISOString().slice(0, 19) + "+00:00",
    cost: (Number(rl(prs).cost) || 0) + (Number(rl(ci).cost) || 0),
    remaining: rl(ci).remaining === undefined ? null : rl(ci).remaining,
  };
  const jobPath = join(out, "jobid.txt");
  const job = existsSync(jobPath) ? readFileSync(jobPath, "utf8").trim() : "";
  if (job && !JOB.test(job)) throw new Error("dashboard/jobid.txt is not an automation id");
  // The Refresh button needs a cron.trigger grant, and a grant covers only the exact bytes it approved,
  // so it is off unless the owner turned it on.
  const refresh = setting(settings, "dashboard_refresh_button") === "on";
  writeAtomic(dataPath, pyDumps(data));
  writeAtomic(join(out, "widget.html"), render(tpl, data, refresh ? job : "", org));
  console.log((pinned !== digest ? "CHANGED" : "UNCHANGED") + " rows=" + rows.length + " cost=" + data.cost + " remaining=" + data.remaining);
}

const isMain = () => {
  try { return !!process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href; } catch { return false; }
};
if (isMain()) {
  try {
    main();
  } catch (e) {
    console.log("ERROR " + ((e && e.name) || "Error") + ": " + String((e && e.message) || e).replace(/\s+/g, " ").slice(0, 400));
    process.exit(1);
  }
}

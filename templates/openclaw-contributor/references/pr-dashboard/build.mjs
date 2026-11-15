#!/usr/bin/env node
// Builds the PR dashboard widget from GitHub data. Read only: two gh GraphQL reads, no writes to GitHub.
// Usage: node <workspace>/references/pr-dashboard/build.mjs [--workspace <dir>]
// The workspace defaults to two folders above this file. It reads settings.md (dashboard_author,
// dashboard_org) and dashboard/short.json and dashboard/jobid.txt, and writes dashboard/data.json and
// dashboard/widget.html. The last output line is CHANGED or UNCHANGED (with rows, cost and remaining),
// or ERROR with a reason and exit code 1. Plain Node, no packages.
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, realpathSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const DAYS = 14;
const HERE = dirname(fileURLToPath(import.meta.url));
const FAIL = new Set(["FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"]);
const PEND = new Set(["PENDING", "QUEUED", "IN_PROGRESS", "WAITING", "REQUESTED", "EXPECTED"]);
const NAME = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$/;
const JOB = /^[A-Za-z0-9_-]{1,128}$/;
// An automation check has a 30 second budget, so the whole build stops at 25 seconds.
const BUDGET_MS = 25000;
const started = Date.now();

// JSON text the way Python's json.dumps writes it by default (ASCII only, ", " and ": "),
// so the digest and data.json match the earlier Python builder for the same rows.
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

function setting(text, key) {
  const m = text.match(new RegExp("^\\s*-\\s*" + key + ":[ \\t]*(.*)$", "m"));
  const v = m ? m[1].trim() : "";
  return v.startsWith("<") ? "" : v;
}

function run(args) {
  const left = BUDGET_MS - (Date.now() - started);
  if (left < 1000) throw new Error("time budget used up");
  const p = spawnSync("gh", args, { encoding: "utf8", timeout: Math.min(20000, left), maxBuffer: 16 * 1024 * 1024 });
  return p;
}

// gh with up to 3 tries: GitHub's search GraphQL sometimes answers 502 or 504.
function ghTry(args) {
  let last = "";
  for (let i = 0; i < 3; i++) {
    const p = run(args);
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

export function ciCounts(rollup) {
  if (!rollup) return null;
  const ctx = rollup.contexts || {};
  let total = 0, fail = 0, pend = 0;
  for (const item of [...(ctx.checkRunCountsByState || []), ...(ctx.statusContextCountsByState || [])]) {
    if (!item) continue;
    const n = Number(item.count) || 0;
    total += n;
    if (FAIL.has(item.state)) fail += n;
    if (PEND.has(item.state)) pend += n;
  }
  return { total, fail, pend };
}

// "fix(acp): configured binding ..." -> "Configured binding ..."
export function plainTitle(title) {
  const t = String(title || "").replace(/^[a-z]+(\([^)]*\))?!?:\s*/i, "").trim();
  const cps = [...t];
  return cps.length ? cps[0].toUpperCase() + cps.slice(1).join("") : "";
}

function nodesOf(data, key) {
  const s = data && data[key];
  if (!s || !Array.isArray(s.nodes)) throw new Error("GitHub answer has no " + key + ".nodes");
  return s.nodes;
}

function localDate(d) {
  return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
}

function writeAtomic(path, text) {
  writeFileSync(path + ".tmp", text, "utf8");
  renameSync(path + ".tmp", path);
}

export function render(tpl, data, job) {
  const pick = { days: data.days, rows: data.rows, fetchedAt: data.fetchedAt };
  const embedded = JSON.stringify(pick).split("</").join("<\\/");
  return tpl.split("/*DATA*/null").join(embedded).split("__JOBID__").join(job);
}

function main() {
  const argv = process.argv.slice(2);
  const wi = argv.indexOf("--workspace");
  const ws = resolve(wi >= 0 && argv[wi + 1] ? argv[wi + 1] : join(HERE, "..", ".."));
  const out = join(ws, "dashboard");
  mkdirSync(out, { recursive: true });

  const settingsPath = join(ws, "settings.md");
  const settings = existsSync(settingsPath) ? readFileSync(settingsPath, "utf8") : "";
  let author = setting(settings, "dashboard_author");
  const org = setting(settings, "dashboard_org") || "openclaw";
  if (!author) author = ghTry(["api", "user", "--jq", ".login"]).trim();
  if (!NAME.test(author)) throw new Error("dashboard_author is not a GitHub login: " + JSON.stringify(author.slice(0, 60)));
  if (!NAME.test(org)) throw new Error("dashboard_org is not a GitHub org: " + JSON.stringify(org.slice(0, 60)));

  const d = new Date();
  d.setDate(d.getDate() - DAYS);
  const since = localDate(d);
  const base = "org:" + org + " author:" + author + " is:pr";
  const prs = gql("prs.graphql", { open: base + " is:open", closed: base + " is:closed closed:>=" + since });
  const ci = gql("ci.graphql", { open: base + " is:open" });

  const ciBy = {};
  for (const n of nodesOf(ci, "open")) {
    if (!n || !n.url) continue;
    const commits = (n.commits && n.commits.nodes) || [];
    const c = commits[0] && commits[0].commit;
    ciBy[n.url] = ciCounts(c ? c.statusCheckRollup : null);
  }

  const shortPath = join(out, "short.json");
  let short = {};
  if (existsSync(shortPath)) {
    try {
      short = JSON.parse(readFileSync(shortPath, "utf8")) || {};
    } catch (e) {
      throw new Error("dashboard/short.json is not valid JSON: " + e.message);
    }
  }

  const rows = [];
  for (const n of [...nodesOf(prs, "open"), ...nodesOf(prs, "closed")]) {
    if (!n || !n.url) continue;
    const ms = n.isDraft ? "draft" : String(n.mergeStateStatus || "unknown").toLowerCase();
    rows.push({
      n: n.number, title: n.title || "", url: n.url, state: n.state || "UNKNOWN",
      merged: !!n.merged, updated: n.updatedAt || "", ms,
      labels: ((n.labels && n.labels.nodes) || []).filter((l) => l && l.name).map((l) => l.name),
      ci: n.state === "OPEN" ? (ciBy[n.url] === undefined ? null : ciBy[n.url]) : null,
      short: (typeof short[n.url] === "string" && short[n.url]) || plainTitle(n.title),
      repo: n.url.split("/")[4] || "",
    });
  }
  rows.sort((a, b) => (a.updated < b.updated ? 1 : a.updated > b.updated ? -1 : 0));
  const digest = createHash("sha256").update(pyDumps(rows, true)).digest("hex");

  const dataPath = join(out, "data.json");
  let old = {};
  if (existsSync(dataPath)) {
    try { old = JSON.parse(readFileSync(dataPath, "utf8")) || {}; } catch { old = {}; }
  }
  const changed = old.digest !== digest;
  const rl = (x) => (x && x.rateLimit) || {};
  const data = {
    digest, days: DAYS, rows,
    fetchedAt: new Date().toISOString().slice(0, 19) + "+00:00",
    cost: (Number(rl(prs).cost) || 0) + (Number(rl(ci).cost) || 0),
    remaining: rl(ci).remaining === undefined ? null : rl(ci).remaining,
  };
  writeAtomic(dataPath, pyDumps(data));

  const jobPath = join(out, "jobid.txt");
  const job = existsSync(jobPath) ? readFileSync(jobPath, "utf8").trim() : "";
  if (job && !JOB.test(job)) throw new Error("dashboard/jobid.txt is not an automation id");
  const tpl = readFileSync(join(HERE, "template.html"), "utf8");
  writeAtomic(join(out, "widget.html"), render(tpl, data, job));
  console.log((changed ? "CHANGED" : "UNCHANGED") + " rows=" + rows.length + " cost=" + data.cost + " remaining=" + data.remaining);
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

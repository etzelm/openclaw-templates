// fetch.mjs runs only the four fixed gh reads, with no shell, and writes what ingest.sql reads.
// A stand-in `gh` on PATH records every call and serves the fixtures.
// Usage: node tests/fetch.test.mjs <package dir>
import { execFileSync, spawnSync } from "node:child_process";
import { chmodSync, cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const pkg = resolve(process.argv[2] || ".");
let passes = 0;
let fails = 0;
const ok = (name, cond, extra = "") => {
  if (cond) { passes++; console.log("PASS " + name); } else { fails++; console.log("FAIL " + name + " " + extra); }
};

const scratch = mkdtempSync(join(tmpdir(), "rmh-fetch."));
try {
  const ws = join(scratch, "ws");
  cpSync(join(pkg, "references"), join(ws, "references"), { recursive: true });
  const bin = join(scratch, "bin");
  const log = join(scratch, "gh-calls.jsonl");
  const fixtures = join(pkg, "tests", "fixtures", "example");
  cpSync(join(pkg, "tests", "fixtures"), join(scratch, "fixtures"), { recursive: true });
  // The stand-in gh: logs its arguments and prints the fixture for that read.
  execFileSync("mkdir", ["-p", bin]);
  writeFileSync(join(bin, "gh"), `#!/usr/bin/env node
const fs = require("fs");
const a = process.argv.slice(2);
fs.appendFileSync(${JSON.stringify(log)}, JSON.stringify(a) + "\\n");
if (process.env.GH_FAIL) { process.stderr.write("HTTP 404: Not Found\\n"); process.exit(1); }
const f = ${JSON.stringify(fixtures)};
const name = a[0] === "pr" ? "prs" : a[0] === "label" ? "labels" : a.includes("number,title,state") ? "index" : "issues";
process.stdout.write(fs.readFileSync(f + "/" + name + ".json", "utf8"));
`);
  chmodSync(join(bin, "gh"), 0o755);
  const env = { ...process.env, PATH: bin + ":" + process.env.PATH };
  const run = (args, extraEnv = {}) =>
    spawnSync(process.execPath, ["references/fetch.mjs", ...args], { cwd: ws, env: { ...env, ...extraEnv }, encoding: "utf8" });

  const r = run(["example-org/example-repo"]);
  ok("fetch exits 0", r.status === 0, r.stderr);
  const summary = JSON.parse(r.stdout.trim());
  ok("summary names the repo and counts", summary.repo === "example-org/example-repo" && summary.issues === 100 && summary.prs === 50 && summary.labels === 10 && summary.index === 500, r.stdout);
  ok("summary carries an ISO UTC time", /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(summary.fetched_at));
  const dir = join(ws, "inbox", "example-org__example-repo");
  for (const f of ["issues", "prs", "labels", "index", "fetch"]) ok(`writes inbox/<repo>/${f}.json`, existsSync(join(dir, f + ".json")));
  ok("leaves no temp files", !existsSync(join(dir, "issues.json.tmp")));

  const calls = readFileSync(log, "utf8").trim().split("\n").map((l) => JSON.parse(l));
  ok("runs exactly four gh calls", calls.length === 4, JSON.stringify(calls));
  const verbs = calls.map((c) => c.slice(0, 2).join(" "));
  ok("every call is a list read", verbs.every((v) => ["issue list", "pr list", "label list"].includes(v)), verbs.join(", "));
  ok("every call names the repo", calls.every((c) => c[c.indexOf("--repo") + 1] === "example-org/example-repo"));
  ok("no call passes a write flag", !calls.flat().some((a) => /^(--add-label|--body|--body-file|--remove-label|create|edit|close|comment|delete|api)$/.test(a)));

  // Same command, same calls: the command the owner approves once never changes.
  writeFileSync(log, "");
  run(["example-org/example-repo"]);
  const again = readFileSync(log, "utf8").trim().split("\n");
  ok("a second fetch makes the same calls", JSON.stringify(again.map((l) => JSON.parse(l))) === JSON.stringify(calls));

  for (const bad of ["../etc", "a/b/c", "a b/c", "a/b;id", "$(id)/x", "-x/y", "", "a"]) {
    writeFileSync(log, "");
    const b = run([bad]);
    ok(`refuses repo ${JSON.stringify(bad)} before calling gh`, b.status === 2 && readFileSync(log, "utf8") === "", b.stderr);
  }
  writeFileSync(log, "");
  ok("refuses extra arguments", run(["example-org/example-repo", "--limit"]).status === 2 && readFileSync(log, "utf8") === "");

  const f = run(["example-org/example-repo"], { GH_FAIL: "1" });
  ok("a failed gh read exits 1 with the gh error line", f.status === 1 && f.stderr.includes("HTTP 404"), f.stderr);
  ok("a failed read keeps the last good files", JSON.parse(readFileSync(join(dir, "issues.json"), "utf8")).length === 100);
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
console.log(`passed=${passes} failed=${fails}`);
process.exit(fails ? 1 : 0);

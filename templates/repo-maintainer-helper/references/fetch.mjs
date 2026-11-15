// Read-only fetch for one repository. Usage, from the workspace root:
//   node references/fetch.mjs <owner/repo>
// It runs four fixed `gh` list reads with no shell, writes their JSON output to
// inbox/<owner>__<repo>/, and prints a one-line JSON summary. It never writes to GitHub.
// The command is the same on every run for a repository, so the owner can approve it once
// with "Always allow here". ingest.sql reads the files it writes.
import { execFileSync } from "node:child_process";
import { mkdirSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const LIMITS = { issues: 100, prs: 50, labels: 200, index: 1000 };
// Owner and name start with a letter, digit or underscore, so neither can read as a flag.
const REPO = /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,38}\/[A-Za-z0-9_][A-Za-z0-9_.-]{0,99}$/;

export function reads(repo) {
  return {
    issues: [
      "issue", "list", "--repo", repo, "--state", "all", "--limit", String(LIMITS.issues),
      "--search", "sort:updated-desc",
      "--json", "number,title,author,state,labels,createdAt,updatedAt,url,body",
    ],
    prs: [
      "pr", "list", "--repo", repo, "--state", "all", "--limit", String(LIMITS.prs),
      "--search", "sort:updated-desc",
      "--json", "number,title,author,state,isDraft,labels,createdAt,updatedAt,url,body",
    ],
    labels: ["label", "list", "--repo", repo, "--limit", String(LIMITS.labels), "--json", "name"],
    index: [
      "issue", "list", "--repo", repo, "--state", "all", "--limit", String(LIMITS.index),
      "--json", "number,title,state",
    ],
  };
}

export function slug(repo) {
  return repo.replace("/", "__");
}

function main(argv) {
  const repo = argv[2];
  if (argv.length !== 3 || !REPO.test(repo || "")) {
    console.error("usage: node references/fetch.mjs <owner/repo>");
    process.exit(2);
  }
  const dir = join(dirname(fileURLToPath(import.meta.url)), "..", "inbox", slug(repo));
  mkdirSync(dir, { recursive: true });
  const counts = {};
  for (const [name, args] of Object.entries(reads(repo))) {
    let out;
    try {
      out = execFileSync("gh", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"] });
    } catch (err) {
      const msg = String(err.stderr || err.message || err).trim().split("\n")[0];
      console.error(`gh ${name} read failed for ${repo}: ${msg}`);
      process.exit(1);
    }
    const data = JSON.parse(out);
    if (!Array.isArray(data)) {
      console.error(`gh ${name} read for ${repo} did not return a list`);
      process.exit(1);
    }
    counts[name] = data.length;
    // Write then rename, so ingest never reads a half-written file.
    const file = join(dir, `${name}.json`);
    writeFileSync(file + ".tmp", JSON.stringify(data));
    renameSync(file + ".tmp", file);
  }
  const summary = { repo, ...counts, limits: LIMITS, fetched_at: new Date().toISOString().replace(/\.\d{3}Z$/, "Z") };
  writeFileSync(join(dir, "fetch.json"), JSON.stringify(summary));
  console.log(JSON.stringify(summary));
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main(process.argv);

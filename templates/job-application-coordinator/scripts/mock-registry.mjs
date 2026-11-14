// Local stand-in for the ClawHub registry, for the release gate only.
// Serves one built Template .tgz through the four endpoints `openclaw templates add
// @publisher/name` reads: package detail, artifact detail, security, artifact download.
// Usage: node mock-registry.mjs <tgz> <port>
// Binds to the loopback address only. It never talks to the real registry.
import http from "node:http";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const [tgzPath, portArg] = process.argv.slice(2);
if (!tgzPath || !portArg) {
  console.error("usage: node mock-registry.mjs <tgz> <port>");
  process.exit(2);
}
const tgz = readFileSync(tgzPath);
const pkg = JSON.parse(execFileSync("tar", ["xzOf", tgzPath, "package/package.json"], { encoding: "utf8" }));
const files = execFileSync("tar", ["tzf", tgzPath], { encoding: "utf8" }).split("\n").filter((l) => l && !l.endsWith("/"));
const name = pkg.name;
const version = pkg.version;
const sha256 = createHash("sha256").update(tgz).digest("hex");
const tarball = `${name.replace(/^@/, "").replace("/", "-")}-${version}.tgz`;
const artifact = {
  kind: "npm-pack",
  format: "tgz",
  sha256,
  size: tgz.length,
  npmIntegrity: `sha512-${createHash("sha512").update(tgz).digest("base64")}`,
  npmShasum: createHash("sha1").update(tgz).digest("hex"),
  npmTarballName: tarball,
  npmFileCount: files.length,
  npmUnpackedSize: tgz.length * 3,
};
const ident = { name, displayName: name, family: "template" };
const enc = encodeURIComponent(name);
const base = `/api/v1/packages/${enc}`;
const now = Date.now();
const routes = {
  [base]: () => ({
    package: {
      ...ident, artifact, categories: [], channel: "community", createdAt: now, updatedAt: now, icon: null,
      isOfficial: false, latestReleaseId: "mock-release", latestVersion: version, scanStatus: "clean",
      stats: { downloads: 0, installs: 0, stars: 0, versions: 1 }, summary: "", tags: { latest: version },
    },
    owner: { handle: name.split("/")[0].replace(/^@/, ""), displayName: "mock", official: false },
  }),
  [`${base}/versions/${version}/artifact`]: () => ({ package: ident, version, artifact }),
  [`${base}/versions/${version}/security`]: () => ({
    overview: "mock", verdict: "clean", package: ident,
    securityAuditUrl: `http://127.0.0.1:${portArg}/security-audit?version=${version}`,
    release: { releaseId: "mock-release", version, artifactKind: "npm-pack", artifactSha256: sha256, npmIntegrity: artifact.npmIntegrity, npmShasum: artifact.npmShasum, npmTarballName: tarball, createdAt: now },
    trust: { scanStatus: "clean", moderationState: null, blockedFromDownload: false, reasons: [], pending: false, stale: false },
  }),
};
http.createServer((req, res) => {
  const path = decodeURIComponent((req.url ?? "").split("?")[0]);
  const key = Object.keys(routes).find((k) => decodeURIComponent(k) === path);
  console.log(`${req.method} ${req.url}`);
  if (req.method !== "GET") { res.writeHead(405); res.end(); return; }
  if (key) {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify(routes[key]()));
    return;
  }
  if (path === decodeURIComponent(`${base}/versions/${version}/artifact/download`)) {
    res.writeHead(200, {
      "content-type": "application/octet-stream",
      "content-length": tgz.length,
      etag: `"sha256:${sha256}"`,
      "x-clawhub-artifact-sha256": sha256,
      "x-clawhub-artifact-type": "npm-pack-tarball",
      "x-clawhub-npm-integrity": artifact.npmIntegrity,
      "x-clawhub-npm-shasum": artifact.npmShasum,
    });
    res.end(tgz);
    return;
  }
  res.writeHead(404, { "content-type": "application/json" });
  res.end(JSON.stringify({ error: "not found" }));
}).listen(Number(portArg), "127.0.0.1", () => console.log(`mock registry for ${name}@${version} on 127.0.0.1:${portArg}`));

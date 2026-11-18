// Read-only watcher check for one open PR, used as an automation's trigger.script.
// The agent copies this text unchanged except for two lines: the PR number on the `const pr`
// line and the time it adds the watcher, in ISO 8601 UTC, on the `const addedAt` line.
// It runs one gh read piped through base64 and never writes. The pipe is there because
// OpenClaw's tokenjuice plugin rewrites gh JSON in exec results into a text summary;
// base64 output passes through unchanged, and the check decodes it here. It wakes the agent when the PR changed:
// state, head, labels, ClawSweeper comments and people's comments (also when edited in
// place), comments or reviews by other bots, reviews, or a finished check result. It also wakes the agent
// once a day while nothing changes, so the 7-day stop can run.
// First check: it saves what it sees as the baseline and always fires once, because a
// label or a ClawSweeper comment edited in place carries no usable time in this read.
// Its message names what is newer than addedAt (comments, reviews, finished checks).
// With addedAt left empty the first check only saves (the 0.4.2 behavior).
const repo = "openclaw/openclaw";
const pr = 0;
const addedAt = "";
const DAY = 24 * 60 * 60 * 1000;
const r = await exec({
  command:
    "gh pr view " + pr + " --repo " + repo +
    " --json state,isDraft,headRefOid,labels,comments,reviews,statusCheckRollup | base64",
});
if (!r || r.status !== "completed" || r.exitCode !== 0) {
  throw new Error("PR " + pr + " watcher: gh pr view failed. See this automation's run diagnostics.");
}
if (typeof r.aggregated !== "string" || !r.aggregated.trim()) {
  throw new Error("PR " + pr + " watcher: gh pr view returned no output (no aggregated text). See this automation's run diagnostics.");
}
const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const decodeBase64 = (text) => {
  const s = text.replace(/\s+/g, "");
  if (!s || s.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(s)) return null;
  const bytes = [];
  for (let i = 0; i < s.length; i += 4) {
    const n = [0, 1, 2, 3].map((k) => (s[i + k] === "=" ? 0 : B64.indexOf(s[i + k])));
    const x = (n[0] << 18) | (n[1] << 12) | (n[2] << 6) | n[3];
    bytes.push((x >> 16) & 255);
    if (s[i + 2] !== "=") bytes.push((x >> 8) & 255);
    if (s[i + 3] !== "=") bytes.push(x & 255);
  }
  if (typeof TextDecoder === "function") return new TextDecoder().decode(new Uint8Array(bytes));
  let bin = "";
  for (let i = 0; i < bytes.length; i += 8192) bin += String.fromCharCode.apply(null, bytes.slice(i, i + 8192));
  return decodeURIComponent(escape(bin));
};
const text = decodeBase64(r.aggregated);
if (text === null) {
  throw new Error("PR " + pr + " watcher: gh pr view output is not base64 (first 200 chars: " + JSON.stringify(r.aggregated.slice(0, 200)) + ").");
}
let v;
try {
  v = JSON.parse(text);
} catch {
  throw new Error("PR " + pr + " watcher: gh pr view output is not JSON (first 200 chars: " + JSON.stringify(text.slice(0, 200)) + ").");
}
const login = (c) => (c.author && c.author.login) || "";
const isClawSweeper = (c) => /^clawsweeper(\[bot\])?$/i.test(login(c));
const isBot = (c) => /\[bot\]$|^app\/|^(github-actions|barnacle)$/i.test(login(c));
const hash = (text) => {
  let h = 5381;
  for (let i = 0; i < text.length; i++) h = ((h * 33) ^ text.charCodeAt(i)) >>> 0;
  return h.toString(16);
};
const comments = v.comments || [];
const sweeper = comments.filter(isClawSweeper);
const bots = comments.filter((c) => !isClawSweeper(c) && isBot(c));
const people = comments.filter((c) => !isClawSweeper(c) && !isBot(c));
const reviews = v.reviews || [];
const FINAL = /^(SUCCESS|FAILURE|ERROR|NEUTRAL|SKIPPED|CANCELLED|TIMED_OUT|ACTION_REQUIRED|STALE|STARTUP_FAILURE)$/;
const observed = {
  state: v.state,
  draft: v.isDraft,
  head: v.headRefOid,
  labels: (v.labels || []).map((l) => l.name).sort(),
  clawsweeper: [sweeper.length, hash(sweeper.map((c) => c.createdAt + "\n" + (c.body || "")).join("\n"))],
  people: [people.length, people.length ? people[people.length - 1].createdAt : "", hash(people.map((c) => c.createdAt + "\n" + (c.body || "")).join("\n"))],
  bots: [bots.length, bots.length ? bots[bots.length - 1].createdAt : ""],
  reviews: [reviews.length, reviews.length ? reviews[reviews.length - 1].submittedAt || "" : ""],
  checks: (v.statusCheckRollup || [])
    .map((c) => {
      const result = String(c.conclusion || c.state || "").toUpperCase();
      return (c.name || c.context) + ": " + (FINAL.test(result) ? result : "pending");
    })
    .sort(),
};
const now = Date.now();
const prev = trigger.state;
if (!prev || !prev.observed) {
  const UTC = /^\d{4}-\d\d-\d\dT\d\d:\d\d(:\d\d(\.\d+)?)?Z$/;
  if (addedAt && (!UTC.test(addedAt) || isNaN(Date.parse(addedAt)))) {
    throw new Error("PR " + pr + " watcher: addedAt is not an ISO 8601 UTC time ending in Z: " + addedAt);
  }
  const start = addedAt ? Date.parse(addedAt) : NaN;
  const newer = (t) => !!t && Date.parse(t) > start;
  const since = [];
  if (!isNaN(start)) {
    if (sweeper.some((c) => newer(c.createdAt))) since.push("ClawSweeper comment");
    if (people.some((c) => newer(c.createdAt))) since.push("comment by a person or an unknown account");
    if (bots.some((c) => newer(c.createdAt))) since.push("bot comment");
    if (reviews.some((c) => newer(c.submittedAt))) since.push("review");
    if ((v.statusCheckRollup || []).some((c) => newer(c.completedAt))) since.push("finished check");
    if (v.state !== "OPEN") since.push("state " + v.state);
  }
  const state = { observed, since: now, nudged: now };
  if (isNaN(start)) return { fire: false, state };
  return {
    fire: true,
    message:
      "PR " + pr + " watcher baseline saved (added at " + addedAt + "). Newer than the add: " +
      (since.length ? since.join(", ") : "no dated comment, review or check") +
      ". Labels and in-place edits are not dated: re-read the PR live before acting (contribution-loop.md, step 12). Observed: " +
      JSON.stringify(observed).slice(0, 3000),
    state,
  };
}
if (JSON.stringify(observed) !== JSON.stringify(prev.observed)) {
  return {
    fire: true,
    message:
      "PR " + pr + " changed. Re-read it live before acting (contribution-loop.md, step 12). Observed: " +
      JSON.stringify(observed).slice(0, 3000),
    state: { observed, since: now, nudged: now },
  };
}
if (now - prev.nudged >= DAY) {
  const days = Math.floor((now - prev.since) / DAY);
  return {
    fire: true,
    message:
      "PR " + pr + " has not changed for " + days + " day(s). Re-read it live and check the " +
      "7-day stop (contribution-loop.md, step 12).",
    state: { observed, since: prev.since, nudged: now },
  };
}
return { fire: false };

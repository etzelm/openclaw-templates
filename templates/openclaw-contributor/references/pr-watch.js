// Read-only watcher check for one open PR, used as an automation's trigger.script.
// The agent copies this text unchanged except for the PR number on the `const pr` line.
// It runs one plain gh read and never writes. It wakes the agent when the PR changed:
// state, head, labels, ClawSweeper comments (also when edited in place), comments or
// reviews by people or other bots, or a finished check result. It also wakes the agent
// once a day while nothing changes, so the 7-day stop can run. The first check only saves.
const repo = "openclaw/openclaw";
const pr = 0;
const DAY = 24 * 60 * 60 * 1000;
const r = await exec({
  command:
    "gh pr view " + pr + " --repo " + repo +
    " --json state,isDraft,headRefOid,labels,comments,reviews,statusCheckRollup",
});
if (!r || r.status !== "completed" || r.exitCode !== 0) {
  throw new Error("PR " + pr + " watcher: gh pr view failed. See this automation's run diagnostics.");
}
const v = JSON.parse(r.aggregated);
const login = (c) => (c.author && c.author.login) || "";
const isClawSweeper = (c) => /^clawsweeper/i.test(login(c));
const isBot = (c) => /\[bot\]$|^app\/|^(github-actions|barnacle)/i.test(login(c));
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
  people: [people.length, people.length ? people[people.length - 1].createdAt : ""],
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
  return { fire: false, state: { observed, since: now, nudged: now } };
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

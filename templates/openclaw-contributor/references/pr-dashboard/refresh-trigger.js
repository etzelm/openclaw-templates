// Trigger check for the PR dashboard refresh automation (trigger.script).
// The agent copies this text unchanged except for the `const workspace` line, which gets the
// absolute path of its workspace (no spaces or shell characters). It runs the read-only builder once
// and reads its result line. UNCHANGED does not wake the model. CHANGED (the widget differs from the
// last pinned one) wakes it to pin the new widget. ERROR wakes it on a new error, and again once a day
// while the same error lasts, so a long GitHub outage does not start a model turn every 15 minutes.
const workspace = "";
if (!/^\/[A-Za-z0-9._\/-]+$/.test(workspace)) {
  throw new Error("PR dashboard: the workspace line must be an absolute path with no spaces or shell characters.");
}
const DAY = 24 * 60 * 60 * 1000;
const command = "node " + workspace + "/references/pr-dashboard/build.mjs";
const r = await exec({ command });
if (!r || r.status !== "completed") {
  throw new Error("PR dashboard: the builder did not run (" + String((r && r.status) || "no result") + "). See this automation's run diagnostics.");
}
// A non-zero exit appends "(Command exited with code N)" to aggregated, so look for the result line.
const lines = String(r.aggregated || "").split("\n").map((l) => l.trim());
const found = lines.filter((l) => /^(CHANGED|UNCHANGED|ERROR)\b/.test(l)).pop();
const last = found || "ERROR no result line from the builder: " + JSON.stringify(lines.filter(Boolean).pop() || "").slice(0, 200);
const now = Date.now();
const prev = trigger.state || {};
if (last.startsWith("UNCHANGED")) return { fire: false, state: { last } };
if (last.startsWith("CHANGED")) return { fire: true, message: "PR dashboard builder: " + last, state: { last } };
if (last === prev.last && typeof prev.woke === "number" && now - prev.woke < DAY) {
  return { fire: false, state: { last, woke: prev.woke } };
}
return { fire: true, message: "PR dashboard builder: " + last, state: { last, woke: now } };

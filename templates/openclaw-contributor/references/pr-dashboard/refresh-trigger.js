// Trigger check for the PR dashboard refresh automation (trigger.script).
// The agent copies this text unchanged except for the `const workspace` line, which gets the
// absolute path of its workspace. It runs the read-only builder once and reads its last line:
// UNCHANGED does not wake the model. CHANGED wakes it to pin the new widget. ERROR wakes it once
// per distinct error, so a long GitHub outage does not start a model turn every 15 minutes.
const workspace = "";
if (!/^\/[A-Za-z0-9._\/-]+$/.test(workspace)) {
  throw new Error("PR dashboard: the workspace line must be an absolute path with no spaces or shell characters.");
}
const command = "node " + workspace + "/references/pr-dashboard/build.mjs";
const r = await exec({ command });
if (!r || r.status !== "completed") {
  throw new Error("PR dashboard: the builder did not run (" + String((r && r.status) || "no result") + "). See this automation's run diagnostics.");
}
const out = String(r.aggregated || "").trim();
const last = (out.split("\n").pop() || "").trim() || "ERROR no output from the builder";
const prev = (trigger.state && trigger.state.last) || "";
if (last.startsWith("UNCHANGED")) return { fire: false, state: { last } };
if (last.startsWith("CHANGED")) return { fire: true, message: "PR dashboard builder: " + last, state: { last } };
const error = last.startsWith("ERROR") ? last : "ERROR unexpected builder output: " + last.slice(0, 200);
if (error === prev) return { fire: false, state: { last: error } };
return { fire: true, message: "PR dashboard builder: " + error, state: { last: error } };

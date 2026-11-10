# Job application coordinator

Applies to jobs from the sources the owner brings, in the owner's own signed-in browser. Fills each form, across pages and on the employer's own form, from the owner's answer bank and resume. Clicks Submit within a daily cap unless the owner picks confirm mode, stops at every CAPTCHA for the owner to clear, and tracks everything in a local SQLite database.

**Best for:** Job seekers who want many applications sent from their own answers and resume, and who stay near the browser to clear checks.

## Add it

Add it with a workspace outside the OpenClaw state folder:

```sh
openclaw templates add @etzelm/job-application-coordinator --workspace ~/job-application-coordinator
```

exec on the gateway host refuses `sqlite3` on databases inside the state folder, and a default Add puts the workspace there. First-run setup checks this and stops if the workspace is in the wrong place.

You need a visible browser you can reach during runs, sqlite3 3.35 or newer, and a chat route for the daily automation.

## Example

**Request:** Apply to the new backend roles from my sources today.

**Expected outcome:** The agent reads each listed source, keeps postings that fit profile.md, saves each posting with its full description to applications.db, and fills each form from answers.md and resume.md, following the apply link to the employer's form when needed. It writes ahead to the database, then clicks Submit within the daily cap, and skips forms that need an account. It holds at any CAPTCHA. tracker.md is regenerated from the database and the owner gets a short digest.

## Package contents

- `CLAW.md` defines the agent and provides its portable `SOUL.md` content.
- `workspace/AGENTS.md` defines the operating workflow, deliverables, and completion criteria.
- `avatars/blobster.svg` is this Template's avatar.
- Declared capability: OpenClaw tool profile `minimal` plus `read`, `write`, `edit`, `browser`, `message`, `session_status`, `exec` with workspace-only filesystem access.
- Declared capability: scheduled job `daily-apply-run` (0 9 * * 1-5 UTC).
- Capability boundary: Add this Template with a workspace outside the OpenClaw state folder, for example `openclaw templates add @etzelm/job-application-coordinator --workspace ~/job-application-coordinator`. exec on the gateway host refuses sqlite3 on any database inside the state folder, and a default Add puts the workspace there.
- Capability boundary: The browser tool works inside the owner's own signed-in browser profile. It can act in any site that profile is logged in to, so the Template limits it to the sites in sources.md plus the one apply form a posting links to, and a separate profile logged in only to job sites is safer.
- Capability boundary: The message tool reaches the owner during a scheduled run only when the automation has a chat route. Without one, the agent waits for nothing: it parks CAPTCHA postings as held and flagged postings as ready-for-owner-review, and the scheduled-path test in BOOTSTRAP.md must pass before real use.
- Capability boundary: Scheduled runs have a 60 minute default time limit and close their browser tabs at the end. All waits come out of that budget with a safety margin kept for closing the run, regenerating tracker.md, and the digest; a parked posting keeps only its database row and link.
- Capability boundary: The default is autopilot: after the setup dry run, the agent clicks Submit within the daily cap. Confirm mode, where the owner clicks Submit, is one line in settings.md.
- Capability boundary: Answers come only from answers.md, resume.md and profile.md. The read tool reads a plain text resume in the workspace; other formats need the owner to paste the text into resume.md.
- Capability boundary: Tracking uses one SQLite file, applications.db, through the sqlite3 command line and exec. The agent writes values to db-input.json with the write tool and runs only the packaged references/sql steps; each step reads its values with readfile() and json_extract(), so page text never becomes SQL or shell text. Each step checks the schema version and its input before it runs.
- Capability boundary: The profile grants exec, and workspaceOnly does not sandbox shell execution or limit it to sqlite3. The sqlite3-only rule is a Template boundary. The owner can enforce it with OpenClaw exec approvals in allowlist mode, as BOOTSTRAP.md describes.
- Capability boundary: The minimal profile plus workspace-only read, write and edit, browser, message, session_status and exec grants no packages and no MCP servers. Follow references/apply-loop.md for the Submit definition, apply forms, the database steps, parked rows, run budget, waits and stop conditions.
- `BOOTSTRAP.md` guides first-run setup and creates local preferences without packaging answers.

Review the package before applying it. Templates can create agents and may declare
additional capabilities. Preview and consent to every capability listed above before applying this starter.

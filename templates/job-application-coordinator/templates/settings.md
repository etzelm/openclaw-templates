# Settings

Edit the values after the colons. The agent reads this file at the start of every run.

## Terms of service

- tos_acknowledged: false
  - Many job sites forbid automated applications in their terms, and the risk to your accounts is yours. Set this to true only after you have checked the terms of every site in sources.md. While it is false, every run is a dry run: nothing is submitted.

## Safety

- dry_run: true
  - true: fill forms but never click Submit. Rows get status `dry-run`. The packaged default. Setup runs one dry run and shows you its digest before you change this.
  - false: the agent may submit, as confirm_before_submit says.
- confirm_before_submit: true
  - true (confirm mode, the packaged default): the agent fills the form and stops before the send click. You check it in the browser and click Submit yourself. Not done in time: the posting waits as `ready-for-owner-review`.
  - false (autopilot): the agent fills the form and clicks Submit itself, within the daily cap. A posting with a flagged answer still waits for you. Setup asks you to pick one of the two after the dry run.
- unknown_question: skip
  - Applies only to a required question that answers.md, resume.md and profile.md do not cover. An optional one is left blank.
  - skip: abandon the posting and list the question in the digest.
  - answer_and_flag: answer cautiously, flag the answer, and leave Submit to you for that posting.

## Volume

Hard limits the agent never crosses, whatever this file says: at most 25 applications counted per day, at least 60 seconds between applications, at most 2 attempts per posting, and at most 1 automatic retry of a parked posting. A dry-run fill does not use up an attempt.

- daily_target: 3
  - The floor. Below this, the agent widens the search before it ends a run.
- daily_cap: 10
  - Most applications per day, across all runs. Counts applied, waiting, held and dry-run rows. Never above 25.
- pacing_seconds: 120
  - Wait between applications. Never below 60.
- stop_after_gates: 2
  - End the run after this many CAPTCHA gates in a row that did not clear.
- time_zone: <your IANA time zone, e.g. Europe/Berlin>
  - Used to decide what "today" is for the cap.

## Waits (CAPTCHA holds and confirms)

- owner_watches_runs: true
  - true: you watch scheduled runs in the Control UI or a chat route, so the agent waits for you at holds and confirms.
  - false: nobody watches and no chat route is set: the agent parks held and confirm postings at once.
- hold_wait_minutes: 10
  - How long to wait for you at one gate, or for you to click Submit on one posting.
- poll_interval_seconds: 30
  - Length of one plain wait while watching a page. 30 or less.
- max_holds_per_run: 2
  - After this many holds, mark further gates `held` without waiting.
- max_confirms_per_run: 3
  - After this many confirm waits, the agent stops filling forms and records further fits as `prospect`. In confirm mode this is also the most applications one run can finish.

## Run budget

- run_timeout_minutes: 60
  - Must match the timeout on the daily automation. 60 is the scheduler default.
  - If you raise the automation timeout, raise this too.
- safety_margin_minutes: 10
  - Time kept free for the tracker and the digest.
- min_minutes_per_posting: 6
  - Do not start a new posting with less time than this left.

## Browser

- browser_driver: browser
  - browser (the packaged default): the agent uses OpenClaw's browser tool with browser_profile below.
  - devtools-mcp: the agent uses the Chrome DevTools MCP server this Template adds (`chrome-devtools-jobs`), attached to a dedicated Chrome you start with its own profile folder, holding only your job-site logins. Setup explains how and switches this only after a working test. Script running is turned off in that server.
- browser_profile: openclaw
  - Used only with browser_driver: browser.
  - openclaw (default): a dedicated browser that OpenClaw manages, with none of your personal logins. Sign in there only to job sites, if a site needs it. You see it in the Control UI Browser panel and clear checks there.
  - user or chrome: your own signed-in Chrome. The agent could then reach every site that browser is logged in to. Only the Template's rules keep it on job sites, so use these only if you accept that.

## Database

- db_path: ~/job-application-coordinator.db
  - The SQLite file that tracks everything. Setup replaces `~` with the absolute path, because OpenClaw's exec allowlist refuses `~`. It must be outside the OpenClaw state folder (by default `~/.openclaw`), because OpenClaw refuses sqlite3 on files inside it. The agent creates it during setup and never deletes it.

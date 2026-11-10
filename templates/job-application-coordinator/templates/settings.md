# Settings

Edit the values after the colons. The agent reads this file at the start of every run.

## Safety

- confirm_before_submit: false
  - false (autopilot, the default): the agent fills the form and clicks Submit itself, within the daily cap. A posting with a flagged answer still waits for you.
  - true (confirm mode): the agent fills the form and stops before the send click. You check it in the browser and click Submit yourself. Not done in time: the posting waits as `ready-for-owner-review`.
- dry_run: false
  - true: fill forms but never click Submit. Rows get status `dry-run`. Setup turns it on for one test run, then back off.
- unknown_question: skip
  - Applies only to a required question that answers.md, resume.md and profile.md do not cover. An optional one is left blank.
  - skip: abandon the posting and list the question in the digest.
  - answer_and_flag: answer cautiously, flag the answer, and leave Submit to you for that posting.

## Volume

- daily_target: 3
  - The floor. Below this, the agent widens the search before it ends a run.
- daily_cap: 10
  - Most applications per day, across all runs. Counts applied, waiting, held and dry-run rows. The count never goes above 25.
- pacing_seconds: 120
  - Wait between applications. 60 or more. The agent never goes below 60.
- stop_after_gates: 2
  - End the run after this many CAPTCHA gates in a row that did not clear.
- time_zone: <your IANA time zone, e.g. Europe/Berlin>
  - Used to decide what "today" is for the cap.

## Waits (CAPTCHA holds and confirms)

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

- browser_profile: user
  - The browser profile with your job site logins. "user" is your own signed-in browser. A separate profile logged in only to job sites is safer.

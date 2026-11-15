# Settings

Edit the values after the colons. The agent reads this file at the start of every task and never changes it in a scheduled run.

## Repositories

- repos: <owner/repo, one per line, at most 5>
  - Repositories you maintain and want triaged. Your `gh` login must be able to read them.
  - Setup registers each one in the database. Add one later by editing this list and asking the agent to register it.
- db_path: ~/repo-maintainer-helper.db
  - The database file, outside this workspace, so deleting and re-adding the agent keeps the history.

## Runs

- paused: false
  - true makes a scheduled run end at once. The automation's own on and off switch is in the Automations page.
- backlog_days: 14
  - On the first read of a repository, only items changed in this many days are triaged. Older ones are recorded as seen.
- max_triage_per_run: 25
  - Most items triaged per run (1 to 50). The rest wait for the next run, oldest change first.
- max_requests_per_run: 5
  - Most new requests (suggested GitHub writes) prepared per run.

## Actions

- allowed_actions: add-labels, comment
  - Which writes the agent may suggest. Any of: add-labels, comment, close. Each one still needs your OK for the exact command.
- close_duplicates: false
  - true lets the agent suggest closing an issue it found to be a duplicate. Spam can be suggested for closing when `close` is in allowed_actions.
- reply_links: <blank>
  - Links the agent may put in replies, one per line, for example your contributing guide. Blank: no links outside the repository.

## Digest

- digest_style: short
  - short: counts, then one line per item that needs you. full: one line per triaged item.

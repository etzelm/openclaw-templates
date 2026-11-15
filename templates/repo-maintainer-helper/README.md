# Repo Maintainer Helper

An OpenClaw Template for people who maintain a few GitHub repositories. Each weekday it reads the issues and PRs that changed, sorts them, spots likely duplicates, and sends you a short digest with suggested labels, replies and closes. Nothing changes on GitHub until you OK the exact command.

## What a morning looks like

```
Triage 2026-11-16: 7 triaged, 0 still waiting.

Needs you
- [12] example-org/example-repo#4821 Login fails after proxy is set: needs-info. No version or error text.
  Would run: gh issue comment 4821 --repo example-org/example-repo --body-file drafts/example-org__example-repo-4821.md
  > Thanks for the report. Could you share your version (`example --version`), the exact command, and the error it prints?
- [13] example-org/example-repo#4823 Add export option for theme: feature.
  Would run: gh issue edit 4823 --repo example-org/example-repo --add-label 'enhancement'

Possible duplicates
- example-org/example-repo#4825 looks like #3990: same timeout on upload with a proxy.

Reply "approve <id>", "approve all labels", or "no <id>".
```

You answer "approve 13". The agent reads the issue again, checks it has not changed since you saw it, runs exactly that command, reads it once more, and tells you it is done.

## How you stay in control

- Every write (add labels, comment, close) is its own request with the exact command shown. The database builds the command; the agent cannot change it after you saw it.
- A request is tied to the item as you saw it. If someone comments or the item changes, the request is refused and asked again.
- A reply is tied to the exact text of its draft file. Edit the draft and the agent asks again with the new text.
- Each approval is used once.
- Scheduled runs never write to GitHub. They read, sort and prepare requests.
- On top of that, setup sets this agent's exec mode to `ask`, so OpenClaw prompts you for every command you have not allowed. You allow the read commands once; write commands prompt every time.

These are the agent's rules plus OpenClaw's approval prompt. The agent uses your own `gh` login, which can do anything you can. It is not a sandbox.

## What it never does

Merge, approve or review PRs, assign people, remove labels, edit titles or bodies, lock, transfer or delete anything, @-mention anyone, promise fixes or dates, or reply publicly to something that looks like a security report.

## Requirements

- OpenClaw with Templates turned on (**Settings → Labs**, or `gateway.controlUi.experimental.templates` set to `true` on a headless install).
- On the Gateway host: `gh` logged in with read access to your repositories (write access for the actions you approve), Node 22 or newer, and sqlite3 3.38 or newer with FTS5. The stock macOS sqlite3 has both.
- A model that follows long instructions well. Triage quality depends on it.
- Model cost: a run is one agent turn that triages at most `max_triage_per_run` items (25 by default). Cost depends on your model.

## Add it

Not published on ClawHub yet. From a local checkout of this repository, with the Gateway stopped:

```sh
openclaw templates add ./templates/repo-maintainer-helper
```

Then open the new agent's chat. Setup asks for your repositories, locks its commands behind the approval prompt, creates the database, runs one pass, and helps you turn on the schedule.

## Settings

`settings.md` in the agent's workspace. The main ones:

| Setting | Default | What it does |
|---------|---------|--------------|
| `repos` | none | Up to 5 `owner/repo` names |
| `allowed_actions` | `add-labels, comment` | Which writes it may suggest; add `close` for spam and duplicates |
| `max_triage_per_run` | 25 | Items per run, oldest change first |
| `backlog_days` | 14 | On the first read, only items changed this recently are triaged |
| `close_duplicates` | false | Suggest closing confirmed duplicates |

## How it reads GitHub

One command per repository: `node references/fetch.mjs <owner/repo>`. It runs four fixed `gh` reads with no shell (the 100 most recently updated issues, the 50 most recently updated PRs, the label list, and up to 1000 issue titles for the duplicate check) and writes them to `inbox/`. A SQL step loads them into the database. If more than 100 issues or 50 PRs changed between runs, the digest says some changes may be missed.

## Data

- The database at `db_path` (default `~/repo-maintainer-helper.db`) holds items, triage notes, requests and your answers. It is outside the workspace, so deleting and re-adding the agent keeps the history.
- `inbox/` holds the latest raw reads; `drafts/` holds reply drafts. Both are in the workspace.
- Issue and PR text is public data from your repositories. It is stored in plain text on the Gateway host.

## Remove it

```sh
openclaw agents delete <agent-id>
```

This removes the workspace and the automation. Delete the file at `db_path` too if you do not want the history.

## Tested, and not yet

- Tested on macOS with gh 2.102, Node 24 and sqlite3 3.54:
  - every SQL step and every approval check (`tests/`), with fixtures in the exact shape of real `gh` output
  - `fetch.mjs` against a stand-in `gh`
  - a live read-only pass on a public repository: fetch, ingest, the triage queue and the duplicate search
  - `openclaw templates validate`, `dev`, and `add --dry-run`
- Not yet: a full Add with a model turn, the daily automation running for days on a live repository, a write approved end to end on a throwaway repository, and Linux.

## License

MIT. See [LICENSE](LICENSE).

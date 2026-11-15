# Operating workflow

## Start here

Read or confirm:

- settings.md: repositories, db_path, run limits, allowed actions, digest style
- references/triage-loop.md: the commands, the steps, the scheduled run, and how to answer the owner's requests
- the database at db_path, only through the packaged SQL steps

If settings.md is missing, BOOTSTRAP.md has not finished: run setup first.

## Included capability boundaries

- The profile is `minimal` plus read, write, edit, exec and session_status. The `gateway` tool is denied. There is no messaging tool, no browser and no MCP server. GitHub is reached only through `gh` under exec.
- File tools are limited to this workspace. workspaceOnly does not sandbox exec, and `gh` runs with the owner's full login. Setup sets this agent's exec mode to `ask` and makes references/ read-only, so OpenClaw asks the owner before every command they have not allowed with "Always allow here". The rules in SOUL.md apply on top of that prompt.
- The commands the owner may allow once are the per-repository fetch and the packaged SQL steps, exactly as triage-loop.md spells them. Every `gh` write command asks every time.

## Process

1. Scheduled run (the Daily triage automation): triage-loop.md, "Scheduled run". Reads, triage, requests and the digest only. No writes to GitHub.
2. The owner answers requests in chat: triage-loop.md, "Answering requests". Each write is one granted, used-once approval for the exact command.
3. A manual pass when the owner asks ("triage now", "check my repos"): the same steps as a scheduled run with run-start kind `manual`. In the same chat, the owner may then answer the requests right away.
4. Questions about the history ("what did you close last week?"): answer from the digest step of the runs in question, or say what the database does not hold.

## Example setting

```
- repos:
  example-org/example-repo
- backlog_days: 14
- max_triage_per_run: 25
- allowed_actions: add-labels, comment
```

## Standard deliverables

- The digest at the end of every run, from templates/digest.md
- Draft replies in drafts/, one file per item, named by ask-approval
- One line per answered request: the command, done or failed, and the link

## Done when

- Every repository in settings.md was fetched and ingested, or its fetch error is in the digest
- Every item to-triage returned in this run has a saved triage, or the digest says why not
- Every request this run prepared is in the digest with its exact command
- No GitHub write ran without a granted, used approval, and every used approval has an outcome

# Changelog

## 0.1.0

First version.

- A paused daily automation reads the issues and PRs that changed on up to 5 repositories, with one fixed read-only command per repository (`node references/fetch.mjs <owner/repo>`), so the owner can allow it once.
- Triage into bug, feature, question, docs, duplicate, needs-info, spam, ready-for-review or other, with a duplicate check against the titles of up to 1000 issues (SQLite FTS5, no extra GitHub calls).
- Suggested labels come only from the repository's own label list. Replies are drafted to files, never put on a command line.
- Every GitHub write is an owner approval in chat for a command the database builds itself, bound to the item as the owner saw it and, for a reply, to the exact draft bytes. Used once.
- The first read of a repository triages only the last `backlog_days`. The digest names reads that may have missed changes.

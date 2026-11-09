# Tracker

The agent appends one row per posting it touched and updates the status of its own rows as things move. It checks this table to avoid duplicates. Do not delete rows. You may change a status by hand, for example `ready-for-owner-review` to `applied`, or `applied` to `interviewing`.

Status:
- Pipeline: `prospect`, `ready-for-owner-review`, `applied`, `interviewing`, `offer-review`, `closed`.
- Agent outcomes: `skipped`, `dry-run`, `held`, `handoff`.

Final (never retried): `applied`, `interviewing`, `offer-review`, `closed`, `handoff`, and `skipped` for any reason except "unknown question".

`held` and `ready-for-owner-review` rows get at most one automatic retry, on a later day, in confirm mode only. After that the row is yours: close it by editing the status.

| date | company | title | link | fit reason | flagged answers | status | note |
| ---- | ------- | ----- | ---- | ---------- | --------------- | ------ | ---- |

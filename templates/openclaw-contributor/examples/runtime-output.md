# Example: a filled Runtime output section

Illustrative. This shows the shape hosted ClawSweeper asked for on a real PR: a scheduled send to a busy CLI session, where the review wanted "inspectable runtime output linking queue acceptance, occurrence completion, and the receiver's successful reply". The session ids, times, SHAs and log text below are made up and shortened for this example; a real body copies them from `evidence/<slug>/runtime-base.log` and `runtime-head.log`.

---

### Runtime output

Setup: isolated Gateway from this checkout, own state folder, loopback port 38973, no channels. The CLI backend is a stub that answers after 20 s, so the receiver is busy when the scheduled send arrives.

**Before, on main `1a2b3c4d5e6`**

Commands, in the order they ran (the last one is the trigger):

```sh
env -u OPENCLAW_PROFILE -u OPENCLAW_SUPERVISOR_MODE -u OPENCLAW_GATEWAY_URL -u OPENCLAW_GATEWAY_TOKEN -u OPENCLAW_GATEWAY_PASSWORD OPENCLAW_STATE_DIR=<workspace>/evidence/demo/state OPENCLAW_CONFIG_PATH=<workspace>/evidence/demo/state/openclaw.json OPENCLAW_GATEWAY_PORT=38973 node <checkout>/openclaw.mjs gateway run --port 38973 --bind loopback
node <workspace>/evidence/demo/stub-cli.mjs --delay 20
env -u OPENCLAW_PROFILE -u OPENCLAW_SUPERVISOR_MODE -u OPENCLAW_GATEWAY_URL -u OPENCLAW_GATEWAY_TOKEN -u OPENCLAW_GATEWAY_PASSWORD OPENCLAW_STATE_DIR=<workspace>/evidence/demo/state OPENCLAW_CONFIG_PATH=<workspace>/evidence/demo/state/openclaw.json OPENCLAW_GATEWAY_PORT=38973 node <checkout>/openclaw.mjs automations run handoff-demo
```

Output (redacted, 6 of 412 lines; the cut marker stands for the lines between them; full log: inline excerpt only):

```text
18:02:11.204 cron  occurrence=occ_7f2 start job=handoff-demo
18:02:11.389 queue session=sess_recv accepted item=itm_41 (receiver busy, queued)
18:02:11.402 cron  occurrence=occ_7f2 end status=ok
[... 37 lines cut ...]
18:02:31.877 queue session=sess_recv dequeue item=itm_41
18:02:31.880 agent session=sess_recv turn failed: Cron occurrence source authority is no longer active
18:02:31.881 queue session=sess_recv item=itm_41 dropped
```

At 18:02:11.389 the send is queued as item itm_41, at 18:02:11.402 the sender's occurrence ends, and at 18:02:31.880 the receiver fails on that same item once it dequeues.

**After, on this branch `5d6e7f8a9b0`**

Commands, in the order they ran (the last one is the trigger):

```sh
env -u OPENCLAW_PROFILE -u OPENCLAW_SUPERVISOR_MODE -u OPENCLAW_GATEWAY_URL -u OPENCLAW_GATEWAY_TOKEN -u OPENCLAW_GATEWAY_PASSWORD OPENCLAW_STATE_DIR=<workspace>/evidence/demo/state OPENCLAW_CONFIG_PATH=<workspace>/evidence/demo/state/openclaw.json OPENCLAW_GATEWAY_PORT=38973 node <checkout>/openclaw.mjs gateway run --port 38973 --bind loopback
node <workspace>/evidence/demo/stub-cli.mjs --delay 20
env -u OPENCLAW_PROFILE -u OPENCLAW_SUPERVISOR_MODE -u OPENCLAW_GATEWAY_URL -u OPENCLAW_GATEWAY_TOKEN -u OPENCLAW_GATEWAY_PASSWORD OPENCLAW_STATE_DIR=<workspace>/evidence/demo/state OPENCLAW_CONFIG_PATH=<workspace>/evidence/demo/state/openclaw.json OPENCLAW_GATEWAY_PORT=38973 node <checkout>/openclaw.mjs automations run handoff-demo
```

Output (redacted, 6 of 405 lines):

```text
18:41:07.015 cron  occurrence=occ_a10 start job=handoff-demo
18:41:07.190 queue session=sess_recv accepted item=itm_9 (receiver busy, queued)
18:41:07.204 cron  occurrence=occ_a10 end status=ok
[... 35 lines cut ...]
18:41:27.660 queue session=sess_recv dequeue item=itm_9
18:41:27.664 agent session=sess_recv turn start source=itm_9
18:41:29.102 agent session=sess_recv reply delivered: HANDOFF-OK
```

Same sequence: queued as itm_9 at 18:41:07.190, sender done at 18:41:07.204, and the receiver now runs itm_9 (18:41:27.664) and replies (18:41:29.102).

Not shown: a real CLI backend login; the stub stands in at the CLI process boundary.

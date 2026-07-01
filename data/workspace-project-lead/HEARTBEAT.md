# HEARTBEAT.md — Atlas's periodic checklist

Each heartbeat poll, in order. If everything is green, reply `HEARTBEAT_OK` and stay quiet.

1. **Inbox scan.** Any new messages in `inbox/`? If yes → process them in arrival order per `WORKFLOWS.md` MONITOR state.
2. **Board health.** Open `docs/board.md`. Any ticket in `in_progress` whose `last_updated` is older than 24 cycles? Send a nudge to its owner.
3. **Blocked tickets.** Any ticket in `blocked`? If the blocker is a user decision, ensure an `escalation` exists; if not, send one.
4. **Risk register.** Any risk whose `review_by` date is today? Reopen it.
5. **Weekly status due?** If 7 days since last `weekly-status` run, trigger the skill.
6. **STANDBY check.** If `docs/` does not exist, do nothing except wait for the user to trigger `onboard-project`.

Quiet hours (23:00–08:00 user local): no nudges, no user messages, only audit-log scans.

If nothing matched, reply `HEARTBEAT_OK`.

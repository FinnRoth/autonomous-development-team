# HEARTBEAT.md — Atlas's periodic checklist

Each heartbeat poll, in order. If everything is green, reply `HEARTBEAT_OK` and stay quiet.

1. **Unread comments.** Call `board_get_unread(agent="project-lead")`. Any new comments (on project tickets or `SYSTEM-00`)? If yes → process them in arrival order per `WORKFLOWS.md` MONITOR state, then `board_ack_comment` each.
2. **Board health.** Call `board_list_tickets(status="in_progress")`. Any ticket where `updated_at` is older than 24 cycles? Send a nudge to its `claimed_by` agent.
3. **Blocked tickets.** Call `board_list_tickets(status="blocked")`. For each: confirm the blocker is being addressed. If the blocker is a user decision, ensure an `escalation` exists; if not, send one.
4. **Risk register.** Call `board_list_tickets()` and scan for any risk whose `review_by` date is today. Reopen it.
5. **Weekly status due?** If 7 days since last `weekly-status` run, trigger the skill.
6. **STANDBY check.** If no tickets exist in board-api, do nothing except wait for the user to trigger `onboard-project`.

Quiet hours (23:00–08:00 user local): no nudges, no user messages, only audit-log scans.

If nothing matched, reply `HEARTBEAT_OK`.

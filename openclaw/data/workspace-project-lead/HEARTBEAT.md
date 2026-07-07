# HEARTBEAT.md — Atlas's periodic checklist

Each heartbeat poll, in order. If everything is green, reply `HEARTBEAT_OK` and stay quiet.

1. **Inbox scan.** Any new messages in `inbox/`? If yes → process them in arrival order per `WORKFLOWS.md` MONITOR state.
2. **Board sync.** Call `board_get_board()`. Regenerate `docs/<docs-repo-name>/board.md` if content differs from current. Commit and push if changed.
3. **Board health.** Call `board_list_tickets(status="in_progress")`. Any ticket where `updated_at` is older than 24 cycles? Send a nudge to its `claimed_by` agent.
4. **Blocked tickets.** Call `board_list_tickets(status="blocked")`. For each: confirm the blocker is being addressed. If the blocker is a user decision, ensure an `escalation` exists; if not, send one.
5. **Risk register.** Any risk whose `review_by` date is today? Reopen it.
6. **Weekly status due?** If 7 days since last `weekly-status` run, trigger the skill.
7. **STANDBY check.** If `docs/` does not exist, do nothing except wait for the user to trigger `onboard-project`.

Quiet hours (23:00–08:00 user local): no nudges, no user messages, only audit-log scans.

If nothing matched, reply `HEARTBEAT_OK`.

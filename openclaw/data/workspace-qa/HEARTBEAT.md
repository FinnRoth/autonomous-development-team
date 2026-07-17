# HEARTBEAT — Krell 🐛

On each heartbeat, in order:

1. Append wake line to `memory/YYYY-MM-DD.md`: `[HEARTBEAT] <ISO>`.

2. **STANDBY check.** If `docs/` does not exist, emit `HEARTBEAT_STANDBY` and stop.

3. `git pull --ff-only` in the docs repo. (Picks up new tickets and merged PRs.)

4. **Process unread comments.** Call `board_get_unread(agent="qa")`. For each comment addressed to me (`handoff` / `question` / `escalation`), process per `WORKFLOWS.md`, then call `board_ack_comment(comment_id=<id>, agent="qa")`.

5. **Proactive board scan.** Call `board_list_tickets(status="qa")`. For each Story with no `docs/qa/cases/<story-id>.md`: treat as missed intake and enter INTAKE state.

6. **Bug reminder pass.** Check open bug reports in `docs/qa/bug-reports/`. For each `status: open` bug older than 24h with no response from the suspected owner: post a reminder `handoff` comment to the suspected owner with `notify=["project-lead"]`.

7. **Log.** If nothing actionable: append `HEARTBEAT_OK` to `memory/YYYY-MM-DD.md` and stop. Otherwise log the action(s) taken.

Keep this file short — token burn during quiet periods is wasted.

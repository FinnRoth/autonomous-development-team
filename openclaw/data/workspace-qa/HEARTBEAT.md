# HEARTBEAT — Krell 🐛

On each heartbeat, in order:

1. Append wake line to `memory/YYYY-MM-DD.md`: `[HEARTBEAT] <ISO>`.

2. **STANDBY check.** If `docs/` does not exist, emit `HEARTBEAT_STANDBY` and stop.

3. `git pull --ff-only` in the docs repo. (Picks up new tickets and merged PRs.)

4. **Inbox scan.** Scan `inbox/` for unprocessed messages. Each new message → process per `WORKFLOWS.md`. Archive processed messages to `inbox/archive/YYYY-MM-DD/`.

5. **Proactive board scan.** Call `board_list_tickets(status="qa")`. For each Story with no `docs/qa/cases/<story-id>.md`: treat as missed intake and enter INTAKE state.

6. **Bug reminder pass.** Check open bug reports in `docs/qa/bug-reports/`. For each `status: open` bug older than 24h with no response from the suspected owner: send a reminder handoff (CC project-lead).

7. **Log.** If nothing actionable: append `HEARTBEAT_OK` to `memory/YYYY-MM-DD.md` and stop. Otherwise log the action(s) taken.

Keep this file short — token burn during quiet periods is wasted.

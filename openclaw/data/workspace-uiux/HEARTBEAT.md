# HEARTBEAT — Iris 🎨

On each heartbeat cycle:

1. **Append wake line** to `memory/YYYY-MM-DD.md`: `[HEARTBEAT] <ISO>`.

2. **STANDBY check** — if board-api empty or project not onboarded, emit `HEARTBEAT_STANDBY` and stop.

3. **Self-assign check** — call `board_get_ready_tickets(owner="uiux")`.
   - If tickets returned: claim highest-priority one via `board_claim_ticket(ticket_id=<id>, agent="uiux")`.
   - On 200: enter CLAIM state per `WORKFLOWS.md`.
   - On 409: re-poll once.

4. **Process inbox** — scan `inbox/` for handoffs from project-lead (design context), questions from frontend/architect.

5. **In-flight check** — continue active design work if in progress.

6. **Log** `HEARTBEAT_OK` if nothing actionable.

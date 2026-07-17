# HEARTBEAT — Vela 💠

On each heartbeat cycle, in this order:

1. **Append wake line** to `memory/YYYY-MM-DD.md`: `[HEARTBEAT] <ISO>`.

2. **STANDBY check** — if board-api is empty or project is not yet onboarded, emit `HEARTBEAT_STANDBY` and stop.

3. **Self-assign check** — call `board_get_ready_tickets(owner="frontend")`.
   - If one or more tickets returned:
     a. Select the first ticket (highest priority, FIFO within priority).
     b. Call `board_claim_ticket(ticket_id=<id>, agent="frontend")`.
     c. On 200: transition workflow to CLAIM state → run `claim-task` skill.
     d. On 409: re-call `board_get_ready_tickets` once. Take next ticket if available.
   - Note: A 409 because uiux depends_on are not done means the frontend ticket's UI spec is not complete yet — expected behavior, not an error.

4. **Process unread comments** — call `board_get_unread(agent="frontend")`. For each comment addressed to me (`handoff` from uiux (UI spec ready), architect (contract changes), `question`, or `escalation`), handle it per `WORKFLOWS.md`, then call `board_ack_comment(comment_id=<id>, agent="frontend")`.

5. **In-flight check** — if currently working on a ticket (`in_progress`): continue the implementation state machine per `WORKFLOWS.md`. Check for review feedback on the current PR.

6. **Log** — if nothing actionable: append `HEARTBEAT_OK` to memory and stop.

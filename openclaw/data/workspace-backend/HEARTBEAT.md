# HEARTBEAT — Forge 🔧

On each heartbeat cycle, in this order:

1. **Append wake line** to `memory/YYYY-MM-DD.md`: `[HEARTBEAT] <ISO>`.

2. **STANDBY check** — if board-api returns empty or project is not yet onboarded, emit `HEARTBEAT_STANDBY` and stop.
   (Check: call `board_list_tickets()` — if the response is empty and no docs repo exists, assume STANDBY.)

3. **Self-assign check** — call `board_get_ready_tickets(owner="backend")`.
   - If one or more tickets returned:
     a. Select the first ticket (highest priority, FIFO within priority — already ordered by the API).
     b. Call `board_claim_ticket(ticket_id=<id>, agent="backend")`.
     c. On 200: transition workflow to CLAIM state → run `claim-task` skill.
     d. On 409: re-call `board_get_ready_tickets` once (the first ticket was race-claimed). Take the next one if available.

4. **Process unread comments** — call `board_get_unread(agent="backend")`. For each comment addressed to me (`handoff`, `question`, `escalation`, or a review-change notification), handle it per `WORKFLOWS.md`, then call `board_ack_comment(comment_id=<id>, agent="backend")`.

5. **In-flight check** — if currently working on a ticket (`in_progress`): continue the implementation state machine per `WORKFLOWS.md`. Re-check `board_get_unread` for new comments or review feedback on the current PR's ticket.

6. **Log** — if nothing actionable: append `HEARTBEAT_OK` to memory and stop.

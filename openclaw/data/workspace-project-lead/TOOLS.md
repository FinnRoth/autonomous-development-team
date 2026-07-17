## board-api-pl

Task board API — full access for project-lead (ticket creation + metadata editing) AND the messaging channel.

**All tools available:**
- `board_create_ticket` — create Epic/Story/Task/Bug tickets in board-api (project-lead only)
- `board_update_ticket` — update ticket metadata (title, acceptance, depends_on, owner, etc.) (project-lead only)
- `board_get_ready_tickets` — check what is ready per agent role
- `board_claim_ticket` — atomic claim
- `board_get_ticket` — read full ticket details + comments (use to reconstruct handoff history)
- `board_list_tickets` — list with filters
- `board_transition_ticket` — transition status
- `board_add_comment` — post a `handoff`/`question`/`escalation`/`info` comment (the messaging channel); set `to` (required for the three actionable types), optional `notify`, optional `from_ticket`
- `board_get_unread` — poll for comments addressed to me (heartbeat notification); reads project tickets and `SYSTEM-00`
- `board_ack_comment` — mark a comment read/handled
- `board_get_board` — full board snapshot
- `board_get_deps` — check dependency completion status

## Messaging — via `board-api` comments

- **Purpose:** all agent-to-agent messages. Post with `board_add_comment` (fields: `to`, `type` ∈ `handoff|question|escalation|info`, `notify`, `from_ticket`); read with `board_get_unread(agent="project-lead")`; clear with `board_ack_comment`.
- **Schemas:** frozen — see CONVENTIONS.md §4. My role-specific examples live in `PROTOCOLS.md`.
- A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).
- **Talking to the user:** I am the only agent that addresses the user, and I do so via chat — never via a comment `to: "user"`.
- **`sessions_send`** (OpenClaw built-in) is retained ONLY as a contentless wake-nudge so I can prompt a sleeping worker to run its heartbeat sooner. It never carries a handoff/question/escalation payload.
- `SYSTEM-00` (seeded automatically by board-api at container startup) is the non-ticket channel where boot-time/cross-cutting escalations arrive; I read them via `board_get_unread`.


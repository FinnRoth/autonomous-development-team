## board-api-pl

Task board API — full access for project-lead (ticket creation + metadata editing).

**All tools available:**
- `board_create_ticket` — create Epic/Story/Task/Bug tickets in board-api
- `board_update_ticket` — update ticket metadata (title, acceptance, depends_on, owner, etc.)
- `board_get_ready_tickets` — check what is ready per agent role
- `board_claim_ticket` — atomic claim
- `board_get_ticket` — read full ticket details
- `board_list_tickets` — list with filters
- `board_transition_ticket` — transition status
- `board_add_comment` — add comment to ticket thread
- `board_get_board` — full board snapshot (used to regenerate docs/board.md)
- `board_get_deps` — check dependency completion status

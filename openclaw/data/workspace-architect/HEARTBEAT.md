# HEARTBEAT — Architect (Cassius 🏛️)

Periodic checklist. Run on each session start and on each heartbeat cycle.

## Checklist

1. `git -C repos/<docs-slug> pull --ff-only` — ensure docs repo is current.
2. Call `board_get_unread(agent="architect")` — handle each comment addressed to me (`handoff` / `question` / `escalation`) per `WORKFLOWS.md`, then `board_ack_comment(comment_id=<id>, agent="architect")`.
3. Scan `docs/<docs-repo-name>/architecture/adr/` for any ADR with `status: proposed` older than 1 cycle — if found, post a `question` comment to `project-lead` asking for reviewer assignment.
4. Check `docs/<docs-repo-name>/architecture/adr/` for any ADR with `status: accepted` that lacks a corresponding entry in the relevant code repo's `.architecture/contracts/` (if the ADR implied a contract change) — drift detected → enter AUDIT state.
5. Call `board_get_ready_tickets(owner="architect")` — any architectural tickets ready to claim? If returned, claim the highest-priority one via `board_claim_ticket` and enter INTAKE state.
6. If none of the above triggers: write `HEARTBEAT_OK` to `memory/YYYY-MM-DD.md` and remain in IDLE.

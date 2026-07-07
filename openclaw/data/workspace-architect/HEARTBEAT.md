# HEARTBEAT — Architect (Cassius 🏛️)

Periodic checklist. Run on every session start when no `inbox/` message is pending, and on each heartbeat cycle.

## Checklist

1. `git -C repos/<docs-slug> pull --ff-only` — ensure docs repo is current.
2. Scan `docs/<docs-repo-name>/architecture/adr/` for any ADR with `status: proposed` older than 1 cycle — if found, file a `question` to `project-lead` asking for reviewer assignment.
3. Check `docs/<docs-repo-name>/architecture/adr/` for any ADR with `status: accepted` that lacks a corresponding entry in the relevant code repo's `.architecture/contracts/` (if the ADR implied a contract change) — drift detected → enter AUDIT state.
4. Call `board_get_ready_tickets(owner="architect")` — any architectural tickets ready to claim? If returned, claim the highest-priority one via `board_claim_ticket` and enter INTAKE state.
5. If none of the above triggers: write `HEARTBEAT_OK` to `memory/YYYY-MM-DD.md` and remain in IDLE.

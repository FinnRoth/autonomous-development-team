# HEARTBEAT — Architect

Rotate through these on each heartbeat poll. Do not check all every time; pick 1-2.

- [ ] `inbox/` — any new `handoff`/`question`/`escalation`? If yes, process per `WORKFLOWS.md`.
- [ ] `docs/board.md` — any ticket in state `in_progress` waiting on an ADR I owe?
- [ ] `docs/architecture/adr/` — any ADR stuck in `proposed` for >2 cycles? Nudge `project-lead` via `question`.
- [ ] `docs/architecture/api/openapi.yaml` — re-run `validate-openapi` if a contract change PR was merged.
- [ ] `project/.architecture/contracts/` — drift check vs. `openapi.yaml`. If drift, re-run `generate-contracts`.
- [ ] Folder structure audit — run `audit-folder-structure` weekly (every ~14 heartbeats).

If nothing actionable, reply `HEARTBEAT_OK`.

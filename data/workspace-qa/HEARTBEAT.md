# HEARTBEAT — Krell

On each heartbeat, in order:

1. `git pull` in `docs/` (cheap, picks up new tickets and merged PRs).
2. Scan `inbox/` for unprocessed messages. Each new message → process per `WORKFLOWS.md`.
3. Scan `docs/board.md` — any Story in `qa` column with no case file? That's a missed intake; enter INTAKE.
4. Check my open bugs in `docs/qa/bug-reports/`. For each `status: open` bug older than 24h with no response from the suspected owner: send a reminder handoff (CC project-lead).
5. Reply `HEARTBEAT_OK` if nothing changed. Otherwise log the action taken in `memory/YYYY-MM-DD.md`.

Keep this file short — token burn during quiet periods is wasted.

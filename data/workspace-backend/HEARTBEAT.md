# HEARTBEAT — Forge 🔧

Every wake, before any action:

1. Append a line to `memory/YYYY-MM-DD.md`: `<ISO timestamp> wake — state=<current state> ticket=<id or none>`.
2. Run the AGENTS.md startup read order.
3. If `project/` or `docs/` are absent, output the STANDBY line (CONVENTIONS.md §9) and stop.
4. Process `inbox/` before advancing the workflow.

Every sleep:

1. Append a line: `<ISO timestamp> sleep — state=<current state> ticket=<id or none> next=<planned next action>`.
2. Commit any unfinished thought to `MEMORY.md` (one-line summary, not a wall of text).

# Heartbeat — Mira 🔍 (reviewer)

On every wake (heartbeat tick):

1. Verify `project/` and `docs/` exist. If not → emit STANDBY (CONVENTIONS.md §9) and stop.
2. `git -C docs pull --ff-only`.
3. Read `ROLE.md`, `WORKFLOWS.md`, `CONVENTIONS.md`, `PROTOCOLS.md` (in that order).
4. Enter WORKFLOWS.md State 1 (IDLE) and execute its actions.
5. On any uncaught error, log to `MEMORY.md` and stop the tick. Do not retry blindly.

I do not initiate work; my heartbeat is reactive. A handoff in `inbox/` or a scheduled audit drives every cycle.

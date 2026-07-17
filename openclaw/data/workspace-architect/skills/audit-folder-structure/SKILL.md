---
name: audit-folder-structure
description: Diff the actual project/ tree against the canonical layout in docs/architecture/folder-structure.md and report drift.
trigger: Weekly via heartbeat (every ~14 heartbeats); also on demand from project-lead; also at AUDIT state.
inputs:
  - docs/architecture/folder-structure.md (canonical layout, declared as a fenced tree block)
  - project/ tree (live)
outputs:
  - docs/architecture/audit-folder-<YYYY-MM-DD>.md (always written)
  - exit code 0 if zero drift; non-zero otherwise
---

# Procedure

1. Parse `docs/architecture/folder-structure.md`. The canonical layout MUST be inside a fenced block of the form:
   ```
   ```text canonical
   project/
   ├── backend/
   │   ├── src/
   │   └── tests/
   ├── frontend/
   │   ├── src/
   │   └── tests/
   ├── qa-tests/
   └── .architecture/
       └── contracts/
   ```
   ```
   If no such block exists, FAIL with "folder-structure.md missing `text canonical` block".
2. Normalize the canonical tree to a set of relative paths (directories only, no trailing slash).
3. Walk `project/` (skipping `.git`, `node_modules`, `__pycache__`, `dist`, `build`, `.venv`, `.next`). Collect the set of directories down to depth 4.
4. Compute three sets:
   - `expected_only` — directories in canonical but missing in live (severity: high if listed in folder-structure.md as `required`).
   - `live_only` — directories in live but not in canonical (severity: med — likely undocumented).
   - `matched` — present in both.
5. Apply allowlists: any directory marked `optional` in folder-structure.md is ignored if missing from live; any directory marked `feature/*` is ignored from `live_only` checks.
6. Write report to `docs/architecture/audit-folder-<YYYY-MM-DD>.md` with sections:
   - `## Summary` — counts of expected_only / live_only / matched.
   - `## Missing (drift: high)` — bullet list of `expected_only`.
   - `## Undocumented (drift: med)` — bullet list of `live_only`.
   - `## Matched` — count only (no list, to keep report short).
   - `## Verdict` — `zero-drift` or `drift-detected`.
7. If verdict is `drift-detected`:
   - Post a `handoff` comment to `project-lead` summarizing the drift. PL decides whether to forward as a task to backend/frontend or to me (for folder-structure.md update).
   - Exit non-zero.
8. If verdict is `zero-drift`, exit 0.
9. Append `memory/YYYY-MM-DD.md`: `audit-folder-structure → <verdict>`.

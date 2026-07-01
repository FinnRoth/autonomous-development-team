---
name: run-tests
description: Standard test-suite runner with focus mode for touched files plus full-suite gating.
trigger: TEST state, also re-run inside SELF_REVIEW and ADDRESS_REVIEW after every code change.
inputs: TICKET_ID, optional FOCUS_PATHS (defaults to git diff vs origin/main).
outputs: green/red verdict per phase; failure summary if red.
---

# run-tests

Deterministic procedure. Phases run in order; later phases are gated by earlier ones.

1. **Identify focus paths**
   - If `FOCUS_PATHS` given, use them.
   - Else:
     ```sh
     cd project
     git fetch origin main
     git diff --name-only origin/main..HEAD | grep '^project/backend/' > /tmp/forge-focus.txt
     ```
   - Map source files to their test files using the project convention (mirror under `project/backend/tests/`).

2. **Lint focus**
   - Run the project's lint command scoped to focus paths.
   - Zero new warnings. Fail-fast on first error.

3. **Format check focus**
   - Run the project's formatter in `--check` mode on focus paths.
   - Any drift → run formatter for real, then re-check, then commit `[<TICKET-ID>] format`.

4. **Type-check whole backend**
   - Always whole-package; types compose across files.
   - Any error → STOP, return to IMPLEMENT.

5. **Focused unit tests**
   - Run the project's test command in focus mode on the focus test files.
   - Must be 100% pass. No `skip`, no `pending`, no `.only`.

6. **Full backend suite**
   - Run the project's full test command for `project/backend/`.
   - Must be 100% pass.
   - Pre-existing failure unrelated to my change → STOP, file `escalation` to project-lead. Do NOT proceed; do NOT skip the test.

7. **Migration dry-run** (only if `project/migrations/` is in focus)
   - Scratch DB.
   - `migrate up`, `migrate down`, `migrate up`.
   - Any failure → return to `write-migration` step 4.

8. **Coverage spot-check** (informational, not gating unless project has a hard floor in ADR)
   - For each new function/handler in focus, confirm at least one test asserts behavior.
   - Missing coverage → return to IMPLEMENT.

9. **Emit a verdict line** to memory:
   ```
   run-tests <TICKET-ID> <ISO>: lint=PASS format=PASS types=PASS focus=PASS full=PASS migrations=PASS|N/A
   ```

10. **On any FAIL** in any phase: STOP, do not advance the workflow, return to the state that owns the fix (IMPLEMENT for code, write-migration for migrations).

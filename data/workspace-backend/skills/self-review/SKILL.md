---
name: self-review
description: Pre-PR checklist — lint, format, type-check, scope-creep grep, test counts on touched files. Outputs a written checklist.
trigger: SELF_REVIEW state, after TEST passed.
inputs: TICKET_ID, current branch.
outputs: a checklist note in memory/YYYY-MM-DD.md; pass/fail decision for the OPEN_PR transition.
---

# self-review

Deterministic procedure. Every item is pass/fail. Any fail returns to IMPLEMENT or TEST.

1. **Identify touched files**
   ```sh
   cd project
   git fetch origin main
   git diff --name-only origin/main..HEAD > /tmp/forge-touched.txt
   ```

2. **Scope-creep grep** — every line in `/tmp/forge-touched.txt` MUST match one of:
   - `^project/backend/`
   - `^project/migrations/`
   - `^\.env\.example$`
   On any miss: STOP. List violating paths. Either:
   - Revert the file (`git checkout origin/main -- <path>`), OR
   - File an `escalation` to project-lead if the change was actually needed in another agent's area.

3. **Lint** on touched files (per project's lint command from `docs/architecture/folder-structure.md` or `package.json`/`pyproject.toml`). Must pass with zero new warnings.

4. **Format check** on touched files. Must pass.

5. **Type-check** the whole backend package. Must pass.

6. **Touched-files test coverage**
   - For each `.ts`/`.py`/`.go`/etc. under `project/backend/src/` in the touched list: assert a corresponding test file exists under `project/backend/tests/` mirroring the path.
   - Missing test file → fail.

7. **Test counts**
   - Run focused test command on touched files.
   - Run full backend suite.
   - Both must be green.

8. **Migration check** (only if `project/migrations/` was touched)
   - Each new migration filename has both an `up` and a `down` (or framework equivalent).
   - Dry-run `migrate up && migrate down && migrate up` on a scratch DB.
   - Fail on any error.

9. **Dependency check**
   - `git diff origin/main..HEAD -- '**/package.json' '**/requirements*.txt' '**/pyproject.toml' '**/go.mod' '**/pom.xml' '**/build.gradle*'`
   - For every added runtime dependency: assert an ADR ID in `docs/architecture/ADR-*.md` mentions it, OR an explicit architect `handoff` exists in `inbox/archive/` approving it.
   - Missing justification → file a `question` to architect, mark check as fail.

10. **PR template readiness** — confirm I can fill every section:
    - Ticket link.
    - Summary (1–3 sentences).
    - Acceptance — copy-paste from ticket frontmatter, each item checkable.
    - Changes — bullet by file/module.
    - Tests — list new/changed tests + how to run.
    - Out-of-scope.
    - Risks.

11. **Acceptance audit** — for every acceptance criterion in the ticket:
    - State which test(s) cover it.
    - If uncovered, fail.

12. **Write the checklist** to `memory/YYYY-MM-DD.md` as:
    ```
    self-review <TICKET-ID> <ISO>:
      [x] scope clean
      [x] lint
      [x] format
      [x] type-check
      [x] test files exist
      [x] tests green (focused + full)
      [x] migrations reversible (or N/A)
      [x] dependencies justified (or N/A)
      [x] PR template fields ready
      [x] acceptance mapped to tests
    ```

13. **Decide**
    - All checks pass → transition to OPEN_PR.
    - Any fail → fix and re-run self-review from step 1.

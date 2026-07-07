---
name: bootstrap-test-plan
description: Produce the first-cut docs/qa/test-plan.md once the project's architecture is acceptance-ready. This file is the top-of-project QA strategy doc and is owned by QA.
trigger: Onboard-handoff from project-lead naming this role for the first time, OR an architect handoff announcing ADR-001 acceptance. Skip (no-op) if docs/qa/test-plan.md already exists at the target schema version.
inputs:
  - docs/architecture/overview.md (if present)
  - docs/architecture/openapi.yaml (if present)
  - docs/architecture/folder-structure.md (if present)
  - board_list_tickets() results (for story-shape sanity)
outputs:
  - docs/qa/test-plan.md (new file)
  - PR via gh on docs repo branch qa/test-plan-bootstrap
---

# bootstrap-test-plan

Deterministic first-time creation of the top-level QA strategy doc. Run ONCE per project. Skill is idempotent: if `docs/qa/test-plan.md` already exists, exit early after logging.

## Steps

1. **Pre-check.** If `docs/qa/test-plan.md` already exists, log `bootstrap-test-plan: skipped, test-plan.md already present` to `memory/YYYY-MM-DD.md` and EXIT. Never overwrite the file from here — subsequent edits go through normal PR flow.

2. **Read architecture inputs (best-effort).** For each of:
   - `docs/architecture/overview.md`
   - `docs/architecture/openapi.yaml`
   - `docs/architecture/folder-structure.md`

   If the file exists, parse it for: stack components (frontend framework, backend runtime, DB), public endpoints, deployment targets. If a file is missing, note it in the test-plan under "Open assumptions" and continue.

3. **Decide environments.** Default matrix:
   - `local` — `FRONTEND_URL=http://localhost:5173`, `BACKEND_URL=http://localhost:8080`. Source: `docs/project/dev-env.md`.
   - `staging` — TBD; placeholder until project-lead seeds the URL.
   - `prod` — read-only smoke; never destructive.

4. **Decide tooling.** Default: Playwright (chromium + firefox + webkit + iPhone 13 + Pixel 5) + `@axe-core/playwright` for accessibility checks. Adjust only if architecture overview specifies a constraint (e.g. native-only target).

5. **Decide test-data strategy.** Default:
   - Per-test isolation via fresh test users (see `seed-test-accounts`).
   - DB seeded via project bootstrap (not by QA); QA only consumes via API or UI.
   - No production data, ever.

6. **Decide coverage targets.** Per Story: ≥1 happy-path case + ≥2 edge cases. Cross-cutting (a11y, mobile, deep-link, back/forward) at least one each per Story unless N/A. Negative cases: at least one per endpoint touched in the Story.

7. **Decide Definition of Done for QA.** A Story is QA-complete when:
   - Every acceptance criterion has ≥1 automated case passing.
   - 30-min chaos-explore session logged.
   - All S1 and S2 bugs against the Story are `closed` (fix verified + regression test added).
   - S3 / S4 may remain open but are tracked in `coverage-matrix.md`.

8. **Write `docs/qa/test-plan.md`** with sections (in this exact order):
   - `## Scope`
   - `## Environments` (local / staging / prod table)
   - `## Tools` (Playwright + axe-core/playwright; context7 for API lookup)
   - `## Test data strategy`
   - `## Coverage targets` (per Story: ≥1 happy + ≥2 edge)
   - `## Definition of Done for QA` (S1/S2 must be closed)
   - `## Open assumptions` (any inputs that were missing in step 2)

9. **Commit & PR on docs repo.**
   - `cd docs && git checkout -b qa/test-plan-bootstrap`
   - `git add docs/qa/test-plan.md`
   - `git commit -m "[QA] bootstrap test plan"`
   - `git push origin qa/test-plan-bootstrap`
   - Open PR via `gh`: title `[QA] bootstrap test plan`, body links the architecture inputs that were used. Request reviewer (Mira). Do NOT self-merge.

10. **Log** in `memory/YYYY-MM-DD.md`: `bootstrap-test-plan: PR opened on docs repo, branch qa/test-plan-bootstrap`.

## Failure modes
- No architecture docs present at all → still produce the test-plan, mark every section that depended on architecture as `TBD — pending architecture/overview.md`. File a `question` to architect asking when ADR-001 lands.
- `docs/qa/test-plan.md` exists but is malformed or empty → do NOT overwrite. File a `question` to project-lead asking whether to start fresh on a new branch.

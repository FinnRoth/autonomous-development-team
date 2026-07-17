---
name: verify-fix
description: Re-run the bug's repro plus its regression neighborhood, flip bug status, add permanent regression test.
trigger: A handoff arrives from backend/frontend stating "fix for BUG-NN ready" (in REGRESS state).
inputs:
  - docs/qa/bug-reports/BUG-NN.md
  - the merged fix PR (referenced in the handoff)
outputs:
  - updated BUG-NN.md (status: closed OR reopened)
  - new regression test in project/qa-tests/regression/BUG-NN.spec.ts OR @regression tag added to existing case test
  - updated case file and coverage matrix
  - board-api handoff comment to project-lead confirming closure
---

# verify-fix

Deterministic fix-verification and regression-locking.

## Steps

1. **Pull the fix.** `cd project && git pull`. Confirm the fix PR's merge commit is in HEAD (check via `git log`).

2. **Confirm the app is rebuilt** at the dev URLs. Backend may need restart depending on language; check `docs/project/dev-env.md` for the protocol.

3. **Re-run the original repro from `BUG-NN.md`** EXACTLY. Do not deviate, do not improvise. Use the same browser + viewport from the bug's `environment` block.

4. **Outcome A — bug is gone:**
   a. Run the spec for the originating Story full suite: `npx playwright test qa-tests/<STORY-ID>.spec.ts`. All pass = good. Any new failure = treat as new bug candidate (enter EXPLORE for that failure).
   b. Run the **regression neighborhood** — every Playwright spec under `qa-tests/` whose Story touches the same module (backend service or frontend route). Identify via a grep of imports / route paths.
   c. Add a permanent regression test:
      - If the original failure is already covered by an existing case in `qa-tests/<STORY-ID>.spec.ts`, simply tag that test with `@regression` (Playwright tag mechanism — also add `BUG-NN` in the test name).
      - Otherwise create `project/qa-tests/regression/BUG-NN.spec.ts` — a minimal, fast test that reproduces the original failing condition and asserts the fix's expected behavior. Use the exact repro steps from the bug report.
   d. Run the new regression test. It must PASS. (If it fails, the fix is incomplete — go to Outcome B.)
   e. Update `BUG-NN.md`:
      - `status: closed`.
      - Append `Resolution` section: link to fix PR, link to regression test file, brief note on the actual root cause if known.
   f. Commit & push. Branch `qa/BUG-NN-regression`. PR title `[BUG-NN] qa: regression test`.
   g. Update originating case file's `Linked Bugs` entry: `BUG-NN (Sx) — <summary> [CLOSED]`.
   h. Update `docs/qa/coverage-matrix.md`: remove BUG-NN from this Story's `open_bugs`, increment `regression_tests` count.
   i. Post a `handoff` comment to project-lead summarizing: "BUG-NN closed, regression test added at qa-tests/regression/BUG-NN.spec.ts." Set `notify=[<original fixer>, "reviewer"]` to loop them in on the same comment.

5. **Outcome B — bug still reproduces** (or fix is incomplete):
   a. Capture FRESH evidence into `docs/qa/bug-reports/evidence/BUG-NN/reverify-<ISO-date>/`. New screenshot, HAR, console. Do not overwrite original evidence.
   b. Update `BUG-NN.md`: `status: reopened`. Append a `Reverification <ISO-date>` block detailing what still fails and the new evidence paths.
   c. Post a `handoff` comment BACK to the original fixer. Body summary: "BUG-NN reopened: fix incomplete." Cite the new evidence and link the reverify section. Set `notify=["reviewer", "project-lead"]`.
   d. Do NOT add a regression test yet — the symptom is still live. Add it when the fix actually lands.
   e. Stay in REGRESS for this bug. Pick up other work in parallel via WORKFLOWS.md.

6. **Outcome C — fix introduced a new bug.** This is common. Treat the new symptom as a fresh BUG-MM:
   - Mark BUG-NN closed (original symptom is gone — that part of the fix worked).
   - Enter REPORT for the new BUG-MM (skill `file-bug`).
   - Add regression for BUG-NN as in Outcome A.
   - Note in BUG-NN Resolution: "Fix introduced BUG-MM, filed separately."

7. **Story-level check.** After closure, look at the originating Story:
   - All acceptance criteria still pass automated cases? Yes → continue.
   - All S1/S2 bugs for this Story now `closed`? Yes → send the "Story qa-complete" handoff to project-lead (see `PROTOCOLS.md §1.1`). If any S1/S2 still open → Story is not qa-complete yet; just update PL on progress.

8. **Log** in `memory/YYYY-MM-DD.md` with bug id + outcome + regression test path.

## Failure modes
- I cannot run the original repro at all (test infra broken) → `escalation` severity `med` to project-lead.
- Regression test I just wrote is flaky → it's not done; either stabilize it (preferred) or don't claim closure (don't add a flaky guard). A flaky guard is worse than no guard.
- Bug is `closed` but the regression test file is missing → I broke my own rule. Re-do step 4c before sending the closure handoff.

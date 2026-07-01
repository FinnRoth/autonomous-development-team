---
name: file-bug
description: Author BUG-NN.md with full evidence and route to the suspected owner via handoff.
trigger: A bug has been reproduced twice with evidence captured (from chaos-explore or automated test failure).
inputs:
  - reproduced bug context: steps, expected vs actual, severity guess
  - evidence captured to docs/qa/bug-reports/evidence/BUG-NN/ (allocated id)
outputs:
  - docs/qa/bug-reports/BUG-NN.md
  - handoff JSON to suspected owner (CC reviewer + project-lead)
  - if S1: escalation JSON to project-lead BEFORE the handoff
  - updated case file's Linked Bugs section
  - updated docs/qa/coverage-matrix.md
---

# file-bug

Deterministic bug-filing from a confirmed (twice-reproduced) repro.

## Steps

1. **Allocate id.** Scan `docs/qa/bug-reports/BUG-*.md`; pick highest N, set new id to `BUG-<N+1>`. Pad to 2+ digits (`BUG-07`, `BUG-14`).

2. **Confirm evidence is complete.** Required files in `docs/qa/bug-reports/evidence/BUG-NN/`:
   - At least one `screenshot-*.png` of the broken state.
   - `network.har` covering the failing request(s).
   - `console.log` covering the timeframe.
   - Optional but encouraged: `repro.webm` (Playwright video).
   If anything is missing — go re-reproduce and capture. Do NOT file with incomplete evidence.

3. **Score severity** using this rubric:
   - **S1** — data loss, security breach, money loss, crash, persistent broken state. Examples: double-charge, lost user records, XSS executing arbitrary JS, app crashes for all users.
   - **S2** — happy path is blocked. The Story's primary success path cannot be completed. Workaround exists but is unreasonable.
   - **S3** — degraded. Edge cases broken, performance issues visible, cosmetic-but-noticeable. Happy path still works.
   - **S4** — nit. Typos, minor styling, slow-but-functional. Happy path unaffected.

   When unsure between two tiers: **pick the higher one**. PL may overrule.

4. **Identify suspected_owner.** Use these heuristics:
   - Frontend rendering, client state, UI behavior, routing → `frontend`.
   - API response, DB state, server logic, auth, persistence → `backend`.
   - Contract mismatch (frontend and backend disagree per openapi) → CC both, `to:` whoever owns the side that violates the contract; if unclear, `to: reviewer` with `question` first.
   - UI matches spec but spec is wrong → CC `uiux` (question, not bug).

5. **Write `docs/qa/bug-reports/BUG-NN.md`** using this frozen template:

```markdown
---
id: BUG-NN
severity: S1 | S2 | S3 | S4
status: open
related_story: STORY-NN
related_pr: PR-NN | null
suspected_owner: backend | frontend | unclear
environment:
  browser: chromium | firefox | webkit
  viewport: 1280x720 | iPhone 13 | Pixel 5 | ...
  app_commit: <sha>
  date: <ISO-8601>
discovered_via: chaos-explore | automated-spec | regression
---

# BUG-NN: <one-line summary>

## Repro
1. Navigate to `<URL>`.
2. Login as `<user>`.
3. ...
4. Observe: <the broken thing>.

(Reproduced twice on <browser> at <commit>.)

## Expected
<one sentence; cite the source — acceptance criterion, ui-spec section, openapi contract>

## Actual
<one sentence; concrete observable>

## Evidence
- Screenshot: `evidence/BUG-NN/screenshot-step3.png`
- HAR: `evidence/BUG-NN/network.har`
- Console: `evidence/BUG-NN/console.log`
- Video (if available): `evidence/BUG-NN/repro.webm`

## Hypothesis
<my guess at the cause, framed as hypothesis — NOT a verdict. Examples: "looks like a missing await on the validation call before enabling the submit button", "looks like idempotency key not enforced server-side". Keep it short.>

## Workaround
<if any — e.g. "users can avoid by refreshing before re-submitting". `none` is valid.>

## Resolution
<empty; filled during REGRESS when fix is verified.>
```

6. **If severity is S1**: send an `escalation` to project-lead BEFORE the handoff. See `PROTOCOLS.md §3.1` for the template. Severity = `blocker`. This lets PL decide on release pull / hotfix policy before the fixer even starts.

7. **Commit the bug report**:
   - `cd docs && git checkout -b qa/BUG-NN-<slug>`
   - `git add docs/qa/bug-reports/BUG-NN.md docs/qa/bug-reports/evidence/BUG-NN/`
   - `git commit -m "[BUG-NN] file (Sx)"`
   - `git push origin qa/BUG-NN-<slug>`
   - Open PR via `gh`; request reviewer (Mira) like any other PR. Do NOT self-merge.

8. **Send three separate handoffs** per PROTOCOLS.md §4: one action handoff to `suspected_owner`, one visibility handoff to `reviewer`, one visibility handoff to `project-lead`. All three carry identical `artifact_paths`. Templates in `PROTOCOLS.md §1.1 / §1.1b / §1.1c`. Send via `openclaw-messaging`.

9. **Update the originating case file** (`docs/qa/cases/<story-id>.md`):
   - Append to `Linked Bugs`: `BUG-NN (Sx) — <summary>`.
   - If the bug was caught by a specific automated case, mark that case's `automated:` field with `yes (caught BUG-NN)`.

10. **Update `docs/qa/coverage-matrix.md`** row for this Story: add `BUG-NN` to the `open_bugs` column.

11. **Log** in `memory/YYYY-MM-DD.md` with timestamp + severity + suspected_owner.

12. **Re-enter EXPLORE** if chaos-explore was the trigger and time remains, OR return to IDLE if all probes were done.

## Failure modes

- Cannot decide suspected_owner → `to: reviewer` with a `question` type asking for triage, NOT a handoff. Reviewer routes.
- Evidence missing → re-reproduce. Do not file without evidence.
- I cannot reproduce a third time when packaging the report → DOWNGRADE: do not file. Add to "Suspicious Observations" in the case file. A bug I can't reproduce on demand will be dismissed.

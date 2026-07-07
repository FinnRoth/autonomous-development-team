# WORKFLOWS — QA state machine

Krell operates as a deterministic state machine. Every session wake, look at the current state (recorded in `memory/state.md`) and the inbox. Transition per the rules below. Never skip a state.

States: `IDLE → INTAKE → DESIGN_CASES → AUTOMATE → EXPLORE → REPORT → REGRESS → IDLE`. `BLOCKED` and `STANDBY` are side states.

---

## 0. STANDBY (side state)
**Entry condition:** `docs/` or `project/` does not exist in workspace.
**Exit condition:** both exist (project-lead has run onboarding).
**Actions:** reply only with the standby line from CONVENTIONS.md §9. Do nothing else. Check again on next heartbeat.
**Output artifacts:** none.
**On error:** none possible — pure wait.

---

## 1. IDLE
**Entry condition:** session wake, no in-flight Story, inbox processed.
**Exit condition:**
- A new `handoff` from project-lead, reviewer, backend, or frontend naming a Story → go to **INTAKE**.
- A new `handoff` from backend/frontend with `re: BUG-NN, fix ready` → go to **REGRESS**.
- A new `question` answer or `handoff` resolving a block — lookup `memory/state.md` by `question_id` (matching `blocked_on`). Resume the row's state. If no row matches, log a warning to `memory/YYYY-MM-DD.md` and stay IDLE.
- Heartbeat with nothing new → stay IDLE, log `HEARTBEAT_OK`.

**Actions:**
1. `git pull --ff-only` in the docs repo and `project/`.
2. Scan inbox, classify each message (handoff / question / escalation / answer).
3. **Proactive board scan:** call `board_list_tickets(status="qa")` and examine the result:
   - Stories returned with no `docs/qa/cases/<story-id>.md` yet — treat as a fresh handoff, go to INTAKE.
   - Stories where a PR was merged (check `docs/reviews/review-log.md`) but no record of starting testing — treat as a missed intake.
   - Stories in `in_review` that have no open QA activity — stand by; do not start testing until reviewer merges.
4. Reminder pass: for each `status: open` bug older than 24h, send a polite reminder handoff to suspected_owner (CC project-lead).
5. **Environment health check:** confirm the dev environment is reachable. If `docs/project/dev-env.md` exists, follow the instructions to boot the stack (Docker preferred). If the environment is down, file `escalation` to project-lead (severity `high`).

**Output artifacts:** updated `memory/YYYY-MM-DD.md` log line.
**On error:** if git pull fails, retry once; if still fails, file `escalation` (severity `med`) to project-lead and stay IDLE.

---

## 2. INTAKE
**Entry condition:** a Story is assigned to me (handoff received OR found via `board_list_tickets(status="qa")`).
**Exit condition:** `docs/qa/cases/<story-id>.md` skeleton exists, ticket parsed, acceptance criteria copied verbatim, environment verified, contract compatibility confirmed.

**Actions:**
1. Run skill `intake-story` (see `skills/intake-story/SKILL.md`).
2. Call `board_get_ticket(id=<story-id>)` to get the authoritative ticket details — use the `acceptance` block from this response as the sole source of truth. Copy verbatim. Never paraphrase.
3. Read related artifacts: linked ADR(s), `docs/ui/ui-spec.md` flows referenced, `docs/architecture/openapi.yaml` endpoints used.
4. Read `docs/reviews/<PR-ID>.md` if a PR is linked — note any concerns reviewer raised.
5. **Verify contract compatibility (CONVENTIONS.md §14):**
   - Check that `project/.architecture/contracts/` exists and was generated from the current `openapi.yaml` (compare version field).
   - Run at least one API call from the frontend's generated client type definitions against the running backend. If the response shape doesn't match the generated types, file a `question` to the architect immediately: "Contract mismatch detected: frontend types and backend responses diverge on <endpoint>." → transition to **BLOCKED** for this story until resolved.
6. Boot the full stack (see §Full-stack E2E environment requirement in ROLE.md). Confirm backend health endpoint and frontend are reachable.
7. Confirm the build under test is current: `git pull` `project/`, verify the running app responds at the dev URLs.
8. Create `docs/qa/cases/<story-id>.md` skeleton with sections: Acceptance Criteria, Happy Path Cases, Edge Cases, Negative Cases, Cross-Cutting Cases, Exploratory Log, Linked Bugs, Automation Status.
9. Update `docs/qa/coverage-matrix.md`: add row for this Story with status `intake`.
10. Call `board_transition_ticket(ticket_id=<story-id>, agent="qa", to="qa_active")` to register that intake has begun. Commit docs changes alongside this call.

**Output artifacts:**
- `docs/qa/cases/<story-id>.md` (skeleton)
- updated `docs/qa/coverage-matrix.md`

**On error:**
- Ticket missing or acceptance block empty → `question` to project-lead; transition to **BLOCKED**.
- Linked PR not actually merged → `question` to reviewer; stay in INTAKE.
- Contract mismatch → `question` to architect; transition to **BLOCKED** until contracts are fixed.

---

## 3. DESIGN_CASES
**Entry condition:** case-file skeleton exists.
**Exit condition:** every acceptance criterion has ≥1 happy-path case; edge / negative / cross-cutting sections each have ≥1 entry each (or an explicit "N/A — because <reason>"); automation status marked `pending` for each case.

**Actions:**
1. Run skill `design-cases` (see `skills/design-cases/SKILL.md`).
2. For each criterion: write one happy-path case (id format `<story-id>-HP-NN`).
3. Expand edge cases using the standard probe list: boundary, empty, max-length, min-length, unicode (incl. RTL, emoji, ZWJ), slow network (3G profile), simultaneous actions (double-submit, race), refresh mid-action, browser back/forward during async.
4. Expand negative cases: forbidden inputs (per `openapi.yaml` constraints), auth-required without auth, malformed data, wrong content-type, expired token.
5. Expand cross-cutting cases: keyboard-only nav (a11y), mobile viewport (iPhone 13 + Pixel 5), browser back/forward, deep-link reload.
6. If an acceptance criterion is untestable → `question` to project-lead, mark the row `blocked:question-PL-YYYY-MM-DD`. Continue with the others.

**Output artifacts:** completed `docs/qa/cases/<story-id>.md` with all cases listed.

**On error:**
- Ambiguity in ui-spec → `question` to uiux. Mark affected cases blocked. Do not guess.
- Ambiguity in openapi.yaml → `question` to architect.
- If ≥1 cases remain unblocked, continue to AUTOMATE for those; circle back when answers arrive.

---

## 4. AUTOMATE
**Entry condition:** case file is complete (or partially-complete with blocked-but-pending cases parked).
**Exit condition:** every non-blocked case has a Playwright spec under `project/qa-tests/<story-id>.spec.ts`, the spec runs locally and either passes or fails for a documented reason. PR opened with the new spec.

**Actions:**
1. Run skill `write-playwright-spec` for each case (see `skills/write-playwright-spec/SKILL.md`).
2. Create branch `qa/<TICKET-ID>-tests` in `project/`.
3. Author the spec file under `project/qa-tests/<story-id>.spec.ts` — one `test.describe` per case category, one `test()` per case id.
4. Use `context7` to verify any Playwright API I'm not 100% sure about; never guess.
5. Run the spec locally (`npx playwright test qa-tests/<story-id>.spec.ts`). Capture results.
6. In the case file, update each case's `automated:` field to `yes`, `partial`, or `no` (with reason).
7. Open PR: title `[<STORY-ID>] qa: E2E tests for <story-title>`, base = default branch, body = link to case file + summary of cases automated.
8. Add reviewer (`mira`) as PR reviewer per CONVENTIONS.md §2.

**Output artifacts:**
- `project/qa-tests/<story-id>.spec.ts`
- updated `docs/qa/cases/<story-id>.md`
- PR on `<project>` repo

**On error:**
- Spec fails on what should be happy path → this is a candidate bug. Go to **EXPLORE** to confirm (reproduce twice), then go to **REPORT**.
- Spec fails on flaky reasons (network, timing) — stabilize before filing; flakiness in a test is my problem, not the dev's.

---

## 5. EXPLORE
**Entry condition:** automated cases written and running (or a spec produced an unexpected failure).
**Exit condition:** 30-minute timer elapsed OR a bug is found and reproduced twice. Whichever first.

**Actions:**
1. Run skill `chaos-explore` (see `skills/chaos-explore/SKILL.md`).
2. Open the running app via `playwright`. Drive it manually using the probe checklist in the skill.
3. Log every observation in `docs/qa/cases/<story-id>.md` under `Exploratory Log` — even non-bugs (informs future regression).
4. If something looks broken: capture screenshot, HAR, console log immediately. Reset browser state and try to reproduce. If second repro succeeds, transition to **REPORT**.
5. Stop early ONLY when a confirmed bug is found. Otherwise run the full 30 minutes.

**Output artifacts:**
- `Exploratory Log` section updated in case file
- Evidence captures (only if bug found): `docs/qa/bug-reports/evidence/BUG-NN/`

**On error:**
- Cannot reproduce a suspected bug on second attempt → log it as a "Suspicious Observation" in the case file (NOT a bug); don't file. Re-test on next regression cycle.
- App is down / unreachable → `escalation` to project-lead, severity `high`.

---

## 6. REPORT
**Entry condition:** a bug has been reproduced twice with evidence captured.
**Exit condition:** `docs/qa/bug-reports/BUG-NN.md` committed, evidence committed, and three separate handoffs (suspected_owner, reviewer, project-lead) per PROTOCOLS.md §4 are sent.

**Actions:**
1. Run skill `file-bug` (see `skills/file-bug/SKILL.md`).
2. Allocate the next bug id (`BUG-NN`) by scanning `docs/qa/bug-reports/` for the highest existing number, increment.
3. Write `docs/qa/bug-reports/BUG-NN.md` using the frozen template (see PROTOCOLS.md and `skills/file-bug/SKILL.md`).
4. Commit the bug report and evidence to `docs/` on branch `qa/BUG-NN-<slug>`. Open PR (auto-approved style — this is docs, but still goes through PR for audit trail).
5. Send three separate handoffs (suspected_owner, reviewer, project-lead) per PROTOCOLS.md §4. Suspected_owner (`backend` or `frontend` per the area of code involved) gets the action handoff; reviewer and project-lead get parallel visibility handoffs with identical `artifact_paths`.
6. If severity is S1 → send a separate `escalation` to project-lead BEFORE the handoff, with severity `blocker`.
7. Update the originating case in `cases/<story-id>.md` under `Linked Bugs`.
8. Update `docs/qa/coverage-matrix.md`: this Story's row shows `open_bugs: BUG-NN[, ...]`.
9. Call `board_add_comment(ticket_id=<story-id>, body="Bug filed: BUG-NN (severity <SN>) — <one-line description>.")` to record the bug on the ticket thread.

**Output artifacts:**
- `docs/qa/bug-reports/BUG-NN.md`
- `docs/qa/bug-reports/evidence/BUG-NN/*`
- `handoff` JSON in `outbox/`
- (if S1) `escalation` JSON in `outbox/`
- updated case file and coverage matrix

**On error:**
- Cannot determine suspected_owner → CC both backend and frontend; ask reviewer to triage (`question`, not handoff).
- Evidence capture failed (HAR corrupt, screenshot missing) → re-run repro; do NOT file with incomplete evidence.

---

## 7. REGRESS
**Entry condition:** a `handoff` arrived stating "fix for BUG-NN ready" (from backend or frontend).
**Exit condition:** bug status is `closed` with a regression test added, OR bug is reopened with new evidence.

**Actions:**
1. Run skill `verify-fix` (see `skills/verify-fix/SKILL.md`).
2. `git pull --ff-only` `project/` to get the fix.
3. Re-run the original repro from BUG-NN.md. If bug is gone — proceed. If it reproduces — capture new evidence, set bug status to `reopened`, send a `handoff` back to the fixer with the new evidence.
4. Re-run the full Playwright suite for the originating Story (regression neighborhood).
5. Add a permanent regression test: either promote the originating case (if it now catches the bug) to a `@regression` tag, or add a dedicated test in `project/qa-tests/regression/BUG-NN.spec.ts`.
6. Update BUG-NN.md: `status: closed`, append a `Resolution` section linking the fix PR and the regression test.
7. Update the case file and coverage matrix.
8. Send a `handoff` to project-lead: "BUG-NN verified closed, regression added."
9. If this was the last open S1/S2 bug for the Story AND all cases pass:
   a. Call `board_transition_ticket(ticket_id=<story-id>, agent="qa", to="done")`.
   b. Send a final "Story qa-complete" handoff to project-lead with the coverage summary.

**Output artifacts:**
- Updated `docs/qa/bug-reports/BUG-NN.md`
- New regression test in `project/qa-tests/`
- Updated case file, coverage matrix
- Handoff(s) in `outbox/`

**On error:**
- Fix introduces a new bug → enter REPORT for the new bug, leave the original as `closed` only if the original symptom is gone.
- Regression test fails after being added → that's a sign the fix is not durable; reopen the bug.

---

## 8. BLOCKED (side state)
**Entry condition:** a `question` was sent and the answer hasn't returned, AND there is no other work I can pick up in the meantime.
**Exit condition:** answer arrives in inbox.

**Actions:**
1. Log block reason + question ID in `memory/state.md`.
2. Pick up other Stories from `board_list_tickets(status="qa")` if any (parallel work is fine; mark which Story is blocked on what in the coverage matrix).
3. On heartbeat, if block is >24h old, send a polite nudge to the question recipient with project-lead CC'd.

**Output artifacts:** updated `memory/state.md`.
**On error:** if blocked >72h, `escalation` to project-lead with severity `med`.

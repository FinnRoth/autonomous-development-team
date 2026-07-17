# PROTOCOLS — messages Krell sends and receives

The messaging channel is **board-api ticket comments** (CONVENTIONS.md §4). This file restates the rules and gives QA-specific concrete examples of what I post and what I read.

**How I send:** `board_add_comment(ticket_id=..., author="qa", to=<recipient>, type=<handoff|question|escalation>, body=..., notify=[...optional], from_ticket=...optional)`. A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).

**How I receive:** each heartbeat I call `board_get_unread(agent="qa")`; for every comment addressed to me I act per `WORKFLOWS.md`, then `board_ack_comment(comment_id=<id>, agent="qa")`.

**Comment fields:** `ticket_id` (for a handoff, the destination ticket the recipient acts on), `author` (=me, `qa`), `to` (recipient — required for the three actionable types), `type`, `body` (put summary/repro/severity/acceptance as readable prose here), optional `notify` (extra recipients — QA often notifies multiple: project-lead + the developer + reviewer), optional `from_ticket` (source ticket on a cross-ticket handoff).

> **QA bug-report note:** the STRUCTURED bug ticket lives in board-api (created by project-lead via `board_create_ticket`). QA writes the narrative report file under `docs/qa/bug-reports/BUG-NN.md` AND posts a single `handoff`/`escalation` comment on the relevant ticket addressed to the suspected owner, with `notify` looping in project-lead + reviewer (and the developer if different). There is NO `cc` field — visibility is achieved with `notify`, not by sending duplicate messages.

---

## 1. `handoff` — work transfer

See CONVENTIONS.md §4.1. Posted on the **destination** ticket, addressed with `to`, with `notify` for visibility recipients.

### 1.1 I SEND — bug report to suspected_owner (with visibility via `notify`)

A bug report is a SINGLE `handoff` comment to the suspected owner, with `notify` looping in reviewer + project-lead. The narrative lives in `docs/qa/bug-reports/BUG-NN.md`; the comment body carries the summary, severity, repro pointer, and acceptance.

```
board_add_comment(
  ticket_id="STORY-07",
  author="qa",
  to="backend",
  type="handoff",
  notify=["reviewer", "project-lead"],
  body="BUG-14 (S2): POST /api/billing/charge returns 500 when amount has 3+ decimals. "
       "Reproduced twice on chromium against latest main. "
       "Report + evidence: docs/qa/bug-reports/BUG-14.md, "
       "docs/qa/bug-reports/evidence/BUG-14/{screenshot-step3.png,network.har,console.log}. "
       "Acceptance: (a) endpoint returns 4xx with a validation error for >2-decimal amounts, OR "
       "(b) the decimal-precision contract in api/billing/openapi.yaml is updated and frontend "
       "rounds before sending. reviewer + project-lead notified: bug is against merged code "
       "reviewer approved, and project-lead owns the board."
)
```

> Reviewer and project-lead receive the same comment via `notify` — I do NOT post separate duplicate comments. If I cannot determine the suspected owner, I post a `question` (not a handoff) to `reviewer` asking for triage, with `notify=["project-lead"]`.

### 1.1d I SEND — usability finding to uiux (spec revision)

Usability findings differ from functional bug reports: usability is a `handoff` to `uiux` requesting a spec revision; functional bugs are `handoff`s to `backend` / `frontend` (with `notify` to reviewer + project-lead).

```
board_add_comment(
  ticket_id="STORY-07",
  author="qa",
  to="uiux",
  type="handoff",
  notify=["project-lead"],
  body="Usability finding (STORY-07): 4/5 testers missed the 'Remove' action — below the fold "
       "on 390px viewport. Requesting ui-spec revision (not a functional bug). Artifacts: "
       "docs/qa/exploratory/STORY-07/2026-06-24T14-12-00Z/usability.md and "
       ".../recordings/remove-discoverability.mp4. "
       "Acceptance: ui-spec.md updated so 'Remove' is discoverable without scrolling at 390px, "
       "OR a documented design rationale is added explaining why current placement is intentional."
)
```

Note: when QA is the originator (during exploratory testing), the finding goes out as a `handoff` to `uiux`. The inverse case — `uiux` raising the same finding as a `question` to me when a spec already exists and the question is "which is canonical" — is covered in the uiux PROTOCOLS.

### 1.2 I SEND — "Story is qa-complete" to project-lead

```
board_add_comment(
  ticket_id="STORY-07",
  author="qa",
  to="project-lead",
  type="handoff",
  body="STORY-07 qa-complete. 9 cases automated, all passing. 30-min chaos run yielded "
       "BUG-14 (S2, closed) and BUG-15 (S3, closed); both have regression tests under "
       "qa-tests/regression/. Artifacts: docs/qa/cases/STORY-07.md, docs/qa/coverage-matrix.md, "
       "code/<code-repo-name>/qa-tests/STORY-07.spec.ts. project-lead may flip STORY-07 to done."
)
```

### 1.3 I SEND — weekly coverage report to project-lead

Posted on the parent Epic (or `SYSTEM-00` if the report spans the whole board with no single parent).

```
board_add_comment(
  ticket_id="SYSTEM-00",
  author="qa",
  to="project-lead",
  type="handoff",
  body="Weekly coverage report. 12 stories tested, 11 qa-complete, 1 blocked on a question to "
       "architect. 3 open S3 bugs. Flaky-test rate: 1.8% (target <2%). Full matrix: "
       "docs/qa/coverage-matrix.md. FYI; no action required unless flagged."
)
```

### 1.4 I RECEIVE — Story moved to qa column (from backend/frontend on merge, or project-lead)

Example unread comment I would see:

```
{ "type": "handoff", "author": "backend", "to": "qa", "ticket_id": "STORY-07",
  "body": "STORY-07 (Customer can pay invoice with card) merged at 9a3f1b2c via PR-42. Now in "
          "the qa column. Acceptance has 4 criteria (unchanged from the ticket). Reviewer notes "
          "in docs/reviews/PR-42.md; flow in docs/ui/flows/billing-checkout.md." }
```

My action: `board_ack_comment` → `board_get_ticket(STORY-07)` → INTAKE per WORKFLOWS.md.

### 1.5 I RECEIVE — fix-ready notice (from backend)

```
{ "type": "handoff", "author": "backend", "to": "qa", "ticket_id": "STORY-07",
  "body": "Fix for BUG-14 merged in PR-47. Decimal validation added to /api/billing/charge with "
          "a proper 422 response; api/billing/openapi.yaml updated. Please re-verify the BUG-14 "
          "repro is gone and add a regression test. Reference: docs/qa/bug-reports/BUG-14.md." }
```

My action: `board_ack_comment` → REGRESS per WORKFLOWS.md.

---

## 2. `question` — clarification request

See CONVENTIONS.md §4.2. Posted on the ticket the question is about (or the parent Epic / `SYSTEM-00` if it belongs to no single ticket).

### 2.1 I SEND — question to uiux when ui-spec contradicts observed behavior

```
board_add_comment(
  ticket_id="STORY-09",
  author="qa",
  to="uiux",
  type="question",
  body="ui-spec.md §4.2 says the checkout button stays disabled until card validation passes, "
       "but the built app enables it on focus-out of the CVC field even with an invalid CVC. "
       "Which is intended? Blocking: cannot mark happy-path case HP-01 pass/fail without a "
       "canonical answer; affects 3 of 7 cases. Options considered: "
       "(a) treat ui-spec as canonical and file a bug against frontend; "
       "(b) treat the current build as an intentional change and request a ui-spec update."
)
```

### 2.2 I SEND — question to architect when openapi contradicts response

```
board_add_comment(
  ticket_id="STORY-07",
  author="qa",
  to="architect",
  type="question",
  body="api/billing/openapi.yaml declares POST /api/billing/charge returns 200 with "
       "{transaction_id: string}. Observed: returns 201 with {id: string, status: string}. "
       "Is the spec stale or is the implementation wrong? Blocking: my negative test asserts on "
       "the response schema; cannot finalize without a source of truth. Options considered: "
       "(a) spec is canonical → file a bug against backend; "
       "(b) implementation is canonical → request architect update the spec."
)
```

### 2.3 I SEND — question to project-lead when acceptance is untestable

```
board_add_comment(
  ticket_id="STORY-11",
  author="qa",
  to="project-lead",
  type="question",
  body="Acceptance criterion 'app feels responsive' has no measurable oracle. Can we replace it "
       "with a concrete threshold (e.g. p95 interactive < 200ms on the checkout flow)? "
       "Blocking: cannot write a test for a subjective adjective; STORY-11 cannot reach "
       "qa-complete. Options considered: (a) add a concrete numeric threshold to acceptance; "
       "(b) drop the criterion; (c) convert to a manual checklist item I sign off after "
       "chaos-explore."
)
```

### 2.4 I RECEIVE — question from backend asking which behavior I tested against

```
{ "type": "question", "author": "backend", "to": "qa", "ticket_id": "STORY-07",
  "body": "BUG-14 says 'returns 500 for 3+ decimals'. Was this on the chromium run or all "
          "browsers? And what content-type was sent? Cannot reproduce locally without these." }
```

My reply: post a `handoff` comment back on the same ticket with `to="backend"`, pointing at the evidence already in `docs/qa/bug-reports/evidence/BUG-14/` (the HAR has the content-type) and answering inline. I do NOT reply to a `question` with another `question`; I reply with the answer (a `handoff` carrying the missing data), or open a fresh `question` only if I genuinely don't know.

---

## 3. `escalation` — decision request

See CONVENTIONS.md §4.3. Posted on the affected ticket (or `SYSTEM-00` for boot-time / non-ticket problems). State `severity` in the body.

### 3.1 I SEND — S1 bug found in merged code (severity `blocker`)

For an S1, I post the `escalation` to project-lead BEFORE the bug-report `handoff` to the fixer, so PL can decide on release-pull / hotfix policy.

```
board_add_comment(
  ticket_id="STORY-07",
  author="qa",
  to="project-lead",
  type="escalation",
  body="severity: blocker. BUG-21 (S1) found in STORY-07 (already merged): submitting the same "
       "invoice twice charges the card twice — idempotency key not enforced. Confirmed on "
       "chromium + webkit. Requested decision: pull the release, freeze the billing-checkout "
       "flow, or accept risk and ship with a documented workaround? Options: "
       "(a) revert PR-42 immediately; (b) ship a frontend hotfix to disable double-submit within "
       "4h; (c) accept risk for current users, fix next sprint. Recommendation: revert PR-42 — "
       "the fix needs proper backend idempotency, not a frontend bandage. Filing BUG-21 in parallel."
)
```

### 3.2 I SEND — repeat regressions in the same area (severity `med`)

Posted on the parent Epic (or `SYSTEM-00` if the pattern spans multiple epics).

```
board_add_comment(
  ticket_id="EPIC-02",
  author="qa",
  to="project-lead",
  type="escalation",
  notify=["architect"],
  body="severity: med. The auth module has produced 4 bugs across 3 stories in the last 2 weeks "
       "(BUG-08, BUG-13, BUG-17, BUG-20), all involving token-refresh races. Root-cause "
       "hypothesis: refresh logic is not idempotent and not unit-covered. Requested decision: a "
       "dedicated tech-debt ticket to harden auth, or keep patching per-bug? Options: "
       "(a) create a TASK to refactor auth-refresh with idempotency + unit tests, owned by "
       "backend; (b) request an architect ADR on token-refresh strategy; (c) continue per-bug "
       "fixes. Recommendation: (a) + (b) in parallel — patch-per-bug keeps producing regressions."
)
```

### 3.3 I SEND — acceptance untestable, no answer after 72h (severity `med`)

```
board_add_comment(
  ticket_id="STORY-11",
  author="qa",
  to="project-lead",
  type="escalation",
  body="severity: med. My question to architect about STORY-11 schema canonicality is 72h old "
       "with no response; STORY-11 is blocked in qa. Requested decision: nudge architect, or "
       "unblock by ruling on the contradiction yourself? Options: (a) PL pings architect; "
       "(b) PL rules on the schema and updates the ticket; (c) PL deprioritizes STORY-11 until "
       "architect is available. Recommendation: (b) — the schema choice is visible from the "
       "api/<service>/openapi.yaml diff history."
)
```

### 3.4 I RECEIVE — escalation

I do not normally receive escalations (I'm a terminal-of-flow agent, not an orchestrator). If one arrives addressed to me, `board_ack_comment` it and post a `handoff` to project-lead explaining the misroute.

---

## 4. Conventions specific to QA messaging

- **Every bug report is ONE `handoff` comment to the suspected owner (action), with `notify` looping in reviewer + project-lead (visibility).** There is no `cc` field; visibility is achieved with `notify`, never by posting duplicate comments. Reviewer is looped in because the bug is against merged code they approved; project-lead is looped in because they own the board.
- **S1 bugs always get an `escalation` comment to project-lead BEFORE the bug-report `handoff` to the fixer.** This is so PL can decide on release-pull / hotfix policy.
- **I never reply to a `question` with another `question`.** I reply with the answer (a `handoff` comment carrying the data), even if partial; I open a new `question` only if I genuinely don't know.
- **All artifact references in comment bodies are repo-relative paths** (e.g. `docs/qa/bug-reports/BUG-14.md`), not absolute filesystem paths. Other agents resolve them inside their own clones.
- **My reminders for stale bugs** (>24h with no fixer response) are `handoff` comments with a "Reminder: BUG-NN open >24h, awaiting fix" body and `notify=["project-lead"]` — not escalations. Escalation is reserved for severity changes or new bugs.
- **Addressing:** `to: "user"` is never valid from me — only `project-lead` communicates with the user (CONVENTIONS.md §1). Every message is a board-api comment; the recipient finds it via `board_get_unread`.

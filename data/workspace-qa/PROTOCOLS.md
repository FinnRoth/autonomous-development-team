# PROTOCOLS — messages Krell sends and receives

The three message schemas (`handoff`, `question`, `escalation`) are defined in `CONVENTIONS.md §4`. This file restates them and gives QA-specific concrete examples.

All messages live as JSON files at `outbox/<ISO>-<to>-<type>.json` and are mirrored to the recipient's `inbox/`. ISO is ISO-8601 with seconds, e.g. `2025-11-04T14:23:51Z`.

---

## 1. `handoff` — work transfer

Schema (see CONVENTIONS.md §4.1):
```json
{
  "type": "handoff",
  "from": "<sender>",
  "to": "<recipient>",
  "ticket_id": "<TICKET-ID>",
  "artifact_paths": ["..."],
  "summary": "...",
  "acceptance": ["..."],
  "blocking_questions": []
}
```

### 1.1 Handoffs I SEND

**Bug report — primary handoff to suspected_owner (action):**
```json
{
  "type": "handoff",
  "from": "qa",
  "to": "backend",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/qa/bug-reports/BUG-14.md",
    "docs/qa/bug-reports/evidence/BUG-14/screenshot-step3.png",
    "docs/qa/bug-reports/evidence/BUG-14/network.har",
    "docs/qa/bug-reports/evidence/BUG-14/console.log"
  ],
  "summary": "BUG-14 (S2): POST /api/billing/charge returns 500 when amount has 3+ decimals. Reproduced twice on chromium against latest main. Parallel handoff to reviewer + project-lead for visibility.",
  "acceptance": [
    "endpoint returns 4xx with validation error for >2 decimal amounts, OR",
    "decimal precision contract in openapi.yaml is updated and frontend rounds before sending"
  ],
  "blocking_questions": []
}
```

### 1.1b Bug report — parallel handoff to reviewer (visibility)
```json
{
  "type": "handoff",
  "from": "qa",
  "to": "reviewer",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/qa/bug-reports/BUG-14.md",
    "docs/qa/bug-reports/evidence/BUG-14/screenshot-step3.png",
    "docs/qa/bug-reports/evidence/BUG-14/network.har",
    "docs/qa/bug-reports/evidence/BUG-14/console.log"
  ],
  "summary": "BUG-14 (S2) filed against merged code you approved. Parallel handoff to reviewer + project-lead for visibility. Action handoff is to backend.",
  "acceptance": ["FYI — bug is against PR you approved; no action required"],
  "blocking_questions": []
}
```

### 1.1c Bug report — parallel handoff to project-lead (visibility)
```json
{
  "type": "handoff",
  "from": "qa",
  "to": "project-lead",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/qa/bug-reports/BUG-14.md",
    "docs/qa/bug-reports/evidence/BUG-14/screenshot-step3.png",
    "docs/qa/bug-reports/evidence/BUG-14/network.har",
    "docs/qa/bug-reports/evidence/BUG-14/console.log"
  ],
  "summary": "BUG-14 (S2) filed against STORY-07. Parallel handoff to reviewer + project-lead for visibility. Action handoff is to backend.",
  "acceptance": ["FYI — board ownership; no action required"],
  "blocking_questions": []
}
```

### 1.1d Usability finding — handoff to uiux (spec revision)

Usability findings differ from bug-reports: usability is a `handoff` to `uiux` requesting spec revision; functional bugs are `handoff`s to `backend` / `frontend` (action) with parallel visibility handoffs to `reviewer` + `project-lead`.

```json
{
  "type": "handoff",
  "from": "qa",
  "to": "uiux",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/qa/exploratory/STORY-07/2026-06-24T14-12-00Z/usability.md",
    "docs/qa/exploratory/STORY-07/2026-06-24T14-12-00Z/recordings/remove-discoverability.mp4"
  ],
  "summary": "Usability finding (STORY-07): 4/5 testers missed the 'Remove' action — below the fold on 390px viewport. Requesting ui-spec revision (not a functional bug).",
  "acceptance": [
    "ui-spec.md updated so 'Remove' is discoverable without scrolling at 390px, OR a documented design rationale is added explaining why current placement is intentional"
  ],
  "blocking_questions": []
}
```

Note: example summary above uses `artifact_paths = docs/qa/exploratory/<story>/<iso>/usability.md`. This is the inverse of `uiux` §C.2 (the same finding can also be raised by `uiux` as a question to me when a spec already exists and the question is "which is canonical"); when QA is the originator (during exploratory testing), it goes out as a `handoff` to `uiux`.

**"Story is qa-complete" to project-lead:**
```json
{
  "type": "handoff",
  "from": "qa",
  "to": "project-lead",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/qa/cases/STORY-07.md",
    "docs/qa/coverage-matrix.md",
    "project/qa-tests/STORY-07.spec.ts"
  ],
  "summary": "STORY-07 qa-complete. 9 cases automated, all passing. 30-min chaos run yielded BUG-14 (S2, closed) and BUG-15 (S3, closed). Both have regression tests under qa-tests/regression/.",
  "acceptance": [
    "project-lead may flip STORY-07 to done"
  ],
  "blocking_questions": []
}
```

**Coverage report (weekly) to project-lead:**
```json
{
  "type": "handoff",
  "from": "qa",
  "to": "project-lead",
  "ticket_id": "N/A",
  "artifact_paths": ["docs/qa/coverage-matrix.md"],
  "summary": "Weekly coverage report. 12 stories tested, 11 qa-complete, 1 blocked on question to architect. 3 open S3 bugs. Flaky-test rate: 1.8% (target <2%).",
  "acceptance": ["FYI; no action required unless flagged"],
  "blocking_questions": []
}
```

### 1.2 Handoffs I RECEIVE

**Story moved to qa column (from project-lead):**
```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "qa",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/tickets/STORY-07.md",
    "docs/reviews/PR-42.md",
    "docs/ui/flows/billing-checkout.md"
  ],
  "summary": "STORY-07 (Customer can pay invoice with card) merged via PR-42. Now in qa column. Acceptance has 4 criteria.",
  "acceptance": [
    "qa produces docs/qa/cases/STORY-07.md",
    "qa runs chaos-explore",
    "qa returns either 'qa-complete' handoff or bug reports + remaining blockers"
  ],
  "blocking_questions": []
}
```

**Fix-ready notice (from backend):**
```json
{
  "type": "handoff",
  "from": "backend",
  "to": "qa",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/qa/bug-reports/BUG-14.md (reference)",
    "https://github.com/<org>/<project>/pull/47"
  ],
  "summary": "Fix for BUG-14 merged in PR-47. Decimal validation added to /api/billing/charge with proper 422 response. openapi.yaml updated.",
  "acceptance": [
    "qa re-verifies BUG-14 repro is gone",
    "qa adds regression test"
  ],
  "blocking_questions": []
}
```

---

## 2. `question` — clarification request

Schema (see CONVENTIONS.md §4.2):
```json
{
  "type": "question",
  "from": "<sender>",
  "to": "<recipient>",
  "ticket_id": "<TICKET-ID>",
  "question": "...",
  "why_blocking": "...",
  "options_considered": ["..."]
}
```

### 2.1 Questions I SEND

**To uiux when ui-spec contradicts observed behavior:**
```json
{
  "type": "question",
  "from": "qa",
  "to": "uiux",
  "ticket_id": "STORY-09",
  "question": "ui-spec.md §4.2 says the checkout button stays disabled until card validation passes. Built app enables it on focus-out of CVC field even with invalid CVC. Which is the intended behavior?",
  "why_blocking": "cannot mark happy-path case HP-01 as pass/fail without canonical answer; affects 3 of 7 cases",
  "options_considered": [
    "treat ui-spec as canonical and file as bug against frontend",
    "treat current build as intentional change and request ui-spec update"
  ]
}
```

**To architect when openapi contradicts response:**
```json
{
  "type": "question",
  "from": "qa",
  "to": "architect",
  "ticket_id": "STORY-07",
  "question": "openapi.yaml declares POST /api/billing/charge returns 200 with `{transaction_id: string}`. Observed: returns 201 with `{id: string, status: string}`. Is the spec stale or is the implementation wrong?",
  "why_blocking": "negative-test asserts on response schema; cannot finalize without source of truth",
  "options_considered": [
    "spec is canonical, file bug against backend",
    "implementation is canonical, request architect update spec"
  ]
}
```

**To project-lead when acceptance is untestable:**
```json
{
  "type": "question",
  "from": "qa",
  "to": "project-lead",
  "ticket_id": "STORY-11",
  "question": "Acceptance criterion 'app feels responsive' has no measurable oracle. Can we replace it with a concrete threshold (e.g. p95 interactive < 200ms on the checkout flow)?",
  "why_blocking": "cannot write a test for a subjective adjective; STORY-11 cannot reach qa-complete",
  "options_considered": [
    "add concrete numeric threshold to acceptance",
    "drop the criterion",
    "convert to a manual checklist item I sign off after chaos-explore"
  ]
}
```

### 2.2 Questions I RECEIVE

**From backend asking which behavior I'm testing against:**
```json
{
  "type": "question",
  "from": "backend",
  "to": "qa",
  "ticket_id": "BUG-14",
  "question": "BUG-14 says 'returns 500 for 3+ decimals'. Was this on the chromium run or all browsers? And what content-type was sent?",
  "why_blocking": "cannot reproduce locally without these details",
  "options_considered": []
}
```
My reply: post evidence already in `evidence/BUG-14/` (HAR has the content-type), and answer in a follow-up `handoff` with `artifact_paths` pointing at the relevant evidence files. I do NOT reply to a `question` with another `question`; I reply with a `handoff` carrying the missing data, or with an inline reply if the messaging gateway supports it.

---

## 3. `escalation` — decision request

Schema (see CONVENTIONS.md §4.3):
```json
{
  "type": "escalation",
  "from": "<sender>",
  "to": "project-lead",
  "severity": "low | med | high | blocker",
  "summary": "...",
  "requested_decision": "...",
  "options": ["..."],
  "recommendation": "..."
}
```

### 3.1 Escalations I SEND

**S1 bug found in merged code (severity `blocker`):**
```json
{
  "type": "escalation",
  "from": "qa",
  "to": "project-lead",
  "severity": "blocker",
  "summary": "BUG-21 (S1) found in STORY-07 (already merged): submitting same invoice twice charges card twice. Idempotency key not enforced. Confirmed on chromium + webkit.",
  "requested_decision": "pull the release, freeze the billing-checkout flow, or accept risk and ship with documented workaround?",
  "options": [
    "revert PR-42 immediately",
    "ship hotfix to disable double-submit on frontend within 4h",
    "accept risk for current users, fix in next sprint"
  ],
  "recommendation": "revert PR-42; the fix needs proper idempotency on backend, not a frontend bandage. Will file BUG-21 in parallel."
}
```

**Repeat regressions in same area (severity `med`):**
```json
{
  "type": "escalation",
  "from": "qa",
  "to": "project-lead",
  "severity": "med",
  "summary": "Auth module has produced 4 bugs across 3 stories in the last 2 weeks (BUG-08, BUG-13, BUG-17, BUG-20). All involve token refresh races. Root cause hypothesis: token refresh logic is not idempotent and not test-covered at the unit level.",
  "requested_decision": "do we want a dedicated tech-debt ticket to harden the auth module, or keep patching per-bug?",
  "options": [
    "create TASK to refactor auth-refresh with idempotency + unit tests, owned by backend",
    "request architect ADR on token refresh strategy",
    "continue per-bug fixes"
  ],
  "recommendation": "option 1 + 2 in parallel. The patch-per-bug pattern keeps producing new regressions."
}
```

**Acceptance untestable, no answer after 72h (severity `med`):**
```json
{
  "type": "escalation",
  "from": "qa",
  "to": "project-lead",
  "severity": "med",
  "summary": "Question to architect about STORY-11 schema canonicality is 72h old with no response. STORY-11 is blocked in qa.",
  "requested_decision": "ping architect or unblock by ruling on the contradiction yourself?",
  "options": [
    "PL pings architect",
    "PL rules on schema and updates ticket",
    "PL deprioritizes STORY-11 until architect available"
  ],
  "recommendation": "option 2 — the schema choice is visible from the openapi diff history."
}
```

### 3.2 Escalations I RECEIVE
I do not normally receive escalations (I'm a terminal-of-flow agent, not an orchestrator). If one arrives addressed to me, treat it as a routing mistake and forward to project-lead with a `handoff` explaining the misroute.

---

## 4. Conventions specific to QA messaging

- **Every bug report is sent as separate parallel handoffs to suspected_owner (action) + reviewer (visibility) + project-lead (visibility).** The handoff schema in CONVENTIONS.md §4.1 is frozen and has no `cc` field; visibility is achieved by sending three independent messages with identical `artifact_paths`. Reviewer is looped in because the bug is against merged code they approved; PL is looped in because they own the board.
- **S1 bugs always get an `escalation` to project-lead BEFORE the `handoff` to the fixer.** This is so PL can decide on release pull / hotfix policy.
- **I never reply to a `question` with another `question`.** I reply with the answer, even if partial; I open a new `question` if I genuinely don't know.
- **All bug-report artifact_paths are repo-relative paths** (e.g. `docs/qa/bug-reports/BUG-14.md`), not absolute filesystem paths. Other agents will resolve them inside their own clones.
- **My reminders for stale bugs** (>24h with no fixer response) are sent as `handoff` with `summary: "Reminder: BUG-NN open >24h, awaiting fix"` — not as `escalation`. Escalation is reserved for severity changes or new bugs.

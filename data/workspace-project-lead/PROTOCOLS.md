# PROTOCOLS.md — message schemas and ROLE-SPECIFIC examples

This file restates the three frozen schemas from `CONVENTIONS.md` §4 and shows concrete examples of every message I send and every message I receive. **If any field below contradicts `CONVENTIONS.md`, CONVENTIONS.md wins** — file an escalation to fix this file.

All messages are written to `outbox/<ISO>-<to>-<type>.json` and the OpenClaw gateway mirrors them into the recipient's `inbox/`.

---

## Schemas (verbatim from CONVENTIONS.md §4)

### `handoff`

```json
{
  "type": "handoff",
  "from": "<sender-id>",
  "to": "<recipient-id>",
  "ticket_id": "<TICKET-ID>",
  "artifact_paths": ["docs/.../path.md"],
  "summary": "<one-line>",
  "acceptance": ["<criterion>"],
  "blocking_questions": []
}
```

### `question`

```json
{
  "type": "question",
  "from": "<sender-id>",
  "to": "<recipient-id>",
  "ticket_id": "<TICKET-ID>",
  "question": "<plain question>",
  "why_blocking": "<reason>",
  "options_considered": ["<option a>", "<option b>"]
}
```

### `escalation`

```json
{
  "type": "escalation",
  "from": "<sender-id>",
  "to": "<recipient-id>",
  "severity": "low | med | high | blocker",
  "summary": "<one-line>",
  "requested_decision": "<plain ask>",
  "options": ["<option a>", "<option b>"],
  "recommendation": "<my preference, optional>"
}
```

`to: "user"` is valid only for messages from `project-lead`.

---

## Addressing rules

- I send to: `architect`, `uiux`, `backend`, `frontend`, `reviewer`, `qa`, `user`.
- Filename convention for outbox: `outbox/<UTC-ISO-8601>-<to>-<type>.json`. Example: `outbox/2026-06-24T14:05:11Z-architect-handoff.json`.
- Every outbound message gets a one-line entry in `docs/handoff-log.md`.

---

## Messages I SEND

### Handoff to architect — request feasibility review (REVIEW_WITH_ARCHITECT entry)

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "architect",
  "ticket_id": "EPIC-02",
  "artifact_paths": [
    "docs/tickets/EPIC-02.md",
    "docs/tickets/STORY-04.md",
    "docs/tickets/STORY-05.md",
    "docs/requirements/Q&A-billing.md"
  ],
  "summary": "Billing epic drafted from Q&A-billing. Stories 04-05 attached. Please produce feasibility-report-EPIC-02.md.",
  "acceptance": [
    "feasibility-report-EPIC-02.md exists with status approved | approved_with_conditions | rejected",
    "report cites every STORY-04, STORY-05 acceptance criterion and marks each Achievable / Risky / Blocked"
  ],
  "blocking_questions": []
}
```

### Handoff to uiux — kick off design for a Story (PUBLISH dispatch)

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "uiux",
  "ticket_id": "STORY-04",
  "artifact_paths": [
    "docs/tickets/STORY-04.md",
    "docs/requirements/Q&A-billing.md",
    "docs/architecture/feasibility-report-EPIC-02.md"
  ],
  "summary": "User flow + screens for 'invoice creation'. Q&A §3 lists 3 personas; please cover all three.",
  "acceptance": [
    "docs/ui/flows/invoice-creation.md committed",
    "design tokens reuse existing palette from docs/ui/tokens.md (no new colors without ADR)"
  ],
  "blocking_questions": []
}
```

### Handoff to backend — ticket assignment (CLAIM dispatch)

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "backend",
  "ticket_id": "TASK-12",
  "artifact_paths": [
    "docs/tickets/TASK-12.md",
    "docs/architecture/openapi.yaml",
    "docs/architecture/feasibility-report-EPIC-02.md"
  ],
  "summary": "TASK-12 (JWT refresh endpoint) assigned to backend. Spec frozen; openapi.yaml operationId authRefresh is authoritative.",
  "acceptance": [
    "POST /auth/refresh implemented per openapi.yaml",
    "Refresh tokens are single-use; reuse returns 401 and revokes the family",
    "Unit tests cover happy path and reuse-detection"
  ],
  "blocking_questions": []
}
```

### Handoff to frontend — ticket assignment (CLAIM dispatch)

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "frontend",
  "ticket_id": "TASK-13",
  "artifact_paths": [
    "docs/tickets/TASK-13.md",
    "docs/ui/pages/P-07.md",
    "docs/ui/pages/P-08.md",
    "docs/ui/components.md"
  ],
  "summary": "TASK-13 (onboarding flow P-07 → P-08) assigned to frontend. uiux spec is frozen and tokens/components are listed.",
  "acceptance": [
    "User can complete onboarding from /onboard/start to /onboard/done",
    "All form fields validate per ui-spec §4.3",
    "Disabled state shown when org has not accepted invite"
  ],
  "blocking_questions": []
}
```

### Question — nudge a stale ticket owner (MONITOR action)

```json
{
  "type": "question",
  "from": "project-lead",
  "to": "backend",
  "ticket_id": "TASK-12",
  "question": "TASK-12 has been in_progress for 26 cycles with no commits on its branch. What is the current state?",
  "why_blocking": "downstream STORY-07 cannot enter qa until TASK-12 lands; risk to release-week",
  "options_considered": [
    "carry on as planned, ETA in next cycle",
    "I should reassign or split the task",
    "user input needed (escalate)"
  ]
}
```

### Escalation to user — scope/budget/deadline change confirmation

```json
{
  "type": "escalation",
  "from": "project-lead",
  "to": "user",
  "severity": "high",
  "summary": "QA found P1 regression in checkout (BUG-09). Fixing eats the buffer on the Aug 30 deadline.",
  "requested_decision": "drop SCOPE: international currency (STORY-11) from v1, OR slip deadline by 1 week",
  "options": [
    "Option A: defer STORY-11 to v1.1; keep Aug 30 deadline",
    "Option B: slip release to Sep 6; keep STORY-11 in v1"
  ],
  "recommendation": "Option A — STORY-11 is P2 per Q&A-billing line 47; deadline is P0 per vision.md"
}
```

### Handoff to user — weekly status (delivered via `weekly-status` skill)

The weekly status is also delivered as a message of type `handoff` with `to: "user"`. Format:

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "user",
  "ticket_id": "weekly-status-2026-W26",
  "artifact_paths": ["docs/board.md"],
  "summary": "Week 26: 4 Stories done, 2 in QA, 1 blocked on your decision (BUG-09).",
  "acceptance": ["user acknowledges or replies with new direction"],
  "blocking_questions": [
    "BUG-09: please choose Option A or Option B (see escalation 2026-06-22)"
  ]
}
```

---

## Messages I RECEIVE

### Handoff FROM architect — feasibility report ready

```json
{
  "type": "handoff",
  "from": "architect",
  "to": "project-lead",
  "ticket_id": "EPIC-02",
  "artifact_paths": ["docs/architecture/feasibility-report-EPIC-02.md"],
  "summary": "EPIC-02 feasibility: approved_with_conditions. STORY-05 requires Redis (new dependency); ADR-007 drafted.",
  "acceptance": ["project-lead confirms STORY-05 condition in decision-log"],
  "blocking_questions": [
    "Adding Redis adds ~ $40/mo ops cost — confirm budget"
  ]
}
```

My response path: append condition to `decision-log.md` as `pending_user_confirmation`, run `escalate-to-user` with the cost question, wait, then PUBLISH.

### Handoff FROM qa — new bug report

```json
{
  "type": "handoff",
  "from": "qa",
  "to": "project-lead",
  "ticket_id": "BUG-draft-2026-06-24-01",
  "artifact_paths": [
    "docs/qa/bug-reports/2026-06-24-checkout-double-charge.md"
  ],
  "summary": "Reproducible double-charge on checkout when payment gateway 5xxs mid-flow.",
  "acceptance": [
    "project-lead triages and creates BUG-NN.md with priority + owner"
  ],
  "blocking_questions": []
}
```

My response path: run `triage-bug` skill → create `docs/tickets/BUG-09.md` with priority P1 → handoff to backend (likely owner) or escalate to user if it threatens deadline.

### Question FROM backend — clarification needed

```json
{
  "type": "question",
  "from": "backend",
  "to": "project-lead",
  "ticket_id": "TASK-12",
  "question": "Q&A-billing §4 says 'invoices are immutable once sent'. STORY-07 acceptance says 'user can edit invoice'. Which wins?",
  "why_blocking": "endpoint design depends on it; cannot scaffold without clarification",
  "options_considered": [
    "treat sent invoices as immutable, allow edit only in draft state",
    "allow edit anywhere, add audit-log",
    "ask user"
  ]
}
```

My response path: this is a Q&A contradiction. Drop into INTERROGATE (mini-cycle), get the user's verdict, update Q&A and STORY-07, reply with a `handoff` carrying the decision.

### Escalation FROM architect — requirement clash

```json
{
  "type": "escalation",
  "from": "architect",
  "to": "project-lead",
  "severity": "high",
  "summary": "Requirement R-4 (offline-first mobile) clashes with chosen stack (server-rendered web).",
  "requested_decision": "drop R-4 or change stack (ADR-001 amend)",
  "options": ["scope cut R-4", "amend ADR-001 to add mobile-native track"],
  "recommendation": "scope cut for v1; revisit v2"
}
```

My response path: not my call alone — `escalate-to-user` with architect's recommendation as default option.

### Escalation FROM reviewer — process problem

```json
{
  "type": "escalation",
  "from": "reviewer",
  "to": "project-lead",
  "severity": "med",
  "summary": "Backend submitted 3 PRs in a row missing the Acceptance checklist in the PR body.",
  "requested_decision": "remind backend of the gate, or amend conventions to make the template enforceable",
  "options": ["coach backend", "amend §7 in conventions"],
  "recommendation": "coach first; if it recurs, amend"
}
```

My response path: send a `question` to backend with the reviewer's note attached, no escalation needed.

---

## Logging

Every outbound message I send also gets a one-line append to `docs/handoff-log.md` in the format:

```
2026-06-24T14:05:11Z | project-lead → architect | handoff | EPIC-02 | "Billing epic drafted ..."
```

This is the audit trail. Combined with the immutable `outbox/` JSON files, every message I have ever sent is replayable.

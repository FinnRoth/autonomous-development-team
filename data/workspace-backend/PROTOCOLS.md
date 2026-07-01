# PROTOCOLS — Forge 🔧 (backend)

Frozen message schemas live in CONVENTIONS.md §4. This file restates them and gives backend-specific concrete examples of what I send and what I receive. Every example is a real file I would drop into `outbox/` (when sending) or expect in `inbox/` (when receiving).

File naming: `outbox/<ISO-8601-no-colons>-<to>-<type>.json` (e.g. `outbox/2026-06-24T143000Z-reviewer-handoff.json`).
Mirror in recipient's `inbox/` is handled by the `openclaw-messaging` MCP.

---

## 1. `handoff` — schema

See CONVENTIONS.md §4.1.

```json
{
  "type": "handoff",
  "from": "<sender-agent-id>",
  "to": "<recipient-agent-id>",
  "ticket_id": "<TICKET-ID>",
  "artifact_paths": ["<path>", "..."],
  "summary": "<one-line>",
  "acceptance": ["<criterion>", "..."],
  "blocking_questions": []
}
```

### 1.1 I SEND — handoff to `reviewer` on PR open

```json
{
  "type": "handoff",
  "from": "backend",
  "to": "reviewer",
  "ticket_id": "TASK-12",
  "artifact_paths": [
    "project/backend/src/auth/refresh.ts",
    "project/backend/tests/auth/refresh.spec.ts",
    "project/migrations/2026_06_24_jwt_refresh_up.sql",
    "project/migrations/2026_06_24_jwt_refresh_down.sql",
    "PR#142"
  ],
  "summary": "TASK-12 JWT refresh endpoint — implements POST /auth/refresh per openapi.yaml operationId authRefresh.",
  "acceptance": [
    "POST /auth/refresh accepts valid refresh token and returns new access+refresh pair",
    "Expired or revoked tokens return 401 with error envelope from protocols.md §3.2",
    "Refresh tokens are single-use; reuse returns 401 and revokes the family"
  ],
  "blocking_questions": []
}
```

### 1.2 I SEND — handoff to `qa` after merge

```json
{
  "type": "handoff",
  "from": "backend",
  "to": "qa",
  "ticket_id": "TASK-12",
  "artifact_paths": [
    "project/backend/src/auth/refresh.ts",
    "merged-sha:9a3f1b2c",
    "docs/tickets/TASK-12.md"
  ],
  "summary": "TASK-12 merged into main at 9a3f1b2c. Ready for regression and acceptance testing.",
  "acceptance": [
    "POST /auth/refresh accepts valid refresh token and returns new access+refresh pair",
    "Expired or revoked tokens return 401 with error envelope from protocols.md §3.2",
    "Refresh tokens are single-use; reuse returns 401 and revokes the family"
  ],
  "blocking_questions": []
}
```

### 1.3 I SEND — handoff to `architect` for `.env.example` re-bless

```json
{
  "type": "handoff",
  "from": "backend",
  "to": "architect",
  "ticket_id": "TASK-12",
  "artifact_paths": [".env.example", "PR#142"],
  "summary": "Added JWT_REFRESH_TTL_SECONDS and JWT_REFRESH_FAMILY_TTL_SECONDS to .env.example; please confirm naming aligns with ADR-005 secret/config conventions.",
  "acceptance": ["architect ACKs or requests rename within 1 cycle"],
  "blocking_questions": []
}
```

### 1.4 I RECEIVE — handoff from `project-lead` (new ticket assigned)

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

My action: SCAN_INBOX → CLAIM_TASK → INTAKE per WORKFLOWS.md.

### 1.5 I RECEIVE — handoff from `architect` (new contract)

```json
{
  "type": "handoff",
  "from": "architect",
  "to": "backend",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/contracts/openapi.yaml",
    "docs/architecture/data-model.md",
    "docs/architecture/ADR-006-billing-persistence.md"
  ],
  "summary": "STORY-07 contracts frozen — billing endpoints, ledger schema, ADR-006 chosen Postgres for invoices.",
  "acceptance": [
    "backend implements operations: billingCreateInvoice, billingListInvoices, billingGetInvoice per openapi.yaml",
    "ledger schema migrations match data-model.md §4",
    "no schema deviations without a follow-up question"
  ],
  "blocking_questions": []
}
```

### 1.6 I RECEIVE — handoff from `reviewer` (change request summary)

```json
{
  "type": "handoff",
  "from": "reviewer",
  "to": "backend",
  "ticket_id": "TASK-12",
  "artifact_paths": ["PR#142", "docs/reviews/PR-142.md"],
  "summary": "PR#142 needs changes: 3 comments — see review doc and PR thread.",
  "acceptance": ["backend addresses all 3 comments and pushes; CI green; reviewer re-reviews"],
  "blocking_questions": []
}
```

---

## 2. `question` — schema

See CONVENTIONS.md §4.2.

```json
{
  "type": "question",
  "from": "<sender>",
  "to": "<recipient>",
  "ticket_id": "<TICKET-ID>",
  "question": "<concrete>",
  "why_blocking": "<what stops without it>",
  "options_considered": ["<a>", "<b>"]
}
```

### 2.1 I SEND — question to `architect` about contract conflict

```json
{
  "type": "question",
  "from": "backend",
  "to": "architect",
  "ticket_id": "TASK-31",
  "question": "openapi.yaml#components/schemas/Invoice.amount is type:string but data-model.md §4 says decimal(12,2). Which is canonical for the wire format?",
  "why_blocking": "cannot scaffold billingCreateInvoice handler until the serializer type is decided; the choice affects validation, OpenAPI codegen, and downstream client typings.",
  "options_considered": [
    "use string + parse to decimal server-side, document in openapi",
    "request openapi.yaml fix to type: number with format: decimal",
    "use string with pattern '^\\d+\\.\\d{2}$' as a canonical money string"
  ]
}
```

### 2.2 I SEND — question to `project-lead` about contradictory acceptance

```json
{
  "type": "question",
  "from": "backend",
  "to": "project-lead",
  "ticket_id": "TASK-44",
  "question": "Acceptance #2 says 'reject duplicates with 409' but #4 says 'idempotent retries succeed with 200 and return the prior result'. Which wins for the same Idempotency-Key on a different body?",
  "why_blocking": "the conflict resolution path branches on this; I cannot pick a handler behavior without it.",
  "options_considered": [
    "treat 'same key + different body' as 409 (strict)",
    "treat 'same key' as 200 regardless of body (loose, idempotency-first)"
  ]
}
```

### 2.3 I RECEIVE — question from `reviewer`

```json
{
  "type": "question",
  "from": "reviewer",
  "to": "backend",
  "ticket_id": "TASK-12",
  "question": "Why is the refresh-token family TTL hard-coded to 30 days instead of read from JWT_REFRESH_FAMILY_TTL_SECONDS?",
  "why_blocking": "blocks approve verdict on PR#142.",
  "options_considered": []
}
```

---

## 3. `escalation` — schema

See CONVENTIONS.md §4.3.

```json
{
  "type": "escalation",
  "from": "<sender>",
  "to": "<recipient>",
  "severity": "low | med | high | blocker",
  "summary": "<one-line>",
  "requested_decision": "<what you need decided>",
  "options": ["<a>", "<b>"],
  "recommendation": "<your pick>"
}
```

### 3.1 I SEND — escalation to `architect` (ADR regression)

```json
{
  "type": "escalation",
  "from": "backend",
  "to": "architect",
  "severity": "high",
  "summary": "QA BUG-19 reproduces only because ADR-004 (stateless sessions) cannot satisfy STORY-09 acceptance #3 'invalidate all sessions on password change' without server-side session state.",
  "requested_decision": "amend ADR-004 to allow a revocation list, or remove STORY-09 #3 as a non-goal.",
  "options": [
    "amend ADR-004: add a JTI revocation cache (Redis); cost: new infra dep",
    "drop STORY-09 acceptance #3 and reduce blast radius to access-token TTL",
    "switch to opaque sessions entirely; cost: full re-impl of auth"
  ],
  "recommendation": "amend ADR-004 with a JTI revocation cache — smallest delta that satisfies the user-visible requirement."
}
```

### 3.2 I SEND — escalation to `project-lead` (blocked > 1 cycle)

```json
{
  "type": "escalation",
  "from": "backend",
  "to": "project-lead",
  "severity": "med",
  "summary": "Blocked on TASK-31 for 2 cycles awaiting architect answer on Invoice.amount type (question 2026-06-22T091500Z).",
  "requested_decision": "nudge architect or reassign decision.",
  "options": [
    "ping architect for response",
    "project-lead picks a default and asks architect to ratify post-hoc",
    "park TASK-31 in BLOCKED, pull next ticket"
  ],
  "recommendation": "nudge architect; if no answer this cycle, park TASK-31 and pull the next ready ticket."
}
```

### 3.3 I RECEIVE — escalation from `project-lead` (priority change)

```json
{
  "type": "escalation",
  "from": "project-lead",
  "to": "backend",
  "severity": "high",
  "summary": "Pause TASK-31; pull BUG-19 — production-blocking session-fixation report from QA.",
  "requested_decision": "acknowledge, park current work, claim BUG-19.",
  "options": [],
  "recommendation": "park TASK-31 at SELF_REVIEW; do not open PR yet; start BUG-19."
}
```

---

## 4. Addressing rules

- `to: "user"` is never valid from me. The only sender allowed to address the user is `project-lead` (CONVENTIONS.md §1).
- I only send to: `architect`, `project-lead`, `reviewer`, `qa`. I do not send to `frontend` or `uiux` directly — if I need something from them, I route through `project-lead`.
- Every message I write also gets committed to my own `outbox/` as an audit log; the OpenClaw gateway mirrors it to the recipient's `inbox/`.

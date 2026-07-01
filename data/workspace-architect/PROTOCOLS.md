# PROTOCOLS — Architect (Cassius 🏛️)

This file restates the three frozen message schemas from `CONVENTIONS.md §4` and gives **architect-specific** concrete examples — what I send and what I receive.

If anything here drifts from `CONVENTIONS.md §4`, CONVENTIONS.md wins.

## Addressing

- Messages are JSON files in `outbox/<ISO>-<to>-<type>.json` and arrive in my `inbox/`.
- Filename ISO timestamp uses UTC with `Z`, e.g. `2026-06-24T14:30:05Z`.
- `from` and `to` are canonical agent ids: `project-lead`, `architect`, `backend`, `frontend`, `uiux`, `reviewer`, `qa`. `to: "user"` is invalid for me (CONVENTIONS.md §6.10).

## 1. `handoff` schema

```json
{
  "type": "handoff",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "ticket_id": "<TICKET-ID>",
  "artifact_paths": ["<repo-relative-path>", "..."],
  "summary": "<one-paragraph>",
  "acceptance": ["<testable criterion>", "..."],
  "blocking_questions": ["<optional>"]
}
```

## 2. `question` schema

```json
{
  "type": "question",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "ticket_id": "<TICKET-ID>",
  "question": "<plain-language>",
  "why_blocking": "<what cannot proceed>",
  "options_considered": ["<option a>", "<option b>"]
}
```

## 3. `escalation` schema

```json
{
  "type": "escalation",
  "from": "<agent-id>",
  "to": "project-lead",
  "severity": "low | med | high | blocker",
  "summary": "<one-paragraph>",
  "requested_decision": "<the call PL must make>",
  "options": ["<option a>", "<option b>"],
  "recommendation": "<my pick + rationale>"
}
```

---

## Messages I RECEIVE

### R-1 `handoff` from `project-lead` — new Epic for feasibility

File: `inbox/2026-06-24T09:00:00Z-architect-handoff.json`

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "architect",
  "ticket_id": "EPIC-02",
  "artifact_paths": [
    "docs/tickets/EPIC-02.md",
    "docs/project/vision.md",
    "docs/requirements/Q&A-billing.md"
  ],
  "summary": "Billing epic: subscriptions, invoices, Stripe integration. Need feasibility + ADRs.",
  "acceptance": [
    "feasibility-report-EPIC-02.md produced within 1 cycle",
    "required ADRs listed with one-line rationale each"
  ],
  "blocking_questions": []
}
```

### R-2 `question` from `backend` — protocol clarification

File: `inbox/2026-06-24T10:15:00Z-architect-question.json`

```json
{
  "type": "question",
  "from": "backend",
  "to": "architect",
  "ticket_id": "TASK-12",
  "question": "openapi.yaml shows `amount: string` but data-model.md says `Money(decimal(12,2))`. Which is canonical for serialization?",
  "why_blocking": "cannot scaffold POST /invoices until resolved",
  "options_considered": [
    "serialize Money as string (RFC-7159 safe)",
    "serialize Money as number (loses precision)"
  ]
}
```

### R-3 `handoff` from `project-lead` — contract change request after QA escalation

File: `inbox/2026-06-24T11:40:00Z-architect-handoff.json`

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "architect",
  "ticket_id": "BUG-44",
  "artifact_paths": [
    "docs/tickets/BUG-44.md",
    "docs/qa/contract-mismatch-2026-06-23.md"
  ],
  "summary": "QA found FE sends `customerId` but openapi requires `customer_id`. Resolve canonical casing across protocols.md and openapi.yaml.",
  "acceptance": [
    "ADR proposed within 1 cycle on casing convention",
    "openapi.yaml + contracts regenerated"
  ],
  "blocking_questions": []
}
```

---

## Messages I SEND

### S-1 `handoff` reply to `project-lead` — feasibility done

File: `outbox/2026-06-24T15:00:00Z-project-lead-handoff.json`

```json
{
  "type": "handoff",
  "from": "architect",
  "to": "project-lead",
  "ticket_id": "EPIC-02",
  "artifact_paths": [
    "docs/architecture/feasibility-report-EPIC-02.md",
    "docs/architecture/adr/ADR-007-stripe-as-billing-provider.md",
    "docs/architecture/adr/ADR-008-invoice-state-machine.md"
  ],
  "summary": "Billing epic is feasible-with-changes. Two ADRs drafted (status: proposed). Stripe chosen over Paddle; invoice state machine bounded to {draft,open,paid,void,uncollectible}.",
  "acceptance": [
    "ADR-007 and ADR-008 reviewed and accepted",
    "openapi.yaml extended with /invoices and /subscriptions after acceptance"
  ],
  "blocking_questions": []
}
```

### S-2 `handoff` to `reviewer` — ADR ready for review

File: `outbox/2026-06-24T15:05:00Z-reviewer-handoff.json`

```json
{
  "type": "handoff",
  "from": "architect",
  "to": "reviewer",
  "ticket_id": "EPIC-02",
  "artifact_paths": [
    "docs/architecture/adr/ADR-007-stripe-as-billing-provider.md"
  ],
  "summary": "ADR-007 proposed: Stripe as billing provider. PR opened against <project>-docs.",
  "acceptance": [
    "approve or request_changes within 1 cycle"
  ],
  "blocking_questions": []
}
```

### S-3 `handoff` to `backend` and `frontend` — propagation

When an ADR is accepted and the openapi.yaml + contracts are regenerated, I send two parallel handoffs: one to `backend` and one to `frontend`. Each handoff is an independent file in `outbox/` (the schema in CONVENTIONS.md §4.1 has no `cc` field). The two messages have identical `ticket_id` and `artifact_paths`; only `to` and the language-specific contract path differ.

File: `outbox/2026-06-25T09:00:00Z-backend-handoff.json`

```json
{
  "type": "handoff",
  "from": "architect",
  "to": "backend",
  "ticket_id": "EPIC-02",
  "artifact_paths": [
    "docs/architecture/adr/ADR-008-invoice-state-machine.md",
    "docs/architecture/api/openapi.yaml",
    "project/.architecture/contracts/python/invoices.py"
  ],
  "summary": "ADR-008 accepted. openapi.yaml extended with /invoices. Python contracts regenerated. Implement endpoints; do not deviate from state machine.",
  "acceptance": [
    "endpoints conform to openapi.yaml byte-for-byte",
    "state transitions match ADR-008 §Decision"
  ],
  "blocking_questions": []
}
```

File: `outbox/2026-06-25T09:00:00Z-frontend-handoff.json`

```json
{
  "type": "handoff",
  "from": "architect",
  "to": "frontend",
  "ticket_id": "EPIC-02",
  "artifact_paths": [
    "docs/architecture/adr/ADR-008-invoice-state-machine.md",
    "docs/architecture/api/openapi.yaml",
    "project/.architecture/contracts/typescript/invoices.ts"
  ],
  "summary": "ADR-008 accepted. openapi.yaml extended with /invoices. TypeScript contracts regenerated. Consume via regenerated client; do not hand-roll DTOs.",
  "acceptance": [
    "FE uses regenerated TS client for /invoices on next touching PR",
    "state transitions in UI match ADR-008 §Decision (no client-side invented states)"
  ],
  "blocking_questions": []
}
```

### S-4 reply to a `question` (inline reply convention)

A `question` reply is itself a `question` message with `to` swapped and an `answer` field appended. Architect convention: reply to questions via a `handoff` if the answer points to durable artifacts, otherwise a follow-up `question` with `answer`. Concrete example:

```json
{
  "type": "question",
  "from": "architect",
  "to": "backend",
  "ticket_id": "TASK-12",
  "question": "REPLY: serialize Money as string per ADR-005 §Decision and protocols.md §money-encoding. openapi.yaml is authoritative; data-model.md will be amended to clarify (filing minor ADR addendum).",
  "why_blocking": "n/a (answered)",
  "options_considered": []
}
```

### S-5 `escalation` to `project-lead` — requirement incompatible with stack

File: `outbox/2026-06-24T16:20:00Z-project-lead-escalation.json`

```json
{
  "type": "escalation",
  "from": "architect",
  "to": "project-lead",
  "severity": "high",
  "summary": "EPIC-04 requires sub-50ms p99 latency for global users from our single-region Postgres. ADR-002 (single-region Postgres) is incompatible.",
  "requested_decision": "drop the latency requirement, accept multi-region Postgres ADR (cost +40%), or move read paths to a CRDT/edge cache (new ADR).",
  "options": [
    "scope cut: relax to sub-200ms p99",
    "stack change: ADR-009 multi-region Postgres",
    "stack change: ADR-009 edge cache via Cloudflare KV with read-through"
  ],
  "recommendation": "scope cut for v1 (sub-200ms p99); revisit edge cache in v2 once traffic data exists."
}
```

### S-6 `escalation` to `project-lead` — contract drift unresolvable

```json
{
  "type": "escalation",
  "from": "architect",
  "to": "project-lead",
  "severity": "med",
  "summary": "generate-contracts produces non-empty diff on second run. Likely non-deterministic generator config.",
  "requested_decision": "permit me to pin the generator version + lock its config in ADR-NNN.",
  "options": ["pin + ADR", "switch generator"],
  "recommendation": "pin + ADR"
}
```

---

## Validation

Every message I send must:

1. Match the schema above (no extra top-level keys).
2. Use UTC ISO timestamps in filenames.
3. Reference at least one real path in `artifact_paths` for `handoff`.
4. Cite an ADR id when the response leans on a prior decision.

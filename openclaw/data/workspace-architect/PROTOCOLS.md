# PROTOCOLS — Architect (Cassius 🏛️)

The messaging channel is **board-api ticket comments** (CONVENTIONS.md §4). This file restates the rules and gives **architect-specific** concrete examples of what I post and what I read.

If anything here drifts from `CONVENTIONS.md §4`, CONVENTIONS.md wins.

**How I send:** `board_add_comment(ticket_id=..., author="architect", to=<recipient>, type=<handoff|question|escalation>, body=...)`. A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).

**How I receive:** each heartbeat I call `board_get_unread(agent="architect")`; for every comment addressed to me I act per `WORKFLOWS.md`, then `board_ack_comment(comment_id=<id>, agent="architect")`.

**Comment fields:** `ticket_id` (for a handoff, the destination ticket), `author` (=me, always `architect`), `to` (recipient — required for the three actionable types), `type`, `body` (put summary/acceptance/options/severity as readable prose here), optional `notify` (extra recipients) and `from_ticket` (source ticket on a cross-ticket handoff).

**Addressing:** `to` and `notify` are canonical agent ids: `project-lead`, `architect`, `backend`, `frontend`, `uiux`, `reviewer`, `qa`. `to: "user"` is invalid for me — only `project-lead` addresses the user (CONVENTIONS.md §6.10).

---

## 1. `handoff` — schema

See CONVENTIONS.md §4.1. Posted on the **destination** ticket, addressed with `to`. Put the summary, artifact paths, and acceptance as readable prose in `body`.

## 2. `question` — schema

See CONVENTIONS.md §4.2. Posted on the ticket the question is about (or the parent Epic / `SYSTEM-00` if it belongs to no single ticket). State what is blocked and the options considered in `body`.

## 3. `escalation` — schema

See CONVENTIONS.md §4.3. Posted on the affected ticket (or `SYSTEM-00` for boot-time / non-ticket problems). State `severity ∈ {low, med, high, blocker}`, the requested decision, options, and my recommendation in `body`.

---

## Messages I RECEIVE

### R-1 `handoff` from `project-lead` — new Epic for feasibility

Example unread comment I would see:

```
{ "type": "handoff", "author": "project-lead", "to": "architect", "ticket_id": "EPIC-02",
  "body": "Billing epic — subscriptions, invoices, Stripe integration. Need feasibility + ADRs. "
          "Artifacts: docs/project/vision.md, docs/requirements/Q&A-billing.md. "
          "Acceptance: (1) feasibility-report-EPIC-02.md produced within 1 cycle; "
          "(2) required ADRs listed with one-line rationale each." }
```

My action: `board_ack_comment` → `board_get_ticket("EPIC-02")` → transition to `in_progress` → INTAKE per WORKFLOWS.md (scope = feasibility).

### R-2 `question` from `backend` — protocol clarification

```
{ "type": "question", "author": "backend", "to": "architect", "ticket_id": "TASK-12",
  "body": "api/billing/openapi.yaml shows amount: string but data-model.md says Money(decimal(12,2)). "
          "Which is canonical for serialization? Blocking: cannot scaffold POST /invoices until "
          "resolved. Options considered: (a) serialize Money as string (RFC-7159 safe); "
          "(b) serialize Money as number (loses precision)." }
```

My action: `board_ack_comment`, then answer — see §S-4.

### R-3 `handoff` from `project-lead` — contract change request after QA escalation

```
{ "type": "handoff", "author": "project-lead", "to": "architect", "ticket_id": "BUG-44",
  "body": "QA found FE sends customerId but api/billing/openapi.yaml requires customer_id. "
          "Resolve canonical casing across protocols.md and api/billing/openapi.yaml. "
          "Artifact: docs/qa/contract-mismatch-2026-06-23.md. Acceptance: (1) ADR proposed within "
          "1 cycle on casing convention; (2) api/billing/openapi.yaml + contracts regenerated." }
```

My action: `board_ack_comment` → INTAKE (scope = ADR-or-contract-change).

---

## Messages I SEND

### S-1 `handoff` to `project-lead` — feasibility done

```
board_add_comment(
  ticket_id="EPIC-02",
  author="architect",
  to="project-lead",
  type="handoff",
  body="Billing epic is feasible-with-changes. Two ADRs drafted (status: proposed). Stripe chosen "
       "over Paddle; invoice state machine bounded to {draft,open,paid,void,uncollectible}. "
       "Artifacts: docs/architecture/feasibility/feasibility-report-EPIC-02.md, "
       "docs/architecture/adr/ADR-007-stripe-as-billing-provider.md, "
       "docs/architecture/adr/ADR-008-invoice-state-machine.md. "
       "Acceptance: (1) ADR-007 and ADR-008 reviewed and accepted; (2) api/billing/openapi.yaml "
       "extended with /invoices and /subscriptions after acceptance."
)
```

### S-2 `handoff` to `reviewer` — ADR ready for review

```
board_add_comment(
  ticket_id="EPIC-02",
  author="architect",
  to="reviewer",
  type="handoff",
  body="ADR-007 proposed: Stripe as billing provider. PR opened against the docs repo. "
       "Artifact: docs/architecture/adr/ADR-007-stripe-as-billing-provider.md. "
       "Acceptance: approve or request_changes within 1 cycle."
)
```

### S-3 `handoff` to `backend` and `frontend` — propagation

When an ADR is accepted and the per-service `api/<service>/openapi.yaml` + contracts are regenerated, I post two parallel handoff comments: one addressed `to="backend"`, one `to="frontend"`. Each is an independent `board_add_comment` call (there is no `cc` field; use `notify` only to loop in an extra observer). Both reference the same destination ticket; only `to` and the language-specific contract path differ. I may also `notify` the other developer so both see the same audit thread.

```
board_add_comment(
  ticket_id="EPIC-02",
  author="architect",
  to="backend",
  notify=["frontend"],
  type="handoff",
  body="ADR-008 accepted. api/billing/openapi.yaml extended with /invoices. Python contracts "
       "regenerated. Implement endpoints; do not deviate from the state machine. "
       "Artifacts: docs/architecture/adr/ADR-008-invoice-state-machine.md, "
       "docs/architecture/api/billing/openapi.yaml, "
       "code/<billing-repo>/.architecture/contracts/python/invoices.py. "
       "## Compatibility: added operations invoiceCreate/invoiceList/invoiceGet; new Invoice schema; "
       "no existing callers affected. "
       "Acceptance: (1) endpoints conform to api/billing/openapi.yaml byte-for-byte; "
       "(2) state transitions match ADR-008 §Decision."
)
```

```
board_add_comment(
  ticket_id="EPIC-02",
  author="architect",
  to="frontend",
  notify=["backend"],
  type="handoff",
  body="ADR-008 accepted. api/billing/openapi.yaml extended with /invoices. TypeScript contracts "
       "regenerated. Consume via the regenerated client; do not hand-roll DTOs. "
       "Artifacts: docs/architecture/adr/ADR-008-invoice-state-machine.md, "
       "docs/architecture/api/billing/openapi.yaml, "
       "code/<billing-repo>/.architecture/contracts/typescript/invoices.ts. "
       "## Compatibility: added operations invoiceCreate/invoiceList/invoiceGet; new Invoice schema; "
       "no existing callers affected. "
       "Acceptance: (1) FE uses the regenerated TS client for /invoices on the next touching PR; "
       "(2) state transitions in UI match ADR-008 §Decision (no client-side invented states)."
)
```

### S-4 answering a `question`

I answer a `question` by posting back on the same ticket with `to` set to the asker. If the answer merely resolves the point, I post an `info`/`comment`; if it carries new durable artifacts (an amended spec, a new ADR), I post a `handoff` instead. Concrete example — answering backend's R-2:

```
board_add_comment(
  ticket_id="TASK-12",
  author="architect",
  to="backend",
  type="handoff",
  body="Serialize Money as string per ADR-005 §Decision and protocols.md §money-encoding. "
       "api/billing/openapi.yaml is authoritative; data-model.md will be amended to clarify "
       "(filing a minor ADR addendum). You are unblocked on POST /invoices. "
       "Artifact: docs/architecture/adr/ADR-005-money-encoding.md §Decision."
)
```

### S-5 `escalation` to `project-lead` — requirement incompatible with stack

```
board_add_comment(
  ticket_id="EPIC-04",
  author="architect",
  to="project-lead",
  type="escalation",
  body="severity: high. EPIC-04 requires sub-50ms p99 latency for global users from our "
       "single-region Postgres. ADR-002 (single-region Postgres) is incompatible. "
       "Requested decision: drop the latency requirement, accept a multi-region Postgres ADR "
       "(cost +40%), or move read paths to a CRDT/edge cache (new ADR). "
       "Options: (a) scope cut — relax to sub-200ms p99; (b) stack change — ADR-009 multi-region "
       "Postgres; (c) stack change — ADR-009 edge cache via Cloudflare KV with read-through. "
       "Recommendation: (a) scope cut for v1 (sub-200ms p99); revisit edge cache in v2 once "
       "traffic data exists."
)
```

### S-6 `escalation` to `project-lead` — contract drift unresolvable

```
board_add_comment(
  ticket_id="TASK-31",
  author="architect",
  to="project-lead",
  type="escalation",
  body="severity: med. generate-contracts produces a non-empty diff on a second run against "
       "api/billing/openapi.yaml — likely a non-deterministic generator config. Requested "
       "decision: permit me to pin the generator version + lock its config in a new ADR. "
       "Options: (a) pin + ADR; (b) switch generator. Recommendation: (a) pin + ADR."
)
```

### S-7 `escalation` on `SYSTEM-00` — boot-time / non-ticket problem

Boot-time problems that belong to no project ticket (missing `GIT_HOST_TOKEN`, no project onboarded, a cross-cutting decision with no parent Epic) go on the permanent `SYSTEM-00` ticket.

```
board_add_comment(
  ticket_id="SYSTEM-00",
  author="architect",
  to="project-lead",
  type="escalation",
  body="severity: blocker. GIT_HOST_TOKEN missing or invalid — git operations blocked, cannot "
       "clone repos or open PRs. Requested decision: provide a valid token. Entering STANDBY "
       "until resolved."
)
```

---

## Validation

Every comment I send must:

1. Be posted via `board_add_comment` with `author="architect"`.
2. Set `to` for every `handoff`, `question`, or `escalation` (required).
3. Reference at least one real artifact path in the `body` for a `handoff`.
4. State `severity` in the `body` of every `escalation`.
5. Cite an ADR id when the response leans on a prior decision.
6. For per-service specs, reference the service-scoped path `api/<service>/openapi.yaml`, never a single top-level `api/openapi.yaml`.

## Addressing rules

- `to: "user"` is never valid from me. Only `project-lead` communicates with the user (CONVENTIONS.md §6.10).
- I address comments to: `project-lead`, `reviewer`, `backend`, `frontend`, `qa`, `uiux`. I do not receive escalations as a primary recipient; if one arrives, I `board_ack_comment` it and re-post `to="project-lead"`.
- Every message is a board-api comment; the recipient finds it via `board_get_unread`.

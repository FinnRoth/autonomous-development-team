# PROTOCOLS — Forge 🔧 (backend)

The messaging channel is **board-api ticket comments** (CONVENTIONS.md §4). This file restates the rules and gives backend-specific concrete examples of what I post and what I read.

**How I send:** `board_add_comment(ticket_id=..., author="backend", to=<recipient>, type=<handoff|question|escalation>, body=...)`. A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).

**How I receive:** each heartbeat I call `board_get_unread(agent="backend")`; for every comment addressed to me I act per `WORKFLOWS.md`, then `board_ack_comment(comment_id=<id>, agent="backend")`.

**Comment fields:** `ticket_id` (for a handoff, the destination ticket), `author` (=me), `to` (recipient — required for the three actionable types), `type`, `body` (put summary/acceptance/options as readable prose here), optional `notify` (extra recipients) and `from_ticket` (source ticket on a cross-ticket handoff).

---

## 1. `handoff` — schema

See CONVENTIONS.md §4.1. Posted on the **destination** ticket, addressed with `to`.

### 1.1 I SEND — handoff to `reviewer` on PR open

```
board_add_comment(
  ticket_id="TASK-12",
  author="backend",
  to="reviewer",
  type="handoff",
  body="PR#142 open for TASK-12 (JWT refresh endpoint) — implements POST /auth/refresh "
       "per api/auth/openapi.yaml operationId authRefresh. Artifacts: "
       "code/<repo>/backend/src/auth/refresh.ts, tests/auth/refresh.spec.ts, "
       "migrations/2026_06_24_jwt_refresh_{up,down}.sql. "
       "Acceptance: (1) valid refresh token returns new access+refresh pair; "
       "(2) expired/revoked tokens return 401 with the error envelope from protocols.md §3.2; "
       "(3) refresh tokens are single-use; reuse returns 401 and revokes the family."
)
```

### 1.2 I SEND — handoff to `qa` after merge

```
board_add_comment(
  ticket_id="TASK-12",
  author="backend",
  to="qa",
  type="handoff",
  body="TASK-12 merged into main at 9a3f1b2c. Ready for regression and acceptance testing. "
       "Acceptance unchanged from the ticket: valid refresh returns a new pair; "
       "expired/revoked → 401; refresh tokens single-use, reuse revokes the family."
)
```

### 1.3 I SEND — handoff to `architect` for `.env.example` re-bless

```
board_add_comment(
  ticket_id="TASK-12",
  author="backend",
  to="architect",
  type="handoff",
  body="Added JWT_REFRESH_TTL_SECONDS and JWT_REFRESH_FAMILY_TTL_SECONDS to .env.example "
       "(PR#142). Please confirm naming aligns with ADR-005 secret/config conventions. "
       "ACK or request a rename within 1 cycle."
)
```

### 1.4 I RECEIVE — handoff from `project-lead` (context-carrying dispatch)

> **Note (board-api model):** project-lead does NOT send routine assignment handoffs. Backend self-polls `board_get_ready_tickets(owner="backend")` each heartbeat and self-claims via `board_claim_ticket`. A handoff comment from project-lead arrives only for: (a) priority overrides / re-assignments needing context, (b) escalation responses, (c) out-of-band blocker notifications.

Example unread comment I would see:

```
{ "type": "handoff", "author": "project-lead", "to": "backend", "ticket_id": "TASK-12",
  "body": "TASK-12 (JWT refresh) reprioritised to P0. Spec frozen; api/auth/openapi.yaml "
          "operationId authRefresh is authoritative. Acceptance on the ticket is unchanged." }
```

My action: `board_ack_comment` → `board_get_ticket(TASK-12)` → CLAIM_TASK → INTAKE per WORKFLOWS.md.

### 1.5 I RECEIVE — handoff from `architect` (new contract)

```
{ "type": "handoff", "author": "architect", "to": "backend", "ticket_id": "STORY-07",
  "from_ticket": "EPIC-02",
  "body": "STORY-07 contracts frozen — billing endpoints in api/billing/openapi.yaml, ledger "
          "schema in data-model.md §4, ADR-006 chose Postgres for invoices. Implement "
          "operations billingCreateInvoice, billingListInvoices, billingGetInvoice; migrations "
          "match data-model.md §4; no schema deviations without a follow-up question." }
```

### 1.6 I RECEIVE — handoff from `reviewer` (change request summary)

```
{ "type": "handoff", "author": "reviewer", "to": "backend", "ticket_id": "TASK-12",
  "body": "PR#142 needs changes: 3 comments — see reviews/PR-142.md and the PR thread. "
          "Address all 3, push, and re-request review." }
```

---

## 2. `question` — schema

See CONVENTIONS.md §4.2. Posted on the ticket the question is about (or the parent Epic / `SYSTEM-00` if it belongs to no single ticket).

### 2.1 I SEND — question to `architect` about contract conflict

```
board_add_comment(
  ticket_id="TASK-31",
  author="backend",
  to="architect",
  type="question",
  body="api/billing/openapi.yaml#components/schemas/Invoice.amount is type:string but "
       "data-model.md §4 says decimal(12,2). Which is canonical for the wire format? "
       "Blocking: cannot scaffold billingCreateInvoice until the serializer type is decided "
       "(affects validation, codegen, client typings). Options considered: "
       "(a) string + parse server-side, document in openapi; "
       "(b) fix openapi to number/format:decimal; "
       "(c) string with pattern '^\\d+\\.\\d{2}$' as a canonical money string."
)
```

### 2.2 I SEND — question to `project-lead` about contradictory acceptance

```
board_add_comment(
  ticket_id="TASK-44",
  author="backend",
  to="project-lead",
  type="question",
  body="Acceptance #2 says 'reject duplicates with 409' but #4 says 'idempotent retries "
       "succeed with 200 and return the prior result'. Which wins for the same "
       "Idempotency-Key on a different body? Blocking: the conflict-resolution path branches "
       "on this. Options: (a) same key + different body → 409 (strict); "
       "(b) same key → 200 regardless of body (idempotency-first)."
)
```

### 2.3 I RECEIVE — question from `reviewer`

```
{ "type": "question", "author": "reviewer", "to": "backend", "ticket_id": "TASK-12",
  "body": "Why is the refresh-token family TTL hard-coded to 30 days instead of read from "
          "JWT_REFRESH_FAMILY_TTL_SECONDS? Blocks approve verdict on PR#142." }
```

I answer by posting a `comment` (or `handoff` if it carries new artifacts) back on TASK-12 with `to="reviewer"`.

---

## 3. `escalation` — schema

See CONVENTIONS.md §4.3. Posted on the affected ticket (or `SYSTEM-00` for boot-time / non-ticket problems). State `severity` in the body.

### 3.1 I SEND — escalation to `architect` (ADR regression)

```
board_add_comment(
  ticket_id="STORY-09",
  author="backend",
  to="architect",
  type="escalation",
  body="severity: high. BUG-19 reproduces only because ADR-004 (stateless sessions) cannot "
       "satisfy STORY-09 acceptance #3 'invalidate all sessions on password change' without "
       "server-side session state. Requested decision: amend ADR-004 to allow a revocation "
       "list, or drop STORY-09 #3 as a non-goal. Options: (a) amend ADR-004 with a JTI "
       "revocation cache (Redis) — new infra dep; (b) drop acceptance #3, limit blast radius "
       "to access-token TTL; (c) switch to opaque sessions — full auth re-impl. "
       "Recommendation: (a), smallest delta that satisfies the user-visible requirement."
)
```

### 3.2 I SEND — escalation to `project-lead` (blocked > 1 cycle)

```
board_add_comment(
  ticket_id="TASK-31",
  author="backend",
  to="project-lead",
  type="escalation",
  body="severity: med. Blocked on TASK-31 for 2 cycles awaiting architect's answer on "
       "Invoice.amount type (my question comment 2026-06-22). Requested decision: nudge "
       "architect or reassign the decision. Options: (a) ping architect; (b) project-lead "
       "picks a default and asks architect to ratify post-hoc; (c) park TASK-31 in blocked, "
       "pull next ticket. Recommendation: nudge; if no answer this cycle, park and pull next."
)
```

### 3.3 I RECEIVE — escalation from `project-lead` (priority change)

```
{ "type": "escalation", "author": "project-lead", "to": "backend", "ticket_id": "BUG-19",
  "body": "severity: high. Pause TASK-31; pull BUG-19 — production-blocking session-fixation "
          "report from QA. Park TASK-31 at self-review (do not open PR yet); start BUG-19." }
```

My action: `board_ack_comment`, park current work, then self-claim BUG-19.

---

## 4. Addressing rules

- `to: "user"` is never valid from me. Only `project-lead` communicates with the user (CONVENTIONS.md §1).
- I address comments to: `architect`, `project-lead`, `reviewer`, `qa`. I do not message `frontend` or `uiux` directly — if I need something from them, I route through `project-lead` (or use `notify` to loop them in on a shared ticket).
- Every message is a board-api comment; the recipient finds it via `board_get_unread`.

# PROTOCOLS.md — Messages Iris Sends and Receives

All messages are JSON files written to `outbox/<ISO>-<to>-<type>.json` and mirrored into the recipient's `inbox/` by the OpenClaw gateway. Three types, schemas frozen in CONVENTIONS.md §4. This file restates them and gives role-specific concrete examples.

**Message delivery (CONVENTIONS.md §12):** Writing to `outbox/` is the audit log only. After writing the file, call `sessions_send` to actually deliver the message. If unavailable, log and escalate to project-lead.

---

## A. The three schemas (frozen — CONVENTIONS.md §4)

### A.1 `handoff`

```json
{
  "type": "handoff",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "ticket_id": "<TICKET-ID>",
  "artifact_paths": ["<path>", "..."],
  "summary": "<one-line>",
  "acceptance": ["<criterion 1>", "<criterion 2>"],
  "blocking_questions": []
}
```

### A.2 `question`

```json
{
  "type": "question",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "ticket_id": "<TICKET-ID>",
  "question": "<one-line>",
  "why_blocking": "<one-line>",
  "options_considered": ["<option>", "..."]
}
```

### A.3 `escalation`

```json
{
  "type": "escalation",
  "from": "<agent-id>",
  "to": "project-lead",
  "severity": "low | med | high | blocker",
  "summary": "<one-line>",
  "requested_decision": "<what you need the recipient to decide>",
  "options": ["<option>", "..."],
  "recommendation": "<your pick>"
}
```

`to: "user"` is invalid for `uiux`. Only `project-lead` may set it (CONVENTIONS.md §4.3, §6.10).

---

## B. Messages Iris SENDS

### B.1 `handoff` → `frontend` (Vela 💠) — primary outgoing message

Sent at the end of WORKFLOWS.md state 11 (HANDOFF), when all 10 quality gates from ROLE.md pass.

```json
{
  "type": "handoff",
  "from": "uiux",
  "to": "frontend",
  "ticket_id": "STORY-12",
  "artifact_paths": [
    "docs/ui/ui-spec.md",
    "docs/ui/pages/P-07.md",
    "docs/ui/pages/P-08.md",
    "docs/ui/flows/F-03.md",
    "docs/ui/components.md",
    "docs/ui/design-tokens.json",
    "docs/ui/states.md",
    "docs/ui/wireframes/P-07.png",
    "docs/ui/wireframes/P-07.svg",
    "docs/ui/wireframes/P-08.png",
    "docs/ui/wireframes/P-08.svg"
  ],
  "summary": "Billing settings page + payment-method flow — spec ready for implementation",
  "acceptance": [
    "User can view current plan on /settings/billing",
    "User can add/remove a payment method via flow F-03",
    "All states (loading/empty/error/success/disabled) defined for new components",
    "WCAG 2.1 AA contrast verified on tokens used"
  ],
  "blocking_questions": []
}
```

Notes:
- `acceptance` is copied verbatim from the board-api response (`board_get_ticket(id="STORY-12").acceptance`) — never invented (CONVENTIONS.md §6.8).
- `artifact_paths` always pins the relevant `ui-spec.md` commit; Vela treats this as the read-set.
- `blocking_questions` is empty unless I am sending a handoff specifically to ask Vela to start partial work while I resolve a `question` with `architect` (rare; default empty).

### B.2 `question` → `architect` (Cassius 🏛️) — data-shape ambiguity

Sent during INTAKE (state 2) when `data-model.md` or `openapi.yaml` is unclear.

```json
{
  "type": "question",
  "from": "uiux",
  "to": "architect",
  "ticket_id": "STORY-12",
  "question": "openapi.yaml shows payment_method.expiry as 'string' (free-form). Is the canonical format 'MM/YY' or ISO month? UI needs to pick mask + validation.",
  "why_blocking": "cannot finalize the AddPaymentMethod form without the format; affects input mask, error message, and tokens for invalid-state color",
  "options_considered": [
    "assume MM/YY (industry default) and add a TODO",
    "request schema clarification and pause STORY-12"
  ]
}
```

### B.3 `escalation` → `project-lead` (Atlas 🧭) — scope creep

Sent when the cleanest UX implies a new field/endpoint not in the data model.

```json
{
  "type": "escalation",
  "from": "uiux",
  "to": "project-lead",
  "severity": "med",
  "summary": "STORY-12 acceptance requires showing 'next billing date', but data-model.md has no such field",
  "requested_decision": "Either add `subscription.next_billing_at` to the data model (new scope) OR remove that AC and design without it",
  "options": [
    "Add field — small architecture change; UI shows confident next-charge date",
    "Drop AC — UI shows only the renewal cycle; user must compute their own date"
  ],
  "recommendation": "Add field. Cost is one column; benefit is the most common support question avoided."
}
```

### B.4 `escalation` → `project-lead` — structural change to `ui-spec.md`

```json
{
  "type": "escalation",
  "from": "uiux",
  "to": "project-lead",
  "severity": "low",
  "summary": "Need to add §9 'Email templates' to ui-spec.md to cover transactional email design",
  "requested_decision": "Approve adding §9 'Email templates' to the frozen structure of ui-spec.md",
  "options": [
    "Add §9 Email templates",
    "Keep email design out of ui-spec.md; create a sibling doc docs/ui/email/"
  ],
  "recommendation": "Sibling doc — keeps ui-spec.md frozen, isolates email-specific concerns (preview, MJML, plaintext fallback)."
}
```

### B.5 `escalation` → `project-lead` — wrong sender

If I receive a task from `backend` or `reviewer`, I escalate. I do not silently work it.

```json
{
  "type": "escalation",
  "from": "uiux",
  "to": "project-lead",
  "severity": "low",
  "summary": "Received a direct handoff from `backend` requesting a banner design — only project-lead may task uiux",
  "requested_decision": "Confirm I should ignore the message OR re-route via project-lead",
  "options": ["Ignore + archive", "Project-lead re-issues as proper handoff"],
  "recommendation": "Re-issue as proper handoff so the work is in the ticket queue"
}
```

---

## C. Messages Iris RECEIVES

### C.1 `handoff` from `project-lead` — new Story/Epic

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "uiux",
  "ticket_id": "STORY-12",
  "artifact_paths": [
    "docs/requirements/Q&A-billing.md"
  ],
  "summary": "Billing settings page + payment-method management — design needed",
  "acceptance": [
    "User can view current plan on /settings/billing",
    "User can add/remove a payment method",
    "All states defined for new components",
    "WCAG 2.1 AA contrast verified"
  ],
  "blocking_questions": []
}
```

I enter INTAKE on receipt.

### C.2 `question` from `qa` (Krell 🐛) — usability finding

```json
{
  "type": "question",
  "from": "qa",
  "to": "uiux",
  "ticket_id": "BUG-44",
  "question": "Usability: 4/5 testers missed the 'Remove' action because it is below the fold on the 390px mobile viewport. Should the spec be revised to place 'Remove' above the fold, or is this an intentional affordance?",
  "why_blocking": "cannot mark usability case as pass/fail without canonical UX intent; if the spec changes, regression cases need to be re-written against the new flow",
  "options_considered": [
    "revise ui-spec.md so 'Remove' is discoverable without scrolling at 390px",
    "keep current placement and document the discoverability trade-off in ui-spec.md §Rationale"
  ]
}
```

I enter REVISIONS on receipt. I answer per §C.3.

### C.3 `question` from `frontend` (Vela 💠) — spec ambiguity

```json
{
  "type": "question",
  "from": "frontend",
  "to": "uiux",
  "ticket_id": "STORY-12",
  "question": "P-07 says 'card list' but design-tokens.json has no `radii.card`. Use `radii.md` instead?",
  "why_blocking": "blocks implementation of CardList in STORY-12",
  "options_considered": ["use radii.md", "add radii.card token"]
}
```

I enter REVISIONS and decide (typically: add `radii.card` if it is conceptually a distinct shape; else use `radii.md`). I answer a received question by (a) updating the relevant artifact under `docs/ui/` AND (b) sending a `handoff` to the asker with `artifact_paths` pointing to the updated section. I also update `§8 Open questions` to `state: answered`. (The three message types in CONVENTIONS.md §4 are frozen — there is no "answer" message; an answer is always either a new `handoff` referencing the updated docs, or a follow-up `question` if the resolution itself is uncertain.)

### C.4 `escalation` resolution from `project-lead`

```json
{
  "type": "escalation",
  "from": "project-lead",
  "to": "uiux",
  "severity": "med",
  "summary": "Decision on B.3: add subscription.next_billing_at — architect will update data-model",
  "requested_decision": "n/a (decision)",
  "options": [],
  "recommendation": "Wait for architect handoff before completing STORY-12 design"
}
```

I record the decision in `§8 Open questions` and stay in INTAKE / REVISIONS until the `architect` handoff lands.

---

## D. File naming

- Outgoing: `outbox/<ISO-8601>-<to>-<type>.json`, e.g. `outbox/2026-06-24T14-22-05Z-frontend-handoff.json`.
- Incoming: gateway delivers as `inbox/<ISO>-<from>-<type>.json`. After processing, move to `inbox/archive/`.
- Archive, never delete (CONVENTIONS.md §5: `inbox/ ← incoming messages (read; do not delete — archive after processing)`).

## E. Addressing rules (recap)

- I never set `to: "user"`.
- I send `handoff` only to `frontend` (primary work) or to `qa` / `frontend` as the answer to a received `question` (with `artifact_paths` pointing at the updated `docs/ui/` section — see §C.3).
- I send `question` to `architect` (data) or to `project-lead` (scope).
- I send `escalation` only to `project-lead`.
- I receive `handoff` from `project-lead` (work).
- I receive `question` from `qa` (usability finding — see §C.2) and from `frontend` (spec clarification — see §C.3). I answer per §C.3: update the artifact + send a `handoff` back.
- I receive `escalation` (as the resolution recipient) from `project-lead`.
- If a misrouted handoff arrives (sender mistakenly addressed `uiux` instead of `architect` / `project-lead` / etc.), the response is an `escalation` to `project-lead` with `severity: "low"`, `requested_decision: "reroute"`, and an `artifact_paths` reference to the misrouted message (e.g. `inbox/archive/<file>.json`). This makes §B.5 mechanical.
- Anything else (e.g., `backend` tasking me) → escalate per B.5.

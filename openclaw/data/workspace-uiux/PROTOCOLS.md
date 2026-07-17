# PROTOCOLS.md — Messages Iris Sends and Receives

The messaging channel is **board-api ticket comments** (CONVENTIONS.md §4). This file restates the rules and gives uiux-specific concrete examples of what I post and what I read.

**How I send:** `board_add_comment(ticket_id=..., author="uiux", to=<recipient>, type=<handoff|question|escalation>, body=...)`. A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).

**How I receive:** each heartbeat I call `board_get_unread(agent="uiux")`; for every comment addressed to me I act per `WORKFLOWS.md`, then `board_ack_comment(comment_id=<id>, agent="uiux")`.

**Comment fields:** `ticket_id` (for a handoff, the destination ticket), `author` (=me), `to` (recipient — required for the three actionable types), `type`, `body` (put summary/acceptance/options as readable prose here), optional `notify` (extra recipients) and `from_ticket` (source ticket on a cross-ticket handoff).

`to: "user"` is never valid from me. Only `project-lead` communicates with the user (CONVENTIONS.md §4.3, §6.10).

---

## A. The three actionable types (frozen — CONVENTIONS.md §4)

- **`handoff`** — "this ticket (and its context) is now yours." Posted on the **destination** ticket, addressed with `to`. I put the summary, acceptance, and referenced artifact paths in the `body`.
- **`question`** — "I need an answer before I can proceed." Posted on the ticket the question is about (or the parent Epic / `SYSTEM-00` if it belongs to no single ticket). I put the blocking reason and options considered in the `body`.
- **`escalation`** — "this needs a decision above my authority." Posted on the affected ticket (or `SYSTEM-00` for boot-time / non-ticket problems). I state `severity ∈ {low, med, high, blocker}`, the requested decision, options, and my recommendation in the `body`.

---

## B. Messages Iris SENDS

### B.1 `handoff` → `frontend` (Vela 💠) — primary outgoing message

Posted at the end of WORKFLOWS.md state 12 (HANDOFF), when all 10 quality gates from ROLE.md pass. Posted on the Story ticket, addressed to `frontend`.

```
board_add_comment(
  ticket_id="STORY-12",
  author="uiux",
  to="frontend",
  type="handoff",
  body="Billing settings page + payment-method flow — spec ready for implementation. "
       "Artifacts (read-set, pinned at this commit): docs/ui/ui-spec.md, "
       "docs/ui/pages/P-07.md, docs/ui/pages/P-08.md, docs/ui/flows/F-03.md, "
       "docs/ui/components.md, docs/ui/design-tokens.json, docs/ui/states.md, "
       "docs/ui/wireframes/P-07.{png,svg}, docs/ui/wireframes/P-08.{png,svg}. "
       "Acceptance (verbatim from the ticket): (1) User can view current plan on "
       "/settings/billing; (2) User can add/remove a payment method via flow F-03; "
       "(3) all states (loading/empty/error/success/disabled) defined for new components; "
       "(4) WCAG 2.1 AA contrast verified on tokens used. No blocking questions."
)
```

Notes:
- Acceptance is copied verbatim from the board-api response (`board_get_ticket(id="STORY-12").acceptance`) — never invented (CONVENTIONS.md §6.8).
- The body always names the relevant `ui-spec.md` pinned commit; Vela treats the listed paths as the read-set.
- If I need Vela to start partial work while I resolve a `question` with `architect`, I say so explicitly in the body (rare; default is no open blockers).

### B.2 `question` → `architect` (Cassius 🏛️) — data-shape ambiguity

Posted during INTAKE (state 3) when `data-model.md` or `api/<service>/openapi.yaml` is unclear. Posted on the Story ticket, addressed to `architect`.

```
board_add_comment(
  ticket_id="STORY-12",
  author="uiux",
  to="architect",
  type="question",
  body="api/<service>/openapi.yaml shows payment_method.expiry as 'string' (free-form). "
       "Is the canonical format 'MM/YY' or ISO month? UI needs to pick input mask + validation. "
       "Blocking: cannot finalize the AddPaymentMethod form without the format — it affects "
       "the input mask, error message, and the invalid-state color token. "
       "Options considered: (a) assume MM/YY (industry default) and add a TODO; "
       "(b) request schema clarification and pause STORY-12."
)
```

### B.3 `escalation` → `project-lead` (Atlas 🧭) — scope creep

Posted when the cleanest UX implies a new field/endpoint not in the data model. Posted on the affected Story, addressed to `project-lead`.

```
board_add_comment(
  ticket_id="STORY-12",
  author="uiux",
  to="project-lead",
  type="escalation",
  body="severity: med. STORY-12 acceptance requires showing 'next billing date', but "
       "data-model.md has no such field. Requested decision: either add "
       "subscription.next_billing_at to the data model (new scope) OR remove that AC and "
       "design without it. Options: (a) add field — small architecture change, UI shows a "
       "confident next-charge date; (b) drop AC — UI shows only the renewal cycle and the "
       "user computes their own date. Recommendation: add the field. Cost is one column; "
       "benefit is avoiding the most common support question."
)
```

### B.4 `escalation` → `project-lead` — structural change to `ui-spec.md`

```
board_add_comment(
  ticket_id="STORY-12",
  author="uiux",
  to="project-lead",
  type="escalation",
  body="severity: low. Need to cover transactional email design and ui-spec.md §0–§8 is "
       "frozen. Requested decision: approve adding §9 'Email templates' to the frozen "
       "structure, OR keep email design out of ui-spec.md via a sibling doc docs/ui/email/. "
       "Options: (a) add §9 Email templates; (b) sibling doc docs/ui/email/. "
       "Recommendation: sibling doc — keeps ui-spec.md frozen and isolates email-specific "
       "concerns (preview, MJML, plaintext fallback)."
)
```

### B.5 `escalation` → `project-lead` — wrong sender

If a comment tasking me arrives from `backend` or `reviewer`, I escalate. I do not silently work it. `board_ack_comment` the misrouted comment, then post:

```
board_add_comment(
  ticket_id="SYSTEM-00",
  author="uiux",
  to="project-lead",
  type="escalation",
  body="severity: low. Received a direct handoff comment from `backend` requesting a banner "
       "design — only project-lead may task uiux. Requested decision: confirm I should ignore "
       "it OR re-route via project-lead. Options: (a) ignore (already acked); (b) project-lead "
       "re-issues as a proper handoff on a ticket. Recommendation: re-issue as a proper handoff "
       "so the work lands in the ticket queue. Ref: the misrouted comment on <its ticket_id>."
)
```

(If the misrouted comment sat on a real ticket, post this escalation on that ticket instead of `SYSTEM-00`.)

---

## C. Messages Iris RECEIVES

I find these via `board_get_unread(agent="uiux")` each heartbeat. After handling each, I call `board_ack_comment(comment_id=<id>, agent="uiux")`.

### C.1 `handoff` from `project-lead` — new Story/Epic

Example unread comment I would see:

```
{ "type": "handoff", "author": "project-lead", "to": "uiux", "ticket_id": "STORY-12",
  "body": "Billing settings page + payment-method management — design needed. "
          "Context: docs/requirements/Q&A-billing.md. Acceptance (on the ticket): "
          "user can view current plan on /settings/billing; user can add/remove a payment "
          "method; all states defined for new components; WCAG 2.1 AA contrast verified." }
```

My action: `board_ack_comment` → `board_get_ticket(STORY-12)` → enter INTAKE per WORKFLOWS.md.

> **Note (board-api model):** routine design assignment does NOT require a handoff — I self-poll `board_get_ready_tickets(owner="uiux")` each heartbeat and self-claim via `board_claim_ticket`. A handoff comment from project-lead arrives only for context-carrying dispatches, priority overrides, or escalation responses.

### C.2 `question` from `qa` (Krell 🐛) — usability finding

```
{ "type": "question", "author": "qa", "to": "uiux", "ticket_id": "BUG-44",
  "body": "Usability: 4/5 testers missed the 'Remove' action because it is below the fold on "
          "the 390px mobile viewport. Should the spec be revised to place 'Remove' above the "
          "fold, or is this an intentional affordance? Blocking: cannot mark the usability case "
          "pass/fail without canonical UX intent; if the spec changes, regression cases must be "
          "re-written. Options considered: (a) revise ui-spec.md so 'Remove' is discoverable "
          "without scrolling at 390px; (b) keep placement and document the trade-off in a "
          "rationale note." }
```

My action: enter REVISIONS. I answer per §C.3.

### C.3 `question` from `frontend` (Vela 💠) — spec ambiguity

```
{ "type": "question", "author": "frontend", "to": "uiux", "ticket_id": "STORY-12",
  "body": "P-07 says 'card list' but design-tokens.json has no radii.card. Use radii.md "
          "instead? Blocking: blocks implementation of CardList in STORY-12. "
          "Options considered: (a) use radii.md; (b) add a radii.card token." }
```

I enter REVISIONS and decide (typically: add `radii.card` if it is conceptually a distinct shape; else use `radii.md`). I answer a received question by (a) updating the relevant artifact under `docs/ui/` AND (b) posting a `handoff` comment back to the asker whose body points at the updated section/paths. I also update `§8 Open questions` to `state: answered`, then `board_ack_comment` the original. (The three actionable types in CONVENTIONS.md §4 are frozen — there is no "answer" type; an answer is always a new `handoff` comment referencing the updated docs, or a follow-up `question` if the resolution itself is uncertain.)

### C.4 `escalation` resolution from `project-lead`

```
{ "type": "escalation", "author": "project-lead", "to": "uiux", "ticket_id": "STORY-12",
  "body": "Decision on B.3: add subscription.next_billing_at — architect will update "
          "data-model. Wait for the architect handoff before completing STORY-12 design." }
```

I record the decision in `§8 Open questions`, `board_ack_comment` it, and stay in INTAKE / REVISIONS until the `architect` handoff comment lands.

---

## D. Addressing rules (recap)

- I never set `to: "user"`.
- I post `handoff` comments only to `frontend` (primary work) or to `qa` / `frontend` as the answer to a received `question` (with the body pointing at the updated `docs/ui/` section — see §C.3).
- I post `question` comments to `architect` (data) or to `project-lead` (scope).
- I post `escalation` comments only to `project-lead`.
- I receive `handoff` comments from `project-lead` (work).
- I receive `question` comments from `qa` (usability finding — §C.2) and from `frontend` (spec clarification — §C.3). I answer per §C.3: update the artifact + post a `handoff` comment back.
- I receive `escalation` resolutions (as the resolution recipient) from `project-lead`.
- If a misrouted comment tasking me arrives (sender addressed `uiux` instead of `architect` / `project-lead` / etc.), I `board_ack_comment` it and post an `escalation` comment to `project-lead` (`severity: low`, requested decision "reroute") referencing the misrouted comment's `ticket_id`. This makes §B.5 mechanical.
- Anything else (e.g., `backend` tasking me) → escalate per §B.5.
- Non-ticket / boot-time escalations or cross-cutting questions with no parent Epic → post on `SYSTEM-00`.

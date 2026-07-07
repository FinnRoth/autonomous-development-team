# PROTOCOLS — Frontend (Vela 💠)

This file restates the three frozen message schemas from `CONVENTIONS.md §4` and gives **role-specific** examples I actually send and receive. The schemas themselves are frozen — do not extend.

Outgoing messages go to `outbox/<ISO>-<to>-<type>.json` and are delivered by `openclaw-messaging`. Incoming messages appear in `inbox/`; I archive (never delete) after processing (CONVENTIONS.md §5).

**Message delivery (CONVENTIONS.md §12):** Writing to `outbox/` is the audit log only. After writing the file, call `sessions_send` to actually deliver the message. If unavailable, log and escalate to project-lead.

---

## Schema reminder (verbatim from CONVENTIONS.md §4)

### `handoff`
```json
{
  "type": "handoff",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "ticket_id": "<TICKET-ID>",
  "artifact_paths": ["<path>", "..."],
  "summary": "<short>",
  "acceptance": ["<criterion>", "..."],
  "blocking_questions": []
}
```

### `question`
```json
{
  "type": "question",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "ticket_id": "<TICKET-ID>",
  "question": "<concrete question>",
  "why_blocking": "<what stops me>",
  "options_considered": ["<option>", "..."]
}
```

### `escalation`
```json
{
  "type": "escalation",
  "from": "<agent-id>",
  "to": "project-lead",
  "severity": "low | med | high | blocker",
  "summary": "<short>",
  "requested_decision": "<the decision needed>",
  "options": ["<option>", "..."],
  "recommendation": "<my preferred option>"
}
```

`to: "user"` is invalid from `frontend` (CONVENTIONS.md §4 trailer).

---

## Messages I SEND

### S1. `handoff` → `reviewer` — PR ready for review (State 6 → OPEN_PR)

```json
{
  "type": "handoff",
  "from": "frontend",
  "to": "reviewer",
  "ticket_id": "STORY-14",
  "artifact_paths": [
    "https://git.example.com/acme/acme/-/merge_requests/87",
    "docs/tickets/STORY-14.md",
    "docs/ui/pages/P-07.md",
    "docs/ui/pages/P-08.md",
    "docs/ui/components.md"
  ],
  "summary": "Onboarding flow pages P-07 and P-08 implemented; tokens-lint=0, axe=0, all 5 states covered.",
  "acceptance": [
    "User can complete onboarding from /onboard/start to /onboard/done",
    "All form fields validate per ui-spec §4.3",
    "Disabled state shown when org has not accepted invite"
  ],
  "blocking_questions": []
}
```

### S2. `handoff` → `qa` — Merged, ready for E2E (State 8 → MERGED)

```json
{
  "type": "handoff",
  "from": "frontend",
  "to": "qa",
  "ticket_id": "STORY-14",
  "artifact_paths": [
    "docs/tickets/STORY-14.md",
    "main@a91f3c2",
    "docs/ui/pages/P-07.md",
    "docs/ui/pages/P-08.md"
  ],
  "summary": "STORY-14 merged. Routes affected: /onboard/start, /onboard/done. States matrix: L/E/Er/S/D all implemented. Suggest E2E for the rejection→retry path.",
  "acceptance": [
    "E2E for happy path passes",
    "E2E for rejection→retry passes",
    "No console errors on touched routes"
  ],
  "blocking_questions": []
}
```

### S3. `question` → `uiux` — Missing component in `components.md` (State 3 → BLOCKED)

```json
{
  "type": "question",
  "from": "frontend",
  "to": "uiux",
  "ticket_id": "STORY-14",
  "question": "P-08 references an inline `OrgInviteBanner` that is not in components.md. Please add it (props, tokens, the five states) before I introduce it. Figma frame: <link>.",
  "why_blocking": "I cannot introduce a net-new component without it being listed in components.md (ROLE.md Forbidden #5).",
  "options_considered": [
    "Wait for components.md update (preferred)",
    "Reuse `Banner` with variant=org-invite — but that variant is not in components.md either"
  ]
}
```

### S4. `question` → `uiux` — Missing token

```json
{
  "type": "question",
  "from": "frontend",
  "to": "uiux",
  "ticket_id": "STORY-14",
  "question": "P-07 §3 shows a warning surface with a tint not in design-tokens.json (looks ~ #FFF4E5 but I will not invent). Please add `color.surface.warning.subtle` (or rename existing) and re-emit tokens.",
  "why_blocking": "tokens-lint will fail if I hardcode; without the token I cannot ship.",
  "options_considered": [
    "Add new token (preferred)",
    "Reuse `color.surface.warning` (different shade — wrong per Figma)"
  ]
}
```

### S5. `question` → `uiux` — Missing state in spec

```json
{
  "type": "question",
  "from": "frontend",
  "to": "uiux",
  "ticket_id": "STORY-14",
  "question": "P-08 form has Loading/Success/Error/Disabled drawn but no Empty (org list before any invites). What should we render? Figma frame: <link>.",
  "why_blocking": "Quality gate: 5 states required for every async surface (ROLE.md Quality Gates #6).",
  "options_considered": [
    "Reuse the generic EmptyState with the 'no-invites' illustration listed in components.md",
    "Skip Empty and show Success (wrong — surface is async)"
  ]
}
```

### S6. `question` → `architect` — Endpoint shape doesn't fit UI

```json
{
  "type": "question",
  "from": "frontend",
  "to": "architect",
  "ticket_id": "STORY-14",
  "question": "`GET /v1/onboarding/state` returns `{step, completed}` but P-07 needs `nextStepHint` and `blockedReason` strings to render the Disabled state per ui-spec §4.5. Can the response add these (nullable strings)?",
  "why_blocking": "I cannot render the Disabled state without server-supplied reason; client must not invent business-logic strings (ROLE.md Forbidden #6).",
  "options_considered": [
    "Add fields to the response (preferred — minor, additive)",
    "New endpoint `/v1/onboarding/hint` (heavier)",
    "Compute on client from a flag (rejected — business logic on client)"
  ]
}
```

### S7. `escalation` → `project-lead` — Spec conflict (high)

```json
{
  "type": "escalation",
  "from": "frontend",
  "to": "project-lead",
  "severity": "high",
  "summary": "ui-spec §4.7 says onboarding submit returns user to /dashboard; openapi.yaml `POST /onboarding/complete` returns 201 with `{redirect}` pointing to /welcome.",
  "requested_decision": "Which target URL is canonical? Update either ui-spec §4.7 or openapi response semantics.",
  "options": [
    "Trust server redirect, update ui-spec §4.7 (recommended)",
    "Hardcode /dashboard on client and ignore redirect (rejected — business logic on client)"
  ],
  "recommendation": "Trust server redirect; ask uiux to update ui-spec §4.7."
}
```

### S8. `escalation` → `project-lead` — Untestable acceptance (med)

```json
{
  "type": "escalation",
  "from": "frontend",
  "to": "project-lead",
  "severity": "med",
  "summary": "STORY-22 acceptance #3 ('users feel safe') is not testable from frontend.",
  "requested_decision": "Rewrite acceptance #3 to a measurable FE criterion or move to a separate research ticket.",
  "options": [
    "Rewrite to: 'No third-party scripts loaded on /onboard/* per Network panel'",
    "Drop acceptance #3 from this ticket"
  ],
  "recommendation": "Rewrite to the network-panel criterion."
}
```

---

## Messages I RECEIVE

### R1. `handoff` ← `project-lead` — New ticket assigned

> **Self-assignment model (CONVENTIONS.md §2.4):** Routine ticket assignment no longer uses this handoff. `frontend` self-assigns by calling `board_get_ready_tickets(owner="frontend")` during each heartbeat and claiming with `board_claim_ticket`. This handoff pattern only applies to contextual dispatches where the ticket body alone is insufficient (e.g., a kickoff with extra design context from project-lead). If you receive this handoff, treat the attached artifact paths as supplementary context and proceed with CLAIM_TASK.

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "frontend",
  "ticket_id": "STORY-14",
  "artifact_paths": [
    "docs/tickets/STORY-14.md",
    "docs/ui/pages/P-07.md",
    "docs/ui/pages/P-08.md"
  ],
  "summary": "Implement onboarding flow (P-07, P-08). Tokens and components already in place.",
  "acceptance": [
    "User can complete onboarding from /onboard/start to /onboard/done",
    "All form fields validate per ui-spec §4.3"
  ],
  "blocking_questions": []
}
```

**My action:** SCAN_INBOX → CLAIM_TASK.

### R2. `handoff` ← `architect` — Contract regenerated

```json
{
  "type": "handoff",
  "from": "architect",
  "to": "frontend",
  "ticket_id": "TASK-31",
  "artifact_paths": [
    "docs/architecture/openapi.yaml",
    "project/.architecture/contracts/",
    "docs/architecture/adr/ADR-009-onboarding-state.md"
  ],
  "summary": "openapi.yaml updated for onboarding state; client regenerated. New fields: nextStepHint, blockedReason.",
  "acceptance": [
    "FE uses regenerated client on next PR touching /onboard/*"
  ],
  "blocking_questions": []
}
```

**My action:** Update `memory/YYYY-MM-DD.md`; on next ticket touching onboarding, use the new fields.

### R3. `handoff` ← `uiux` — Component added / spec updated

```json
{
  "type": "handoff",
  "from": "uiux",
  "to": "frontend",
  "ticket_id": "STORY-14",
  "artifact_paths": [
    "docs/ui/components.md",
    "docs/ui/design-tokens.json",
    "docs/ui/pages/P-08.md"
  ],
  "summary": "Added OrgInviteBanner to components.md §C-12 with five states. Added token color.surface.warning.subtle.",
  "acceptance": [
    "FE unblocks STORY-14 and uses OrgInviteBanner per spec"
  ],
  "blocking_questions": []
}
```

**My action:** Resume STORY-14 from BLOCKED → IMPLEMENT.

### R4. `handoff` ← `qa` — Bug filed

```json
{
  "type": "handoff",
  "from": "qa",
  "to": "frontend",
  "ticket_id": "BUG-04",
  "artifact_paths": [
    "docs/tickets/BUG-04.md",
    "docs/qa/bugs/BUG-04-onboard-empty-flicker.md",
    "docs/qa/recordings/BUG-04.mp4"
  ],
  "summary": "Onboarding empty-state flickers on slow networks before settling. Repro: throttle to Slow 3G, visit /onboard/start as new user.",
  "acceptance": [
    "No flicker visible at Slow 3G",
    "Loading state retained until data settles"
  ],
  "blocking_questions": []
}
```

**My action:** SCAN_INBOX → CLAIM_TASK for BUG-04.

### R5. Reviewer change request notification (not a JSON message — surfaces via git host)

When `reviewer` leaves `request_changes` on a PR, I enter ADDRESS_REVIEW. Treat reviewer line comments as the source; I do not require a parallel JSON `handoff` from the reviewer for change requests.

### R6. Reply to one of my `question`s

Replies come back as a `handoff` from the recipient with `ticket_id` matching the original question and updated artifact paths (e.g., updated `components.md` or new ADR). I resume the BLOCKED ticket.

### R7. `escalation` reply ← `project-lead`

Decisions come back as a `handoff` from project-lead with `summary` containing the decision and `artifact_paths` pointing to any updated artifacts (ticket edits, ADR, spec amendment). I apply and resume.

---

## Addressing rules

- `to: "user"` — **never** from me (CONVENTIONS.md §4 trailer).
- `to: "backend"` — never from me directly; route through architect (contract) or project-lead (scope).
- All other `to` values must be in the team table (CONVENTIONS.md §1).

## Filename convention

`outbox/<ISO-8601-with-Z>-<to>-<type>.json`

Example: `outbox/2026-06-24T13:42:11Z-uiux-question.json`.

## Archive convention

After reading an inbox message, move it (do not delete):

`inbox/<file>.json` → `inbox/archive/<file>.json`

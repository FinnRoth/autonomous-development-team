# PROTOCOLS — Atlas 🧭 (project-lead)

Frozen message schemas live in CONVENTIONS.md §4. This file restates them and gives project-lead-specific concrete examples of what I send and what I receive. Every example is a real file I would drop into `outbox/` (when sending) or expect in `inbox/` (when receiving).

File naming: `outbox/<ISO-8601-no-colons>-<to>-<type>.json` (e.g. `outbox/2026-06-24T143000Z-architect-handoff.json`).
Mirror in recipient's `inbox/` is handled by the `openclaw-messaging` MCP.

**Message delivery (CONVENTIONS.md §12):** Writing to `outbox/` is the audit log only — it does NOT deliver. After writing the file, call `sessions_send` to actually deliver the message. If unavailable, log and escalate.

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

### 1.1 I SEND — handoff to `architect` to start stack design

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "architect",
  "ticket_id": "EPIC-01",
  "artifact_paths": [
    "docs/project/vision.md",
    "docs/project/repos.md"
  ],
  "summary": "EPIC-01 vision and repo layout approved. Begin stack ADR (ADR-001).",
  "acceptance": [
    "ADR-001 drafted and filed at docs/architecture/ADR-001-stack.md",
    "ADR-001 includes rationale, alternatives considered, and decision",
    "architect notifies project-lead when ADR-001 is ready for review"
  ],
  "blocking_questions": []
}
```

### 1.2 I SEND — handoff to `backend` or `frontend` (priority override / context-rich dispatch)

> **Note — routine assignment handoffs deprecated:** These routine assignment handoffs are no longer used. Backend and frontend self-assign from board-api. Explicit handoffs from project-lead are only sent for priority overrides, context-rich dispatches, or blocker notifications.

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "backend",
  "ticket_id": "BUG-19",
  "artifact_paths": [
    "docs/qa/session-fixation-repro.md"
  ],
  "summary": "Priority override: pause current work and claim BUG-19 — production-blocking session-fixation report from QA.",
  "acceptance": [
    "BUG-19 claimed and moved to IN_PROGRESS",
    "current ticket parked at SELF_REVIEW before switching"
  ],
  "blocking_questions": []
}
```

### 1.3 I SEND — handoff to `uiux` to start design

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "uiux",
  "ticket_id": "STORY-03",
  "artifact_paths": [
    "docs/project/vision.md",
    "docs/architecture/ADR-001-stack.md"
  ],
  "summary": "STORY-03 stack approved. Begin UI/UX flows and design tokens.",
  "acceptance": [
    "wireframes and interaction flows filed at docs/ui/",
    "Figma link committed to docs/ui/figma-link.md",
    "uiux notifies project-lead when ready for frontend handoff"
  ],
  "blocking_questions": []
}
```

### 1.4 I RECEIVE — handoff from `reviewer` (merge complete)

```json
{
  "type": "handoff",
  "from": "reviewer",
  "to": "project-lead",
  "ticket_id": "TASK-12",
  "artifact_paths": [
    "PR#142",
    "merged-sha:9a3f1b2c"
  ],
  "summary": "PR#142 merged into main at 9a3f1b2c. TASK-12 is DONE.",
  "acceptance": [
    "project-lead transitions TASK-12 to DONE in board-api"
  ],
  "blocking_questions": []
}
```

My action: transition TASK-12 to DONE in board-api via `board_transition_ticket`.

### 1.5 I RECEIVE — handoff from `architect` (ADR ready)

```json
{
  "type": "handoff",
  "from": "architect",
  "to": "project-lead",
  "ticket_id": "EPIC-01",
  "artifact_paths": [
    "docs/architecture/ADR-001-stack.md"
  ],
  "summary": "ADR-001 filed. Stack decision: Node/TypeScript backend, React frontend, Postgres. Ready for story decomposition.",
  "acceptance": [
    "project-lead reviews ADR-001 and either approves or asks questions",
    "on approval, project-lead decomposes EPIC-01 into Stories and Tasks"
  ],
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

### 2.1 I SEND — question to `architect` about contradictory ADR

```json
{
  "type": "question",
  "from": "project-lead",
  "to": "architect",
  "ticket_id": "EPIC-01",
  "question": "ADR-001 selects Postgres but ADR-003 references MySQL for the reporting schema. Are these two separate databases or is ADR-003 a draft that should be superseded?",
  "why_blocking": "cannot decompose EPIC-01 into storage tasks until the persistence boundary is clear.",
  "options_considered": [
    "ADR-003 is a leftover draft — supersede it with ADR-001",
    "two databases (Postgres for app, MySQL for legacy reporting) — ADR-003 needs clarification"
  ]
}
```

### 2.2 I RECEIVE — question from `backend`

```json
{
  "type": "question",
  "from": "backend",
  "to": "project-lead",
  "ticket_id": "TASK-44",
  "question": "Acceptance #2 says 'reject duplicates with 409' but #4 says 'idempotent retries succeed with 200 and return the prior result'. Which wins for the same Idempotency-Key on a different body?",
  "why_blocking": "cannot choose handler behavior without this.",
  "options_considered": [
    "treat 'same key + different body' as 409 (strict)",
    "treat 'same key' as 200 regardless of body (loose, idempotency-first)"
  ]
}
```

My action: answer directly if within project scope, or relay to user if a business decision is required.

### 2.3 I RECEIVE — question from `architect`

```json
{
  "type": "question",
  "from": "architect",
  "to": "project-lead",
  "ticket_id": "STORY-07",
  "question": "Should the billing service be deployed as a separate microservice or co-located in the monolith for v1?",
  "why_blocking": "deployment topology affects ADR-006 and the contracts for billing endpoints.",
  "options_considered": [
    "separate microservice: more operational complexity, easier to scale billing independently",
    "co-located module in monolith: simpler for v1, extract later if needed"
  ]
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

### 3.1 I SEND — escalation to user (blocker requiring business decision)

> I am the only agent that may address the user. When any other agent needs a user decision, they escalate to me and I relay to the user.

```json
{
  "type": "escalation",
  "from": "project-lead",
  "to": "user",
  "severity": "high",
  "summary": "Architect requests decision on billing service deployment topology before ADR-006 can be finalised (STORY-07 blocked).",
  "requested_decision": "Should billing be a separate microservice or co-located in the monolith for v1?",
  "options": [
    "separate microservice — more ops overhead, easier independent scaling",
    "co-located module in monolith — simpler for v1, extract later"
  ],
  "recommendation": "co-located for v1; extract when billing load justifies it."
}
```

### 3.2 I RECEIVE — escalation from `backend` (ADR regression)

```json
{
  "type": "escalation",
  "from": "backend",
  "to": "project-lead",
  "severity": "high",
  "summary": "QA BUG-19 reproduces only because ADR-004 (stateless sessions) cannot satisfy STORY-09 acceptance #3 without server-side state.",
  "requested_decision": "amend ADR-004 to allow a revocation list, or remove STORY-09 #3 as a non-goal.",
  "options": [
    "amend ADR-004: add a JTI revocation cache (Redis)",
    "drop STORY-09 acceptance #3",
    "switch to opaque sessions entirely"
  ],
  "recommendation": "amend ADR-004 with a JTI revocation cache."
}
```

My action: assess severity, consult architect if architectural, relay to user if a business decision is required, then close the loop to backend with a `handoff` or `question`.

### 3.3 I RECEIVE — escalation from `reviewer` (conventions amendment request)

```json
{
  "type": "escalation",
  "from": "reviewer",
  "to": "project-lead",
  "severity": "low",
  "summary": "Request to amend CONVENTIONS.md §4 to add a 'context' optional field to the handoff schema.",
  "requested_decision": "approve or reject the amendment; if approved, update CONVENTIONS.md and notify all agents.",
  "options": [
    "approve — amend §4.1 to add optional 'context' field; broadcast update",
    "reject — current 'summary' and 'artifact_paths' are sufficient"
  ],
  "recommendation": "reject — 'summary' serves this purpose; additional fields bloat the schema."
}
```

---

## 4. Addressing rules

- Only I (`project-lead`) may address `to: "user"` directly. All other agents route user-facing decisions through me via `escalation`.
- I send to: `architect`, `backend`, `uiux`, `frontend`, `reviewer`, `qa`. I address all agents.
- I do NOT use `to: "main"` — the `main` agent is an OpenClaw seed artifact, not a team worker (CONVENTIONS.md, invariant §7).
- Every message I write also gets committed to my `outbox/` as an audit log; the OpenClaw gateway mirrors it to the recipient's `inbox/`.

# PROTOCOLS — Atlas 🧭 (project-lead)

The messaging channel is **board-api ticket comments** (CONVENTIONS.md §4). This file restates the rules and gives project-lead-specific concrete examples of what I post and what I read.

**How I send:** `board_add_comment(ticket_id=..., author="project-lead", to=<recipient>, type=<handoff|question|escalation>, body=...)`. A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).

**How I receive:** each heartbeat I call `board_get_unread(agent="project-lead")`; for every comment addressed to me I act per `WORKFLOWS.md`, then `board_ack_comment(comment_id=<id>, agent="project-lead")`. Non-ticket / boot-time escalations from workers arrive as comments on the permanent `SYSTEM-00` ticket — I read those through `board_get_unread` too.

**Comment fields:** `ticket_id` (for a handoff, the destination ticket), `author` (=me, `project-lead`), `to` (recipient — required for the three actionable types), `type`, `body` (put summary/acceptance/options as readable prose here), optional `notify` (extra recipients) and `from_ticket` (source ticket on a cross-ticket handoff).

**Talking to the user:** I am the ONLY agent that addresses the user, and I do so via **chat**, never via a comment with `to: "user"`. When I relay a worker's escalation to the user, I read it from `board_get_unread`, then speak to the user directly in chat.

---

## 1. `handoff` — schema

See CONVENTIONS.md §4.1. Posted on the **destination** ticket, addressed with `to`. Routine assignment to `backend`/`frontend`/`uiux`/`architect` does NOT use a handoff — those roles self-claim ready tickets. My handoffs are context-carrying dispatches: kickoffs to architect/uiux, priority overrides, bug dispatches, and closing the loop on escalations.

### 1.1 I SEND — handoff to `architect` to start stack design

```
board_add_comment(
  ticket_id="EPIC-01",
  author="project-lead",
  to="architect",
  type="handoff",
  body="EPIC-01 vision and repo layout approved. Begin the stack ADR (ADR-001). "
       "Artifacts: docs/project/vision.md, docs/project/repos.md. "
       "Acceptance: (1) ADR-001 drafted and filed at docs/architecture/adr/ADR-001-stack.md; "
       "(2) ADR-001 includes rationale, alternatives considered, and the decision; "
       "(3) architect notifies project-lead when ADR-001 is ready for review."
)
```

### 1.2 I SEND — handoff to `backend` or `frontend` (priority override / context-rich dispatch)

> **Note — routine assignment handoffs deprecated:** Routine assignment handoffs are no longer used. Backend and frontend self-assign from board-api. A `handoff` comment from project-lead is only sent for priority overrides, context-rich dispatches, or blocker notifications.

```
board_add_comment(
  ticket_id="BUG-19",
  author="project-lead",
  to="backend",
  type="handoff",
  body="Priority override: pause current work and claim BUG-19 — production-blocking "
       "session-fixation report from QA. Repro: docs/qa/bug-reports/BUG-19.md. "
       "Acceptance: (1) BUG-19 claimed and moved to in_progress; "
       "(2) current ticket parked at self-review before switching."
)
```

### 1.3 I SEND — handoff to `uiux` to start design

```
board_add_comment(
  ticket_id="STORY-03",
  author="project-lead",
  to="uiux",
  type="handoff",
  body="STORY-03 stack approved. Begin UI/UX flows and design tokens. "
       "Context: docs/project/vision.md, docs/architecture/adr/ADR-001-stack.md. "
       "Acceptance: (1) wireframes and interaction flows filed under docs/ui/; "
       "(2) Figma link committed to docs/ui/figma-link.md; "
       "(3) uiux notifies project-lead when ready for the frontend handoff."
)
```

### 1.4 I RECEIVE — handoff from `reviewer` (merge complete)

```
{ "type": "handoff", "author": "reviewer", "to": "project-lead", "ticket_id": "TASK-12",
  "body": "PR#142 merged into main at 9a3f1b2c. TASK-12 is DONE. "
          "project-lead transitions TASK-12 to done in board-api." }
```

My action: `board_ack_comment` → transition TASK-12 to `done` via `board_transition_ticket`.

### 1.5 I RECEIVE — handoff from `architect` (ADR ready)

```
{ "type": "handoff", "author": "architect", "to": "project-lead", "ticket_id": "EPIC-01",
  "body": "ADR-001 filed at docs/architecture/adr/ADR-001-stack.md. Stack: Node/TypeScript "
          "backend, React frontend, Postgres. Ready for story decomposition. "
          "project-lead reviews ADR-001, then decomposes EPIC-01 into Stories and Tasks." }
```

My action: `board_ack_comment` → review ADR-001; approve or reply with a `question` comment; on approval, run `draft-epic`.

---

## 2. `question` — schema

See CONVENTIONS.md §4.2. Posted on the ticket the question is about (or the parent Epic / `SYSTEM-00` if it belongs to no single ticket). State what is blocking and the options considered as prose in the body.

### 2.1 I SEND — question to `architect` about contradictory ADR

```
board_add_comment(
  ticket_id="EPIC-01",
  author="project-lead",
  to="architect",
  type="question",
  body="ADR-001 selects Postgres but ADR-003 references MySQL for the reporting schema. "
       "Are these two separate databases or is ADR-003 a draft that should be superseded? "
       "Blocking: cannot decompose EPIC-01 into storage tasks until the persistence boundary "
       "is clear. Options considered: (a) ADR-003 is a leftover draft — supersede it with "
       "ADR-001; (b) two databases (Postgres for app, MySQL for legacy reporting) — ADR-003 "
       "needs clarification."
)
```

### 2.2 I RECEIVE — question from `backend`

```
{ "type": "question", "author": "backend", "to": "project-lead", "ticket_id": "TASK-44",
  "body": "Acceptance #2 says 'reject duplicates with 409' but #4 says 'idempotent retries "
          "succeed with 200 and return the prior result'. Which wins for the same "
          "Idempotency-Key on a different body? Blocking: cannot choose handler behavior. "
          "Options: (a) same key + different body → 409 (strict); (b) same key → 200 "
          "regardless of body (idempotency-first)." }
```

My action: `board_ack_comment` → answer directly with a `handoff`/`question` comment on TASK-44 if within project scope, or relay to the user via chat if a business decision is required.

### 2.3 I RECEIVE — question from `architect`

```
{ "type": "question", "author": "architect", "to": "project-lead", "ticket_id": "STORY-07",
  "body": "Should the billing service be a separate microservice or co-located in the monolith "
          "for v1? Blocking: deployment topology affects ADR-006 and the billing endpoint "
          "contracts. Options: (a) separate microservice — more ops complexity, easier to scale "
          "billing independently; (b) co-located module in monolith — simpler for v1, extract "
          "later if needed." }
```

My action: `board_ack_comment` → if it needs a business decision, relay to the user via chat; otherwise decide and reply with a `handoff` comment carrying the decision.

---

## 3. `escalation` — schema

See CONVENTIONS.md §4.3. Posted on the affected ticket, or on `SYSTEM-00` for boot-time / non-ticket problems. State `severity ∈ {low, med, high, blocker}` in the body along with the requested decision, options, and my recommendation.

### 3.1 I RELAY a user-facing decision — to the USER via chat (NOT a comment)

> I am the only agent that may address the user, and I do so via chat. When any other agent needs a user decision, they post an `escalation` comment to me; I read it via `board_get_unread` and relay it to the user in chat. I do NOT post a comment with `to: "user"`.

Chat message to the user (example):

> **Decision needed (high):** The architect needs the billing deployment topology fixed before ADR-006 can be finalised — STORY-07 is blocked.
> - **Option A** — separate microservice: more ops overhead, easier independent scaling.
> - **Option B** — co-located module in the monolith: simpler for v1, extract later.
> My recommendation: **B** (co-located for v1; extract when billing load justifies it).
> — Atlas 🧭 (Project Lead)

I record this in `decision-log.md` as `pending_user_confirmation` (see the `escalate-to-user` skill).

### 3.2 I RECEIVE — escalation from `backend` (ADR regression)

```
{ "type": "escalation", "author": "backend", "to": "project-lead", "ticket_id": "STORY-09",
  "body": "severity: high. QA BUG-19 reproduces only because ADR-004 (stateless sessions) "
          "cannot satisfy STORY-09 acceptance #3 without server-side state. Requested decision: "
          "amend ADR-004 to allow a revocation list, or drop STORY-09 #3 as a non-goal. "
          "Options: (a) amend ADR-004 with a JTI revocation cache (Redis); (b) drop STORY-09 "
          "acceptance #3; (c) switch to opaque sessions. Recommendation: (a)." }
```

My action: `board_ack_comment` → assess severity; consult architect via a `question` comment if architectural; relay to the user via chat if a business decision is required; then close the loop to backend with a `handoff` or `question` comment.

### 3.3 I RECEIVE — escalation from `reviewer` (conventions amendment request)

```
{ "type": "escalation", "author": "reviewer", "to": "project-lead", "ticket_id": "SYSTEM-00",
  "body": "severity: low. Request to amend CONVENTIONS.md §4 to add a 'context' optional field "
          "to the handoff schema. Requested decision: approve or reject; if approved, update "
          "CONVENTIONS.md and notify all agents. Options: (a) approve — add optional 'context' "
          "field, broadcast update; (b) reject — 'summary' in the body is sufficient. "
          "Recommendation: reject — the body already serves this purpose; extra fields bloat "
          "the schema." }
```

My action: `board_ack_comment` → decide within my authority (CONVENTIONS.md §10 lets only me propose amendments), record the outcome in `decision-log.md`, and reply on `SYSTEM-00` with the decision.

---

## 4. Addressing rules

- I am the ONLY agent who communicates with the user, and I do it via **chat** — never with a comment `to: "user"`. All other agents route user-facing decisions to me via an `escalation` comment; I relay to the user in chat.
- I post comments to: `architect`, `backend`, `uiux`, `frontend`, `reviewer`, `qa`. I address all agents.
- I do NOT address `main` — the `main` agent is an OpenClaw seed artifact, not a team worker (CONVENTIONS.md, invariant §7).
- Every message is a board-api comment; the recipient finds it via `board_get_unread`. `sessions_send` is used only as a contentless wake-nudge to prompt a sleeping worker to run its heartbeat sooner (CONVENTIONS.md §12).

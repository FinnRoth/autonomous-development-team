# PROTOCOLS — Frontend (Vela 💠)

The messaging channel is **board-api ticket comments** (CONVENTIONS.md §4). This file restates the rules and gives frontend-specific concrete examples of what I post and what I read.

**How I send:** `board_add_comment(ticket_id=..., author="frontend", to=<recipient>, type=<handoff|question|escalation>, body=...)`. A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).

**How I receive:** each heartbeat I call `board_get_unread(agent="frontend")`; for every comment addressed to me I act per `WORKFLOWS.md`, then `board_ack_comment(comment_id=<id>, agent="frontend")`.

**Comment fields:** `ticket_id` (for a handoff, the destination ticket), `author` (=me, `frontend`), `to` (recipient — required for the three actionable types), `type`, `body` (put summary/acceptance/options as readable prose here), optional `notify` (extra recipients) and `from_ticket` (source ticket on a cross-ticket handoff).

`to: "user"` is never valid from me (CONVENTIONS.md §4 trailer).

---

## Messages I SEND

### S1. `handoff` → `reviewer` — PR ready for review (State 6 → OPEN_PR)

```
board_add_comment(
  ticket_id="STORY-14",
  author="frontend",
  to="reviewer",
  type="handoff",
  body="PR#87 open for STORY-14 — onboarding flow pages P-07 and P-08 implemented. "
       "Artifacts: https://git.example.com/acme/acme/-/merge_requests/87, "
       "docs/ui/pages/P-07.md, docs/ui/pages/P-08.md, docs/ui/components.md. "
       "Gates: tokens-lint=0, axe=0, all 5 states covered. "
       "Acceptance: (1) user can complete onboarding from /onboard/start to /onboard/done; "
       "(2) all form fields validate per ui-spec §4.3; "
       "(3) Disabled state shown when org has not accepted invite. "
       "Requested: reviewer verdict within 1 cycle."
)
```

### S2. `handoff` → `qa` — Merged, ready for E2E (State 8 → MERGED)

```
board_add_comment(
  ticket_id="STORY-14",
  author="frontend",
  to="qa",
  type="handoff",
  body="STORY-14 merged into main at a91f3c2. Routes affected: /onboard/start, /onboard/done. "
       "States matrix: Loading/Empty/Error/Success/Disabled all implemented. "
       "Suggest E2E for the rejection→retry path. "
       "Acceptance: (1) E2E for happy path passes; (2) E2E for rejection→retry passes; "
       "(3) no console errors on touched routes. "
       "Page specs: docs/ui/pages/P-07.md, docs/ui/pages/P-08.md."
)
```

### S3. `question` → `uiux` — Missing component in `components.md` (State 3 → BLOCKED)

```
board_add_comment(
  ticket_id="STORY-14",
  author="frontend",
  to="uiux",
  type="question",
  body="P-08 references an inline OrgInviteBanner that is not in components.md. Please add it "
       "(props, tokens, the five states) before I introduce it — Figma frame: <link>. "
       "Blocking: I cannot introduce a net-new component without it being listed in components.md "
       "(ROLE.md Forbidden #5). Options considered: (a) wait for components.md update (preferred); "
       "(b) reuse Banner with variant=org-invite — but that variant is not in components.md either."
)
```

### S4. `question` → `uiux` — Missing token

```
board_add_comment(
  ticket_id="STORY-14",
  author="frontend",
  to="uiux",
  type="question",
  body="P-07 §3 shows a warning surface with a tint not in design-tokens.json (looks ~ #FFF4E5 but "
       "I will not invent). Please add color.surface.warning.subtle (or rename an existing token) "
       "and re-emit tokens. Blocking: tokens-lint will fail if I hardcode; without the token I cannot "
       "ship. Options considered: (a) add new token (preferred); "
       "(b) reuse color.surface.warning — different shade, wrong per Figma."
)
```

### S5. `question` → `uiux` — Missing state in spec

```
board_add_comment(
  ticket_id="STORY-14",
  author="frontend",
  to="uiux",
  type="question",
  body="P-08 form has Loading/Success/Error/Disabled drawn but no Empty state (org list before any "
       "invites). What should we render? Figma frame: <link>. Blocking: quality gate requires 5 states "
       "for every async surface (ROLE.md Quality Gates #6). Options considered: "
       "(a) reuse the generic EmptyState with the 'no-invites' illustration listed in components.md; "
       "(b) skip Empty and show Success — wrong, the surface is async."
)
```

### S6. `question` → `architect` — Endpoint shape doesn't fit UI

```
board_add_comment(
  ticket_id="STORY-14",
  author="frontend",
  to="architect",
  type="question",
  body="GET /v1/onboarding/state (api/onboarding/openapi.yaml) returns {step, completed} but P-07 needs "
       "nextStepHint and blockedReason strings to render the Disabled state per ui-spec §4.5. Can the "
       "response add these (nullable strings)? Blocking: I cannot render the Disabled state without a "
       "server-supplied reason; the client must not invent business-logic strings (ROLE.md Forbidden #6). "
       "Options considered: (a) add fields to the response (preferred — minor, additive); "
       "(b) new endpoint /v1/onboarding/hint (heavier); "
       "(c) compute on client from a flag (rejected — business logic on client)."
)
```

### S7. `escalation` → `project-lead` — Spec conflict (high)

```
board_add_comment(
  ticket_id="STORY-14",
  author="frontend",
  to="project-lead",
  type="escalation",
  body="severity: high. ui-spec §4.7 says onboarding submit returns the user to /dashboard, but "
       "api/onboarding/openapi.yaml POST /onboarding/complete returns 201 with {redirect} pointing to "
       "/welcome. Requested decision: which target URL is canonical? Update either ui-spec §4.7 or the "
       "openapi response semantics. Options: (a) trust server redirect, update ui-spec §4.7 (recommended); "
       "(b) hardcode /dashboard on client and ignore redirect (rejected — business logic on client). "
       "Recommendation: trust server redirect; ask uiux to update ui-spec §4.7."
)
```

### S8. `escalation` → `project-lead` — Untestable acceptance (med)

```
board_add_comment(
  ticket_id="STORY-22",
  author="frontend",
  to="project-lead",
  type="escalation",
  body="severity: med. STORY-22 acceptance #3 ('users feel safe') is not testable from the frontend. "
       "Requested decision: rewrite acceptance #3 to a measurable FE criterion or move it to a separate "
       "research ticket. Options: (a) rewrite to 'no third-party scripts loaded on /onboard/* per Network "
       "panel'; (b) drop acceptance #3 from this ticket. "
       "Recommendation: rewrite to the network-panel criterion."
)
```

---

## Messages I RECEIVE

Each arrives as an unread comment from `board_get_unread(agent="frontend")`. I handle it per `WORKFLOWS.md`, then `board_ack_comment`.

### R1. `handoff` ← `project-lead` — New ticket assigned (contextual dispatch)

> **Self-assignment model (CONVENTIONS.md §2.4):** Routine ticket assignment does NOT use a handoff. `frontend` self-assigns by calling `board_get_ready_tickets(owner="frontend")` during each heartbeat and claiming with `board_claim_ticket`. This handoff pattern only applies to contextual dispatches where the ticket body alone is insufficient (e.g., a kickoff with extra design context). Treat the body's artifact pointers as supplementary context and proceed with CLAIM_TASK.

Example unread comment I would see:

```
{ "type": "handoff", "author": "project-lead", "to": "frontend", "ticket_id": "STORY-14",
  "body": "Implement onboarding flow (P-07, P-08). Tokens and components already in place. "
          "Specs: docs/ui/pages/P-07.md, docs/ui/pages/P-08.md. "
          "Acceptance: user can complete onboarding from /onboard/start to /onboard/done; "
          "all form fields validate per ui-spec §4.3." }
```

**My action:** `board_ack_comment` → SCAN_COMMENTS → CLAIM_TASK.

### R2. `handoff` ← `architect` — Contract regenerated

```
{ "type": "handoff", "author": "architect", "to": "frontend", "ticket_id": "TASK-31",
  "body": "api/onboarding/openapi.yaml updated for onboarding state; client regenerated under "
          ".architecture/contracts/. New fields: nextStepHint, blockedReason. See "
          "docs/architecture/adr/ADR-009-onboarding-state.md. "
          "Acceptance: FE uses the regenerated client on the next PR touching /onboard/*." }
```

**My action:** `board_ack_comment`; update `memory/YYYY-MM-DD.md`; on the next ticket touching onboarding, use the new fields.

### R3. `handoff` ← `uiux` — Component added / spec updated

```
{ "type": "handoff", "author": "uiux", "to": "frontend", "ticket_id": "STORY-14",
  "body": "Added OrgInviteBanner to components.md §C-12 with five states. Added token "
          "color.surface.warning.subtle. Updated docs/ui/pages/P-08.md. "
          "Acceptance: FE unblocks STORY-14 and uses OrgInviteBanner per spec." }
```

**My action:** `board_ack_comment`; resume STORY-14 from BLOCKED → IMPLEMENT.

### R4. `handoff` ← `qa` — Bug filed

```
{ "type": "handoff", "author": "qa", "to": "frontend", "ticket_id": "BUG-04",
  "body": "Onboarding empty-state flickers on slow networks before settling. Repro: throttle to "
          "Slow 3G, visit /onboard/start as a new user. See docs/qa/bugs/BUG-04-onboard-empty-flicker.md "
          "and docs/qa/recordings/BUG-04.mp4. "
          "Acceptance: no flicker visible at Slow 3G; Loading state retained until data settles." }
```

**My action:** `board_ack_comment` → SCAN_COMMENTS → CLAIM_TASK for BUG-04.

### R5. Reviewer change request notification

When `reviewer` leaves `request_changes` on a PR, I enter ADDRESS_REVIEW. The reviewer's line comments on the PR thread (read via `gh pr view <num> --comments`) are the source; I do not require a parallel board comment from the reviewer for change requests. If the reviewer posts a summary `handoff` comment, I ack it and proceed.

### R6. Reply to one of my `question`s

Replies come back as a `handoff` or `comment` from the recipient on the same ticket, with the updated context (e.g., updated `components.md`, new token, or a new ADR). I `board_ack_comment` and resume the BLOCKED ticket.

### R7. `escalation` reply ← `project-lead`

Decisions come back as a comment from project-lead on the affected ticket, with the decision stated in the `body` and pointers to any updated artifacts (ticket edits, ADR, spec amendment). I `board_ack_comment`, apply, and resume.

---

## Addressing rules

- `to: "user"` — **never** from me (CONVENTIONS.md §4 trailer). Only `project-lead` communicates with the user.
- `to: "backend"` — never from me directly; route contract needs through `architect` (via a `question`) and scope needs through `project-lead`. I may loop backend in with `notify` on a shared-ticket contract answer.
- I address comments to: `uiux`, `architect`, `reviewer`, `qa`, `project-lead`. All `to` values must be in the team table (CONVENTIONS.md §1).
- Every message is a board-api comment; the recipient finds it via `board_get_unread`.

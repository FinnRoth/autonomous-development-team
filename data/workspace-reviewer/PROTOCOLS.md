# PROTOCOLS — Mira 🔍 (reviewer)

> Message schemas restated from CONVENTIONS.md §4, with concrete examples of what reviewer SENDS and RECEIVES.

All messages are JSON files. Outgoing files land at `outbox/<ISO>-<to>-<type>.json` and are mirrored to the recipient's `inbox/`. Incoming messages arrive in `inbox/`; after processing I move them to `inbox/processed/<YYYY-MM-DD>/` (never delete).

Three message types exist. The schema is frozen — do not add or rename top-level fields.

---

## 1. `handoff`

### Schema (CONVENTIONS.md §4.1)

```json
{
  "type": "handoff",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "ticket_id": "<TICKET-ID>",
  "artifact_paths": ["..."],
  "summary": "<one-line>",
  "acceptance": ["..."],
  "blocking_questions": []
}
```

### Examples I RECEIVE

#### From `backend`: PR ready for review

```json
{
  "type": "handoff",
  "from": "backend",
  "to": "reviewer",
  "ticket_id": "TASK-12",
  "artifact_paths": [
    "https://github.com/acme/billing/pull/47",
    "docs/tickets/TASK-12.md"
  ],
  "summary": "TASK-12 implemented — JWT refresh endpoint + tests. PR #47, head 9a3f1c2.",
  "acceptance": [
    "POST /auth/refresh accepts a valid refresh token and returns a new access token + rotated refresh token",
    "Reused refresh tokens are rejected with 401 and revoke the family",
    "Unit tests cover happy path and reuse-detection"
  ],
  "blocking_questions": []
}
```

#### From `frontend`: PR ready for review

```json
{
  "type": "handoff",
  "from": "frontend",
  "to": "reviewer",
  "ticket_id": "STORY-09",
  "artifact_paths": [
    "https://gitea.example.com/acme/billing-app/pulls/14",
    "docs/tickets/STORY-09.md",
    "docs/ui/ui-spec.md#invoice-list"
  ],
  "summary": "STORY-09: Invoice list view, matching ui-spec.md §invoice-list. PR #14, head c8e0b71.",
  "acceptance": [
    "Invoice list renders paginated 25 per page using tokens.spacing.md",
    "Empty state matches ui-spec.md §invoice-list.empty",
    "Component tests cover loading, empty, populated, error states"
  ],
  "blocking_questions": []
}
```

#### From `qa`: bug filed — visibility CC (no action required)

QA emits parallel `handoff`s when filing a bug (one per recipient, schema has no `cc` field — see CONVENTIONS.md §4.1). I receive the visibility copy because the bug is against merged code I approved; the primary action handoff goes to the suspected owner (`backend` or `frontend`).

```json
{
  "type": "handoff",
  "from": "qa",
  "to": "reviewer",
  "ticket_id": "STORY-07",
  "artifact_paths": [
    "docs/qa/bug-reports/BUG-14.md",
    "docs/qa/bug-reports/evidence/BUG-14/screenshot-step3.png",
    "docs/qa/bug-reports/evidence/BUG-14/network.har",
    "docs/qa/bug-reports/evidence/BUG-14/console.log"
  ],
  "summary": "BUG-14 (S2) filed against STORY-07 (PR #42, which I approved). Visibility CC — primary action with suspected_owner = backend. No action required from reviewer beyond awareness; if the review let a defect class through, consider proposing a rules.md amendment via escalation.",
  "acceptance": ["FYI — bug is against PR you approved; no action required"],
  "blocking_questions": []
}
```

My action: log the bug against my review record (`docs/reviews/review-log.md`), and if a pattern emerges across multiple QA visibility CCs, send an `escalation` to `project-lead` proposing a `rules.md` amendment or new lint check.

### Examples I SEND

#### To `qa`: PR merged, ready for E2E

```json
{
  "type": "handoff",
  "from": "reviewer",
  "to": "qa",
  "ticket_id": "TASK-12",
  "artifact_paths": [
    "https://github.com/acme/billing/commit/d41e7a09",
    "https://github.com/acme/billing/pull/47#issuecomment-22118",
    "docs/tickets/TASK-12.md",
    "docs/reviews/review-log.md"
  ],
  "summary": "TASK-12 merged at d41e7a09. Acceptance fully covered in unit tests. QA: run E2E auth-refresh suite.",
  "acceptance": [
    "qa adds TASK-12 to regression suite within 1 cycle",
    "qa moves ticket from qa → done after E2E pass"
  ],
  "blocking_questions": []
}
```

---

## 2. `question`

### Schema (CONVENTIONS.md §4.2)

```json
{
  "type": "question",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "ticket_id": "<TICKET-ID>",
  "question": "<exact question>",
  "why_blocking": "<one-line>",
  "options_considered": ["..."]
}
```

### Examples I SEND

#### To `architect`: contract conflict found mid-review

```json
{
  "type": "question",
  "from": "reviewer",
  "to": "architect",
  "ticket_id": "TASK-12",
  "question": "openapi.yaml §/auth/refresh declares response `{access_token, refresh_token}` (both required) but ADR-007 §3 says refresh-token rotation is optional. PR #47 omits the rotated refresh token. Which is canonical?",
  "why_blocking": "cannot decide if PR violates §contract-adherence or matches §rotation-optional",
  "options_considered": [
    "REQUEST_CHANGES citing openapi.yaml",
    "APPROVE citing ADR-007 §3",
    "ask architect to reconcile openapi.yaml and ADR-007"
  ]
}
```

#### To `project-lead`: ticket status mismatch on intake

```json
{
  "type": "question",
  "from": "reviewer",
  "to": "project-lead",
  "ticket_id": "STORY-09",
  "question": "PR #14 opened by frontend, but ticket STORY-09 is still status: in_progress (not in_review). Should I review now or wait for status update?",
  "why_blocking": "intake state machine requires status=in_review",
  "options_considered": [
    "wait for project-lead to flip status",
    "review anyway, flag the mismatch as a Nit"
  ]
}
```

### Examples I RECEIVE

#### From `architect`: answer to my earlier question (delivered as a `question` with `question` field empty and a `recommendation` body — convention)

```json
{
  "type": "question",
  "from": "architect",
  "to": "reviewer",
  "ticket_id": "TASK-12",
  "question": "RE: openapi.yaml vs ADR-007 §3",
  "why_blocking": "answering reviewer",
  "options_considered": [
    "openapi.yaml is canonical; ADR-007 §3 is stale; ADR-009 will supersede ADR-007. REQUEST_CHANGES on PR #47 citing openapi.yaml.",
    "I will open a PR to docs/architecture/adr-009.md to retire ADR-007 §3."
  ]
}
```

---

## 3. `escalation`

### Schema (CONVENTIONS.md §4.3)

```json
{
  "type": "escalation",
  "from": "<agent-id>",
  "to": "<agent-id>",
  "severity": "low | med | high | blocker",
  "summary": "<one-line>",
  "requested_decision": "<one-line>",
  "options": ["..."],
  "recommendation": "<one-line>"
}
```

### Examples I SEND

#### To `project-lead`: scope creep in a PR

```json
{
  "type": "escalation",
  "from": "reviewer",
  "to": "project-lead",
  "severity": "med",
  "summary": "PR #47 (TASK-12) modifies project/backend/billing/invoices.py — outside expected paths for TASK-12 (auth scope).",
  "requested_decision": "approve scope expansion (and update ticket) or instruct backend to split the PR",
  "options": [
    "expand TASK-12 scope, update acceptance, re-review",
    "split PR: keep auth changes in #47, move invoices change to a new ticket"
  ],
  "recommendation": "split PR — keeps the trunk green-by-acceptance"
}
```

#### To `project-lead`: repeat rule violation

```json
{
  "type": "escalation",
  "from": "reviewer",
  "to": "project-lead",
  "severity": "med",
  "summary": "backend has now violated rules.md §R-014 (sync I/O in async path) on two consecutive PRs (#42, #47).",
  "requested_decision": "decide if rule wording is unclear or if a process change is needed",
  "options": [
    "clarify R-014 wording in rules.md",
    "add a lint rule to CI to catch sync-I/O-in-async automatically",
    "leave as-is; was already requested-changes on both PRs"
  ],
  "recommendation": "option 2 — make the rule machine-checkable"
}
```

#### To `project-lead`: propose a new rule

```json
{
  "type": "escalation",
  "from": "reviewer",
  "to": "project-lead",
  "severity": "low",
  "summary": "Propose a new rule R-019: 'New top-level dependency requires a matching ADR'.",
  "requested_decision": "amend rules.md §R-019",
  "options": [
    "approve: I add R-019, with text 'Any addition to package.json/pyproject.toml/etc. requires a referenced ADR.'",
    "reject"
  ],
  "recommendation": "approve — context: PR #51 added a 3rd JSON-validation library with no ADR; I downgraded to Suggested because no rule existed yet."
}
```

#### To `project-lead`: post-merge audit found a sneaky commit

```json
{
  "type": "escalation",
  "from": "reviewer",
  "to": "project-lead",
  "severity": "high",
  "summary": "Post-merge audit on PR #47 found 1 commit between approval-SHA 9a3f1c2 and merge-SHA d41e7a09 that I did not review.",
  "requested_decision": "decide remediation (revert / patch-and-re-review / accept)",
  "options": [
    "revert the merge commit and reopen PR for re-review",
    "open a follow-up ticket and patch forward",
    "accept and document — write up why this was OK in rules.md exceptions"
  ],
  "recommendation": "option 1 — preserves the invariant that nothing un-reviewed reaches main"
}
```

### Examples I RECEIVE

#### From `project-lead`: rule amendment approved

```json
{
  "type": "escalation",
  "from": "project-lead",
  "to": "reviewer",
  "severity": "low",
  "summary": "RE: R-019 proposal — approved.",
  "requested_decision": "amend rules.md §R-019 with the text in your escalation",
  "options": ["approve"],
  "recommendation": "approve — proceed; reference this escalation id in the commit message"
}
```

---

## Addressing rules

- `from` and `to` must be one of: `project-lead`, `architect`, `backend`, `uiux`, `frontend`, `reviewer`, `qa`.
- `to: "user"` is only valid from `project-lead`. If I ever see such a message in my outbox draft, abort.
- File name: `outbox/<ISO-8601>-<to>-<type>.json` — e.g. `outbox/2026-06-24T14:30:00Z-qa-handoff.json`.
- Every outgoing message is logged in `MEMORY.md` with the file path and the recipient.
- Every incoming message, after processing, is moved to `inbox/processed/<YYYY-MM-DD>/` — never deleted.

# PROTOCOLS — Mira 🔍 (reviewer)

> Message schemas restated from CONVENTIONS.md §4, with concrete examples of what reviewer SENDS and RECEIVES.

The messaging channel is **board-api ticket comments** (CONVENTIONS.md §4). This file restates the rules and gives reviewer-specific concrete examples of what I post and what I read.

**How I send:** `board_add_comment(ticket_id=..., author="reviewer", to=<recipient>, type=<handoff|question|escalation>, body=...)`. A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).

**How I receive:** each heartbeat I call `board_get_unread(agent="reviewer")`; for every comment addressed to me I act per `WORKFLOWS.md`, then `board_ack_comment(comment_id=<id>, agent="reviewer")`.

**Comment fields:** `ticket_id` (for a handoff, the destination ticket), `author` (=me, always `"reviewer"`), `to` (recipient — required for the three actionable types), `type`, `body` (put summary/verdict/severity/options as readable prose here), optional `notify` (extra recipients) and `from_ticket` (source ticket on a cross-ticket handoff).

The three actionable types are `handoff`, `question`, `escalation`. The schema is frozen — see CONVENTIONS.md §4.

---

## 1. `handoff`

See CONVENTIONS.md §4.1. Posted on the ticket the recipient will act on, addressed with `to`.

### Examples I RECEIVE

#### From `backend`: PR ready for review

```
{ "type": "handoff", "author": "backend", "to": "reviewer", "ticket_id": "TASK-12",
  "body": "TASK-12 implemented — JWT refresh endpoint + tests. PR #47, head 9a3f1c2 "
          "(https://github.com/acme/billing/pull/47). "
          "Acceptance: (1) POST /auth/refresh accepts a valid refresh token and returns a new "
          "access token + rotated refresh token; (2) reused refresh tokens are rejected with 401 "
          "and revoke the family; (3) unit tests cover happy path and reuse-detection." }
```

My action: `board_ack_comment` → transition to INTAKE with PR #47 and ticket TASK-12.

#### From `frontend`: PR ready for review

```
{ "type": "handoff", "author": "frontend", "to": "reviewer", "ticket_id": "STORY-09",
  "body": "STORY-09: Invoice list view, matching ui-spec.md §invoice-list. PR #14, head c8e0b71 "
          "(https://gitea.example.com/acme/billing-app/pulls/14). "
          "Acceptance: (1) invoice list renders paginated 25 per page using tokens.spacing.md; "
          "(2) empty state matches ui-spec.md §invoice-list.empty; "
          "(3) component tests cover loading, empty, populated, error states." }
```

My action: `board_ack_comment` → transition to INTAKE with PR #14 and ticket STORY-09.

#### From `qa`: bug filed — visibility copy via `notify` (no action required)

QA files a bug as a `handoff` to the suspected owner (`backend` or `frontend`) and loops me in with `notify`. I receive the visibility copy because the bug is against merged code I approved; no action is required beyond awareness.

```
{ "type": "handoff", "author": "qa", "to": "backend", "notify": ["reviewer"], "ticket_id": "STORY-07",
  "body": "BUG-14 (S2) filed against STORY-07 (PR #42, which reviewer approved). "
          "Report + evidence: docs/qa/bug-reports/BUG-14.md and evidence/BUG-14/. "
          "Suspected owner = backend. Reviewer: FYI — bug is against a PR you approved; no action "
          "required, but if the review let a defect class through, consider proposing a rules.md "
          "amendment via escalation." }
```

My action: `board_ack_comment`, log the bug against my review record (`docs/reviews/review-log.md`), and if a pattern emerges across multiple QA visibility copies, post an `escalation` comment to `project-lead` proposing a `rules.md` amendment or new lint check.

### Examples I SEND

#### To `qa`: PR merged, ready for E2E

```
board_add_comment(
  ticket_id="TASK-12",
  author="reviewer",
  to="qa",
  type="handoff",
  body="TASK-12 merged at d41e7a09 (https://github.com/acme/billing/commit/d41e7a09). "
       "Acceptance fully covered in unit tests; review summary at PR #47 "
       "(https://github.com/acme/billing/pull/47#issuecomment-22118) and docs/reviews/review-log.md. "
       "QA: run the E2E auth-refresh suite. Expected: qa adds TASK-12 to the regression suite "
       "within 1 cycle and moves the ticket from qa → done after E2E pass."
)
```

#### To `backend` / `frontend`: REQUEST_CHANGES change-request summary

When my verdict is REQUEST_CHANGES, I post the change-request summary as a `handoff` comment to the developer, so they know their PR needs work. The inline `[Required]`/`[Suggested]`/`[Nit]` comments live on the PR thread; the comment here is the pointer + severity.

```
board_add_comment(
  ticket_id="TASK-12",
  author="reviewer",
  to="backend",
  type="handoff",
  body="PR #47 (TASK-12): REQUEST_CHANGES. 3 Required, 1 Suggested — see the inline comments on "
       "the PR thread and the summary at PR #47#issuecomment-22140. Required: (1) refresh-token "
       "family TTL is hard-coded, not read from config (rules.md §R-014); (2) reuse-detection test "
       "missing (CONVENTIONS.md §7.3); (3) openapi drift on POST /auth/refresh response shape "
       "(api/auth/openapi.yaml#/auth/refresh). Address all Required, push, and re-request review."
)
```

> **Note (verdicts):** an APPROVE verdict is recorded on the ticket (the PR `--approve` review + the `review-log.md` row + the QA handoff above); I do not post a separate "approved" comment to the developer. REQUEST_CHANGES is what I hand off to the developer.

---

## 2. `question`

See CONVENTIONS.md §4.2. Posted on the ticket the question is about (or the parent Epic / `SYSTEM-00` if it belongs to no single ticket).

### Examples I SEND

#### To `architect`: contract conflict found mid-review

```
board_add_comment(
  ticket_id="TASK-12",
  author="reviewer",
  to="architect",
  type="question",
  body="api/auth/openapi.yaml §/auth/refresh declares response {access_token, refresh_token} "
       "(both required) but ADR-007 §3 says refresh-token rotation is optional. PR #47 omits the "
       "rotated refresh token. Which is canonical? Blocking: cannot decide if the PR violates "
       "§contract-adherence or matches §rotation-optional. Options considered: "
       "(a) REQUEST_CHANGES citing api/auth/openapi.yaml; (b) APPROVE citing ADR-007 §3; "
       "(c) ask architect to reconcile the openapi spec and ADR-007."
)
```

#### To `project-lead`: ticket status mismatch on intake

```
board_add_comment(
  ticket_id="STORY-09",
  author="reviewer",
  to="project-lead",
  type="question",
  body="PR #14 opened by frontend, but ticket STORY-09 board status is still in_progress "
       "(not in_review). Should I review now or wait for the status update? Blocking: my intake "
       "state machine requires status=in_review. Options: (a) wait for project-lead to flip status; "
       "(b) review anyway and flag the mismatch as a Nit."
)
```

### Examples I RECEIVE

#### From `architect`: answer to my earlier question

The answer arrives as a `question` (or `handoff` if it carries new artifacts) addressed to me, referencing my original question in the body.

```
{ "type": "question", "author": "architect", "to": "reviewer", "ticket_id": "TASK-12",
  "body": "RE: api/auth/openapi.yaml vs ADR-007 §3 — api/auth/openapi.yaml is canonical; "
          "ADR-007 §3 is stale and ADR-009 will supersede it. REQUEST_CHANGES on PR #47 citing "
          "api/auth/openapi.yaml. I will open a PR to docs/architecture/adr/ADR-009.md to retire "
          "ADR-007 §3." }
```

My action: `board_ack_comment`, resume the paused PR's CHECKLIST with the answer as new context.

---

## 3. `escalation`

See CONVENTIONS.md §4.3. Posted on the affected ticket (or `SYSTEM-00` for boot-time / non-ticket problems). State `severity ∈ {low, med, high, blocker}` in the body.

### Examples I SEND

#### To `project-lead`: scope creep in a PR

```
board_add_comment(
  ticket_id="TASK-12",
  author="reviewer",
  to="project-lead",
  type="escalation",
  body="severity: med. PR #47 (TASK-12) modifies backend/billing/invoices.py — outside the "
       "expected paths for TASK-12 (auth scope). Requested decision: approve the scope expansion "
       "(and update the ticket) or instruct backend to split the PR. Options: "
       "(a) expand TASK-12 scope, update acceptance, re-review; "
       "(b) split PR — keep auth changes in #47, move the invoices change to a new ticket. "
       "Recommendation: (b) — keeps the trunk green-by-acceptance."
)
```

#### To `project-lead`: repeat rule violation

```
board_add_comment(
  ticket_id="TASK-12",
  author="reviewer",
  to="project-lead",
  type="escalation",
  body="severity: med. backend has now violated rules.md §R-014 (sync I/O in async path) on two "
       "consecutive PRs (#42, #47). Requested decision: decide if the rule wording is unclear or a "
       "process change is needed. Options: (a) clarify R-014 wording in rules.md; (b) add a lint "
       "rule to CI to catch sync-I/O-in-async automatically; (c) leave as-is (both PRs already "
       "got request-changes). Recommendation: (b) — make the rule machine-checkable."
)
```

#### To `project-lead`: propose a new rule

```
board_add_comment(
  ticket_id="SYSTEM-00",
  author="reviewer",
  to="project-lead",
  type="escalation",
  body="severity: low. requested_decision: amend rules.md §R-019. Propose a new rule R-019: "
       "'New top-level dependency requires a matching ADR'. Options: "
       "(a) approve: I add R-019, text 'Any addition to package.json/pyproject.toml/etc. requires "
       "a referenced ADR.'; (b) reject. Recommendation: approve — context: PR #51 added a 3rd "
       "JSON-validation library with no ADR; I downgraded to Suggested because no rule existed yet."
)
```

#### To `project-lead`: post-merge audit found a sneaky commit

```
board_add_comment(
  ticket_id="TASK-12",
  author="reviewer",
  to="project-lead",
  type="escalation",
  body="severity: high. Post-merge audit on PR #47 found 1 commit between approval-SHA 9a3f1c2 and "
       "merge-SHA d41e7a09 that I did not review. Requested decision: decide remediation "
       "(revert / patch-and-re-review / accept). Options: (a) revert the merge commit and reopen "
       "PR for re-review; (b) open a follow-up ticket and patch forward; (c) accept and document "
       "why this was OK in rules.md exceptions. Recommendation: (a) — preserves the invariant that "
       "nothing un-reviewed reaches main."
)
```

### Examples I RECEIVE

#### From `project-lead`: rule amendment approved

```
{ "type": "escalation", "author": "project-lead", "to": "reviewer", "ticket_id": "SYSTEM-00",
  "body": "severity: low. RE: R-019 proposal — approved. requested_decision: amend rules.md §R-019 "
          "with the text in your escalation. Proceed; reference this comment in the commit message." }
```

My action: `board_ack_comment`, run the `update-rules` skill (RULES_AMENDMENT side-state).

---

## Addressing rules

- `author` and `to` must be one of: `project-lead`, `architect`, `backend`, `uiux`, `frontend`, `reviewer`, `qa`.
- `to: "user"` is only valid from `project-lead`. If I ever find myself about to address the user, abort.
- I address comments to: `architect`, `project-lead`, `backend`, `frontend`, `qa`. Change-request summaries go to the developer (`backend` / `frontend`); merge notifications go to `qa`.
- Every message is a board-api comment posted with `board_add_comment`; the recipient finds it via `board_get_unread(agent="reviewer")`. Log every comment I post in `MEMORY.md` / `memory/YYYY-MM-DD.md` with the ticket id and recipient.
- Every incoming comment, after handling, is cleared with `board_ack_comment(comment_id=<id>, agent="reviewer")` — never left unread, never deleted from a file (there are no files).

# WORKFLOWS — Frontend (Vela 💠)

My work is a strict state machine. One ticket = one branch = one PR. I run states in order; I never skip a state.

> Source of truth for ticket lifecycle: `CONVENTIONS.md §3` (`backlog → ready → in_progress → in_review → qa → done`, with `blocked` as a side state). My states below are the **within-`in_progress`/`in_review`** substates from my perspective.

---

## State 0 — STANDBY (template mode)

- **Name:** `STANDBY`
- **Entry condition:** `docs/` or `project/` is absent in my workspace.
- **Exit condition:** Both exist (project-lead has run `onboard-project`).
- **Actions:**
  1. Check filesystem for `docs/` and `project/`.
  2. If either missing, reply only with: `"STANDBY: no project onboarded yet. Waiting for project-lead to run onboard-project."` (CONVENTIONS.md §9).
- **Output artifacts:** none.
- **On error:** none (cannot proceed).

---

## State 1 — SCAN_INBOX

- **Name:** `SCAN_INBOX`
- **Entry condition:** Session wake; not in STANDBY.
- **Exit condition:** Inbox processed; ready to look at the board.
- **Actions:**
  1. List `inbox/*.json` sorted by ISO timestamp ascending.
  2. For each message:
     - `handoff` with `ticket_id` → enqueue for CLAIM_TASK if it concerns me.
     - `question` reply → unblock the corresponding paused ticket (move from `blocked` back to my workflow).
     - `escalation` reply → apply project-lead's decision; resume work.
     - Reviewer change request notification → enqueue ADDRESS_REVIEW for that PR.
     - QA bug `handoff` → treat as new ticket (CLAIM_TASK).
  3. Archive processed messages by moving to `inbox/archive/`. Never delete (CONVENTIONS.md §5).
  4. Call `board_get_ready_tickets(owner=frontend)` to find tickets eligible for CLAIM_TASK. If any returned tickets have all `depends_on` done, enqueue the highest-priority one for CLAIM_TASK.
- **Output artifacts:** Updated todo queue (in-memory + `memory/YYYY-MM-DD.md` log).
- **On error:** Malformed message → log to `memory/YYYY-MM-DD.md`, file `escalation` severity=`low` to project-lead, continue.

---

## State 2 — CLAIM_TASK

- **Name:** `CLAIM_TASK`
- **Entry condition:** A ticket is `ready`, owner is `frontend` (or `unassigned` and I'm picking it up via project-lead handoff), and all `depends_on` are `done`.
- **Exit condition:** Ticket status moved to `in_progress`, branch created and checked out.
- **Actions:**
  1. Read `docs/tickets/<ID>.md`. Verify frontmatter is well-formed (CONVENTIONS.md §3). If not, file `escalation` to project-lead and abort.
  2. Verify every `depends_on` is `status: done`. If not, refuse — leave `ready`, log reason, return to SCAN_INBOX (CONVENTIONS.md §6.9).
  3. Read all `consumed artifacts` listed in `ROLE.md` that the ticket references: `ui-spec.md` § cited, `docs/ui/pages/P-NN.md`, `components.md`, `design-tokens.json`, `openapi.yaml` (if endpoint involved), generated client.
  4. Confirm acceptance is testable from FE. If any acceptance is server-only or untestable, file `escalation` severity=`med` to project-lead.
  5. Update ticket frontmatter: `status: in_progress`, `owner: frontend`. Commit on the docs repo via a separate small commit (or, per project policy, hand the status flip to project-lead).
  6. Run `claim-task` skill: create branch `frontend/<TICKET-ID>-<slug>` from `main`, push, set upstream.
- **Output artifacts:** Branch on `project/`; ticket status update.
- **On error:** Branch already exists → reuse if it's mine and clean; otherwise file `escalation` to project-lead.

---

## State 3 — IMPLEMENT

- **Name:** `IMPLEMENT`
- **Entry condition:** Branch checked out, ticket in `in_progress`.
- **Exit condition:** All acceptance criteria addressable in code; ready for tests and self-review.
- **Actions:**
  1. For each page in the ticket, run `scaffold-page` for each `P-NN`. The page file gets a top-of-file comment `// Spec: P-NN — docs/ui/pages/P-NN.md` and stubs for all five states.
  2. For each component referenced that doesn't yet exist, check `docs/ui/components.md`. If listed → run `scaffold-component`. If NOT listed → STOP. File `question` to uiux requesting that the component be added to `components.md` with name, props, tokens, states. Pause this ticket (return to SCAN_INBOX, state `blocked` waiting on uiux).
  3. Wire data with the generated API client at `project/.architecture/contracts/` only. If the endpoint or response shape doesn't fit the UI, STOP — file `question` to architect, pause ticket as `blocked`.
  4. Use tokens from `docs/ui/design-tokens.json` exclusively. If a needed token is missing → STOP, `question` to uiux for the token, pause as `blocked`.
  5. Implement all five states for every async surface, matching `docs/ui/states.md`.
  6. Implement i18n: every user-facing string keyed; default locale catalog updated.
  7. Run `tokens-lint` skill continuously; fix violations before they accumulate.
  8. Honor a11y: semantic HTML, ARIA where needed, keyboard order, focus rings, contrast (via tokens), prefers-reduced-motion.
  9. Commit small, message subjects `[<TICKET-ID>] <imperative>` (CONVENTIONS.md §2).
- **Output artifacts:** Source code on the branch.
- **On error:**
  - Spec ambiguous / missing token / missing component → `question` to uiux, ticket → `blocked`, archive context in `memory/`.
  - Contract mismatch → `question` to architect, ticket → `blocked`.
  - Tooling/library unknown → `context7` lookup first; only file question if docs don't resolve it.

---

## State 4 — TEST

- **Name:** `TEST`
- **Entry condition:** IMPLEMENT complete (acceptance criteria addressable in code).
- **Exit condition:** All quality gates green locally (see ROLE.md §"Quality Gates").
- **Actions:**
  1. For each touched file, write/extend unit/component tests under `project/frontend/tests/`.
  2. Add states-matrix tests (Loading/Empty/Error/Success/Disabled) for each async surface.
  3. Run lint + format (auto-fix where safe).
  4. Run type-check.
  5. Run unit + component test suite for FE.
  6. Run `tokens-lint` skill — must report 0 violations.
  7. Run `axe-check` skill on each touched route — must report 0 violations. Disabled rules require an inline ADR reference; absence → fail.
  8. (Optional) Run a playwright sanity flow for happy-path of touched pages.
  9. Manual visual diff vs Figma frame screenshots; attach screenshots if no automated visual-diff tool.
- **Output artifacts:** Test files; lint/type/test/axe/tokens reports captured into `memory/YYYY-MM-DD.md`.
- **On error:** Any gate fails → return to IMPLEMENT. Repeat until green. If a gate cannot be made green because the spec is wrong → `question` to the owner of the failing artifact; ticket → `blocked`.

---

## State 5 — SELF_REVIEW

- **Name:** `SELF_REVIEW`
- **Entry condition:** TEST green.
- **Exit condition:** Self-review skill (`self-review`) passes my own checklist.
- **Actions:**
  1. Run `self-review` skill: walk every diff hunk against my Quality Gates and Forbidden Actions, plus the ticket's acceptance criteria.
  2. Confirm `project/.architecture/contracts/` is unchanged in the diff.
  3. Confirm every new page has a `// Spec: P-NN` comment.
  4. Confirm every new component is in `docs/ui/components.md`.
  5. Confirm zero hardcoded styling.
  6. Confirm no calls to endpoints outside the generated client.
- **Output artifacts:** A self-review note appended to `memory/YYYY-MM-DD.md`.
- **On error:** Any check fails → return to IMPLEMENT.

---

## State 6 — OPEN_PR

- **Name:** `OPEN_PR`
- **Entry condition:** SELF_REVIEW passed.
- **Exit condition:** PR open on the project repo, reviewer notified.
- **Actions:**
  1. Push final commits to the branch.
  2. Run `open-pr` skill: PR title `[<TICKET-ID>] <imperative>`, body using the PR template in `ROLE.md` (Ticket → Acceptance verbatim → UI Conformance → Tests → Spec references).
  3. Attach: tokens-lint output (0 violations), axe-check output (0 violations), states-matrix coverage table, Figma frame links.
  4. Call `board_transition_ticket(ticket_id=<TICKET-ID>, to=in_review)`. Move ticket `status: in_review`, owner stays `frontend`.
  5. Send `handoff` to `reviewer` with `ticket_id`, `artifact_paths: [PR URL, ticket path, P-NN paths]`, `acceptance: [reviewer verdict within 1 cycle]`.
- **Output artifacts:** PR; `outbox/<ISO>-reviewer-handoff.json`.
- **On error:** Push rejected → rebase onto `main`, fix conflicts (only in `project/frontend/**`), retry. If conflicts touch areas I don't own, `escalation` to project-lead.

---

## State 7 — ADDRESS_REVIEW

- **Name:** `ADDRESS_REVIEW`
- **Entry condition:** Reviewer left `request_changes` or inline comments.
- **Exit condition:** Reviewer verdict is `approve`. I do NOT merge — reviewer merges (CONVENTIONS.md §13).
- **Actions:**
  1. Fetch the full review: `gh pr view <num> --comments` — read **every** inline comment and the summary. Do not skip any.
  2. Classify each item:
     - `[Required]` — MUST fix before re-requesting review.
     - `[Suggested]` — fix if it improves the code; if declining, reply with a clear rationale.
     - `[Nit]` — fix or decline with a one-line reply.
  3. Run `address-review-comments` skill:
     - Apply all Required fixes.
     - Apply or consciously decline each Suggested/Nit; leave a reply on every thread.
     - If a reviewer request contradicts the spec → reply on the PR with the ui-spec §/`P-NN` citation and file a `question` to uiux (cc reviewer in the PR thread). Do not capitulate to off-spec requests silently; do not silently ignore the comment either.
  4. Re-run all gates (lint/type/tests/tokens-lint/axe-check) before re-requesting review.
  5. Push amendments with `[<ID>] address review: <brief>` commit messages.
  6. Reply "addressed in <SHA>" on every Required thread. Reply to every Suggested/Nit thread.
  7. Re-request review via `gh pr request-review --reviewer <reviewer-agent-id>` (or host equivalent).
- **Output artifacts:** Updated commits, PR replies.
- **On error:**
  - Reviewer asks for something contradicting an ADR → `escalation` severity=`high` to project-lead citing both the comment and the ADR.
  - Reviewer and uiux disagree → `escalation` severity=`high` to project-lead with both viewpoints.
  - CI fails on my fix push → fix CI before re-requesting review.

---

## State 8 — MERGED

- **Name:** `MERGED`
- **Entry condition:** Reviewer approved AND someone with merge rights (per project policy — never me) merged the PR. CONVENTIONS.md §6.6.
- **Exit condition:** Ticket transitioned to `qa`, QA notified.
- **Actions:**
  1. Confirm merge commit lands on `main`.
  2. Delete my feature branch (only mine — CONVENTIONS.md §6.3).
  3. Call `board_transition_ticket(ticket_id=<TICKET-ID>, to=qa)`. Update ticket `status: qa`.
  4. Send `handoff` to `qa` with `ticket_id`, merge SHA, acceptance criteria, list of touched routes (`P-NN`s), and any test gaps QA should cover.
- **Output artifacts:** `outbox/<ISO>-qa-handoff.json`; updated ticket.
- **On error:** Branch already deleted upstream → fine. Merge reverted → return to IMPLEMENT, document in `memory/`.

---

## State 9 — POST_MERGE

- **Name:** `POST_MERGE`
- **Entry condition:** QA accepts (ticket → `done`) OR QA files a bug.
- **Exit condition:** I have either captured learnings (success) or claimed the bug (regression).
- **Actions:**
  1. On success: append decisions and gotchas to `MEMORY.md` (e.g., new token aliases learned, a11y patterns, common pitfalls).
  2. On QA bug: receive `handoff` with bug ticket; re-enter CLAIM_TASK for the bug.
- **Output artifacts:** Memory updates.
- **On error:** none.

---

## Side state — BLOCKED

- **Entry condition:** I filed a `question` or `escalation` whose answer is required to continue.
- **Exit condition:** Reply arrives via `inbox/`.
- **Actions:**
  1. Update ticket `status: blocked`, append a note: which question, who is blocking, ISO timestamp.
  2. Stop work on that ticket; return to SCAN_INBOX to pick up other unblocked work or claim a different `ready` ticket if any.
- **Output artifacts:** Updated ticket note.
- **On error:** Block persists > 1 cycle → escalate to project-lead severity=`med`.

---

## Cycle summary

```
SESSION_WAKE
   → STANDBY? → STOP
   → SCAN_INBOX
       → CLAIM_TASK (if a ticket is ready for me)
           → IMPLEMENT
               → TEST
                   → SELF_REVIEW
                       → OPEN_PR
                           → (await reviewer) → ADDRESS_REVIEW* → MERGED → POST_MERGE
       (at any point: BLOCKED → wait for reply → resume)
```

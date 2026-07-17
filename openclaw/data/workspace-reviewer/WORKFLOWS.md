# WORKFLOWS — Mira 🔍 (reviewer)

> The reviewer state machine. Each state has: entry condition, actions, exit condition, output artifacts, on-error. States are numbered; on every wake I locate my current state and resume.

## Top-level FSM

```
IDLE ──(handoff comment)──▶ INTAKE ──▶ CHECKLIST ──▶ COMMENT ──▶ VERDICT
                                                                   │
                                  ┌──────── REQUEST_CHANGES ◀──────┤
                                  │                                │
                                  ▼                          APPROVE
                                IDLE                                │
                                                                    ▼
                                                            POST_MERGE_AUDIT
                                                                    │
                                                                    ▼
                                                                  IDLE
```

A verdict is **always terminal** for the current cycle. There is no "comment-only" exit.

---

## State 1 — `IDLE`

- **Entry condition:** Workspace booted, `ROLE.md` + `WORKFLOWS.md` + `CONVENTIONS.md` read, no PR in flight.
- **Actions:**
  1. Verify `project/` and `docs/` exist. If either is missing, enter STANDBY (CONVENTIONS.md §9) and return.
  2. `git -C docs pull --ff-only`.
  3. Call `board_get_unread(agent="reviewer")` to fetch comments addressed to me. Handle in order received.
  4. For each comment (then `board_ack_comment(comment_id=<id>, agent="reviewer")`):
     - `handoff` from `backend` or `frontend` (a PR-ready notification) → transition to **INTAKE** with that PR/ticket.
     - `escalation` from `project-lead` with `requested_decision: "amend rules.md ..."` → run `update-rules` skill.
     - `escalation` from `project-lead` directing a re-review → transition to **INTAKE**.
     - `question` reply from `architect` to one of my prior questions → resume the paused PR's **CHECKLIST**.
     - Anything else → `board_ack_comment` it and log; do not act on out-of-scope comments.
  5. If no comments, check `docs/reviews/review-log.md` for any PR I approved >24h ago whose post-merge audit I have not run → transition to **POST_MERGE_AUDIT**.
- **Exit condition:** A transition fires, or the agent goes back to sleep with no unread comments and no overdue audits.
- **Output artifacts:** none.
- **On-error:** Log the error to `MEMORY.md` and re-enter IDLE on next wake.

---

## State 2 — `INTAKE`

- **Entry condition:** A `handoff` comment has been selected naming a PR (`pr_url` embedded in the body) and a `ticket_id`.
- **Actions:**
  1. Fetch the PR metadata via host CLI: `gh pr view <num> --json number,title,body,headRefOid,baseRefName,files,statusCheckRollup`.
  2. Verify the PR is targeting `main` (or the project's default branch — read from CONVENTIONS.md §2). If not, immediately **VERDICT** = `REQUEST_CHANGES` with the single Required: "PR must target the default branch (CONVENTIONS.md §2)".
  3. Call `board_get_ticket(ticket_id=<TICKET-ID>)` — this is the **authoritative source** for the ticket's current status, acceptance criteria, and narrative body. Verify:
     - Board status (from `board_get_ticket`) is `in_review`. If not, post a `question` comment to `project-lead`: "PR <num> opened on ticket whose board status is <X>; should I review?" and pause this cycle.
     - The `acceptance` block from the board response exists and is non-empty.
  4. Fetch the PR diff: `gh pr diff <num>`.
  5. Build the **expected paths** set: derive from the ticket's owner and `docs/<docs-repo-name>/architecture/folder-structure.md` (e.g. `backend` → the backend subtree of the relevant code repo, `frontend` → the frontend subtree). Never hard-code paths — read them from `folder-structure.md`.
  6. Record an intake header in scratch memory (`memory/<DATE>.md`): PR id, ticket id, head SHA, expected paths, CI status.
- **Exit condition:** All four artifacts (PR metadata, diff, ticket, CI status) are loaded.
- **Output artifacts:** A scratch entry under `memory/<YYYY-MM-DD>.md`.
- **On-error:**
  - PR not found / 404 → post a `question` comment to the handoff sender: "PR <num> not accessible — has it been opened?"
  - Ticket missing from board (`board_get_ticket` returns not found) → post an `escalation` comment to `project-lead`, severity `med`, requesting: "create or repair ticket <ID>".

---

## State 3 — `CHECKLIST`

- **Entry condition:** INTAKE complete; all input artifacts loaded.
- **Actions:** Run the `review-checklist` skill end-to-end. Each item produces a tuple `(status, evidence, citation)` where `status ∈ {pass, fail, n/a}`:
  1. Ticket linked in PR body? (`Closes #<num>` or explicit ticket id mention.)
  2. Verbatim acceptance checklist in PR body?
  3. Each acceptance criterion has a visible addressing point (test, code, or note)?
  4. Lint/format passing on CI?
  5. Type-check passing on CI?
  6. Unit tests for all touched files exist + passing?
  7. No files modified outside expected paths?
  8. OpenAPI contract: any endpoint change matches the service's `architecture/api/<service>/openapi.yaml` exactly?
  9. UI contract: any UI change matches `ui-spec.md` (tokens, flows, copy)?
  10. Data model: any DB-touching change matches `data-model.md`?
  11. Security smells (auth bypass, hard-coded secrets, injection, missing input validation)?
  12. Performance smells (N+1, unbounded loops, sync I/O in async paths)?
  13. Naming/dead code/comment style consistent with surroundings?
  14. Tests cover at least one non-happy-path scenario per touched module?
- **Exit condition:** All 14 items have a status. Any `fail` whose citation field is empty triggers a forced re-check (see on-error) before exit.
- **Output artifacts:** A `verdict-input` JSON block written to `memory/<YYYY-MM-DD>.md` under the current PR header.
- **On-error:**
  - A `fail` without a citation → re-investigate. If I genuinely believe a rule is missing, downgrade to "Suggested" and queue an `update-rules` escalation after the verdict ships.
  - A check requires a decision I cannot make from ADRs/contracts → post a `question` comment to `architect`, transition to **IDLE** (paused), resume CHECKLIST when the answer arrives.

---

## State 4 — `COMMENT`

- **Entry condition:** `verdict-input` ready.
- **Actions:**
  1. Sort failed items into three buckets:
     - **Required**: every item with a hard citation (rule id, ADR id, spec section anchor). All §11/§12 security/perf smells default to Required.
     - **Suggested**: improvements without a hard citation (style, minor refactors).
     - **Nit**: cosmetic, single-line preference.
  2. For each Required/Suggested, post an inline review comment on the offending file+line via host CLI, with the citation. Template:
     ```
     **[Required]** <one-line problem>
     - Source: <rule-id or spec-anchor>
     - Expected: <one-line>
     - Found: <one-line>
     ```
     (Replace `[Required]` with `[Suggested]` or `[Nit]` as appropriate.)
  3. Compose the PR summary comment using the **frozen template**:
     ```
     ## Review Verdict — <REQUEST_CHANGES | APPROVE>
     Ticket: <TICKET-ID> — <title>
     PR: <num> @ <head-sha-short>

     ### Acceptance coverage
     - [x] criterion 1 → <evidence>
     - [ ] criterion 2 → MISSING
     …

     ### Required (block merge)
     1. <item> — source: <citation>
     …

     ### Suggested
     1. <item>
     …

     ### Nits
     1. <item>
     …

     ### Notes
     - Tests: <one-line>
     - Contracts: <one-line>
     - Scope: <one-line>

     — Mira 🔍 (reviewer)
     ```
  4. Post the summary via host CLI (`pr comment`).
- **Exit condition:** All inline comments posted, summary posted, summary URL captured.
- **Output artifacts:** Posted PR comments; summary URL stored in scratch memory.
- **On-error:**
  - CLI 5xx → retry up to 3 times with backoff, then escalate `med` to project-lead.
  - Rate-limited → wait 60s and retry.

---

## State 5 — `VERDICT`

- **Entry condition:** COMMENT complete.
- **Actions:**
  1. If any Required item exists OR any acceptance criterion is unaddressed OR CI is red:
     - Post `gh pr review <num> --request-changes --body <link-to-summary>`.
     - Append a line to `docs/<docs-repo-name>/reviews/review-log.md`:
       ```
       | <ISO> | <PR-num> | <TICKET-ID> | REQUEST_CHANGES | — | <required-count> required, <suggested-count> suggested |
       ```
     - Commit `docs/<docs-repo-name>/reviews/review-log.md` to the docs repo (`git -C repos/<docs-slug> add … && git -C repos/<docs-slug> commit -m "[reviewer] log PR <num> request-changes" && git -C repos/<docs-slug> push`).
     - Post a `handoff` comment to the developer (`backend`/`frontend`) summarizing the REQUEST_CHANGES verdict (PROTOCOLS.md §1) so they know their PR needs work.
     - Transition to **IDLE**.
  2. Else (no Required, all acceptance covered, CI green):
     - Post `gh pr review <num> --approve --body <link-to-summary>`.
     - Run the `merge-pr` skill: `gh pr merge <num> --squash --delete-branch` (or the host equivalent). Capture the merge SHA.
     - Call `board_transition_ticket(ticket_id=<TICKET-ID>, agent="reviewer", to="qa")` to move the ticket to QA status on the board.
     - Append to `docs/<docs-repo-name>/reviews/review-log.md`:
       ```
       | <ISO> | <PR-num> | <TICKET-ID> | APPROVE+MERGED | <merge-sha> | 0 required |
       ```
     - Commit + push the log.
     - Post a `handoff` comment to `qa` (PROTOCOLS.md §1) with the merge SHA, the ticket id, and a link to the summary comment.
     - Transition to **POST_MERGE_AUDIT** (scheduled, not immediate — see below).
- **Exit condition:** Verdict posted, log appended, log committed. For APPROVE: board transitioned, merge complete, and QA handoff comment posted.
- **Output artifacts:** `docs/<docs-repo-name>/reviews/review-log.md` entry; QA `handoff` comment (on approve); merge commit on `main`.
- **On-error:**
  - Merge conflicts on squash → REQUEST_CHANGES with Required: "Resolve conflicts against `main` and re-push". The verdict flips. Log accordingly.
  - `board_transition_ticket` fails → log the error, retry once; if it still fails, post an `escalation` comment (severity `med`) to project-lead with the ticket id before proceeding. Do not block the QA handoff.
  - Push to docs repo fails → retry; if persistent, post an `escalation` comment (severity `high`) to project-lead.

---

## State 6 — `POST_MERGE_AUDIT`

- **Entry condition:** A PR I approved has been merged ≥24 hours ago (or sooner, on demand). Found in IDLE scan of `review-log.md`.
- **Actions:** Run the `audit-post-merge` skill:
  1. `git -C project log <head-sha-at-approval>..<merge-sha> --oneline` on the (now-deleted) branch — fetch from reflog or git host's branch-restore API.
  2. If commits exist between approval-SHA and merge-SHA that I did not see in my review, flag them.
  3. Inspect those commits' diffs. If they touch anything beyond trivial whitespace/comment fixes → post an `escalation` comment (severity `high`) to `project-lead` with the diff.
  4. Mark the audit complete in `docs/reviews/review-log.md` by appending `| audited-clean` or `| audited-flagged: <comment-id>` to the PR's row.
- **Exit condition:** Audit decision recorded, log updated.
- **Output artifacts:** Updated `review-log.md`; possibly an `escalation` comment.
- **On-error:**
  - Branch already deleted and reflog gone → log as `| audited-unavailable` and post an `escalation` comment (severity `low`) to project-lead suggesting a branch retention policy.

---

## Side state — `STANDBY`

- **Entry condition:** `project/` or `docs/` missing on wake (CONVENTIONS.md §9).
- **Actions:** Reply only with:
  > "STANDBY: no project onboarded yet. Waiting for project-lead to run `onboard-project`."
- **Exit condition:** Both repos exist on a subsequent wake.

---

## Side state — `RULES_AMENDMENT`

- **Entry condition:** `escalation` from `project-lead` with `requested_decision: "amend rules.md ..."` approved.
- **Actions:** Run `update-rules` skill: add/edit the rule with a stable id, commit + push, post a reply `escalation` comment referencing the approving comment with the new rule id.
- **Exit condition:** `rules.md` updated, commit pushed, confirmation comment posted.
- **Output artifacts:** Updated `docs/reviews/rules.md`.

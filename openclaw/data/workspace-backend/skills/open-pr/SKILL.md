---
name: open-pr
description: Push branch, open PR with the full template body, flip ticket to in_review, send handoff to reviewer.
trigger: OPEN_PR state — self-review passed.
inputs: TICKET_ID, branch name.
outputs: remote branch pushed, open PR, board-api ticket status transitioned to in_review, outbox handoff to reviewer (and to architect if .env.example changed).
---

# open-pr

Deterministic procedure.

1. **Final sync**
   ```sh
   cd project
   git fetch origin main
   git rebase origin/main          # or merge --no-ff; project's convention from ADR
   ```
   On conflict: resolve in-place, re-run tests, only then continue.

2. **Push the branch**
   ```sh
   git push -u origin backend/<TICKET-ID>-<slug>
   ```
   On rejected (non-fast-forward to a shared branch): STOP. This should never happen on my own branch namespace; if it does, escalate.

3. **Compose the PR body** — exact section order, exact headings:

   ```markdown
   ## Ticket
   - Board: call `board_get_ticket(TICKET_ID)` for authoritative ticket data.

   ## Summary
   <one to three sentences describing what this PR does, in imperative voice>

   ## Acceptance
   <verbatim copy from ticket frontmatter `acceptance`, each as a checkbox>
   - [x] criterion 1
   - [x] criterion 2
   - [ ] criterion 3  <!-- deferred, see question 2026-06-24T091500Z -->

   ## Changes
   - `project/backend/src/<area>/<file>.ts` — <what changed>
   - `project/backend/tests/<area>/<file>.spec.ts` — <new test cases>
   - `project/migrations/<timestamp>_<name>_up.sql` — <schema delta>
   - `project/migrations/<timestamp>_<name>_down.sql` — <reverse delta>

   ## Tests
   - `pnpm test --filter backend -- tests/<area>` (or project's equivalent).
   - New cases: <bullet list>.

   ## Out-of-scope
   - <anything I deliberately did NOT touch even though it's nearby>

   ## Risks
   - <migrations, auth changes, breaking changes, perf-sensitive code>
   - <if a destructive migration: explicit architect handoff reference>
   ```

   Every section is required. Empty sections use `- none` — never delete the section.

4. **Open the PR** with the host CLI (chosen at onboarding — `gh` / `tea` / `glab`):
   - Title: `[<TICKET-ID>] <imperative one-line>` matching the commit subject.
   - Base: `main` (or project's default branch per ADR).
   - Head: `backend/<TICKET-ID>-<slug>`.
   - Body: the composed body from step 3.
   - Request review from `reviewer` (Mira).
   - Add labels per project convention (e.g., `backend`, `<TICKET-ID>`).

5. **Flip ticket status**
   Call `board_transition_ticket(ticket_id=TICKET_ID, agent="backend", to="in_review")`.

6. **Send handoff to reviewer**
   - Write `outbox/<ISO>-reviewer-handoff.json` using the schema in PROTOCOLS.md §1.1 with this PR's actual:
     - `ticket_id`
     - `artifact_paths`: list every changed file plus `PR#<N>`.
     - `summary`: one-line.
     - `acceptance`: verbatim from ticket.
     - `blocking_questions`: any unresolved questions.

7. **If `.env.example` changed**, also write `outbox/<ISO>-architect-handoff.json` per PROTOCOLS.md §1.3.

8. **Log to memory**
   - PR number, URL, base SHA, head SHA, timestamp.

9. **Transition** to ADDRESS_REVIEW per WORKFLOWS.md §8.

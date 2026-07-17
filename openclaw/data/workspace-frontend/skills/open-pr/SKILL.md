---
name: open-pr
description: Open a PR for the current branch using the FE PR template (with the UI conformance section) and hand off to reviewer.
trigger: State 6 — OPEN_PR, after self-review passes.
inputs: Current branch; ticket data from board-api; tokens-lint output; axe-check output; states matrix evidence; Figma frame links.
outputs: An open PR on the project repo with the FE template body; a `handoff` comment to reviewer via board_add_comment; ticket status moved to in_review via board_transition_ticket.
---

# open-pr

1. **Confirm branch state.**
   - `git status` — working tree clean.
   - `git fetch origin && git rebase origin/main` — branch is up to date with `main`. Resolve conflicts only inside `project/frontend/**`. If a conflict touches anything outside, STOP and file `escalation` severity=`high` to project-lead.
   - `git push --force-with-lease` (force-with-lease is the only force allowed; never `--force`).

2. **Re-run gates.** Lint, type-check, unit/component tests, `tokens-lint`, `axe-check`. All must be green. If any fails, return to IMPLEMENT.

3. **Compose PR title.** Exactly `[<TICKET-ID>] <imperative one-line>`. The imperative must be ≤72 chars total.

4. **Compose PR body using this template (mandatory).**

```
## Ticket
<TICKET-ID>

## Acceptance (verbatim from ticket)
- [ ] criterion 1
- [ ] criterion 2
...

## UI Conformance
- Pages touched: P-NN (docs/ui/pages/P-NN.md), P-MM, ...
- Components added/changed: <name> (docs/ui/components.md §C-XX)
- Tokens-only confirmed: yes — tokens-lint 0 violations (output below)
- States covered:
  - [x] Loading
  - [x] Empty
  - [x] Error
  - [x] Success
  - [x] Disabled
- Figma frames: <links>
- a11y: axe 0 violations on touched routes (output below)
- i18n: keys added to default locale catalog

## Tests
- Files: <list>
- States-matrix tests: <list>

## Spec references
- ui-spec §<number>, §<number>
- ADRs: <if any, with IDs>

## Tool outputs
<details><summary>tokens-lint</summary>

```
<paste full output>
```
</details>
<details><summary>axe-check</summary>

```
<paste full output>
```
</details>
```

5. **Copy acceptance verbatim.** The Acceptance section MUST match the ticket frontmatter's `acceptance:` list character-for-character. Reviewer's quality gate fails otherwise (CONVENTIONS.md §7.4).

6. **Open the PR** against `main` via the git host CLI (`gh pr create`, `glab mr create`, etc., per project). Capture the PR URL.

7. **Transition ticket status.** Call `board_transition_ticket(ticket_id=<TICKET-ID>, to=in_review)`.

8. **Post `handoff` comment to reviewer.** Call `board_add_comment`:

```
board_add_comment(
  ticket_id="<TICKET-ID>",
  author="frontend",
  to="reviewer",
  type="handoff",
  body="PR#<num> open for <TICKET-ID> — <one-line>; tokens-lint=0, axe=0, all 5 states covered. "
       "Artifacts: <PR URL>, <P-NN paths>. Requested: reviewer verdict within 1 cycle."
)
```

See `PROTOCOLS.md` §S1 for the full body style. A comment is delivered the instant board-api stores it (CONVENTIONS.md §12).

9. **Log in `memory/YYYY-MM-DD.md`** with PR URL, branch, ticket id, ISO timestamp.

10. **Park** — wait for reviewer feedback. Return to SCAN_COMMENTS.

## Forbidden during this skill

- Self-merge (CONVENTIONS.md §6.6).
- `git push --force` on any branch.
- Editing the ticket's `acceptance` block to make it pass.
- Skipping any of the PR body sections.

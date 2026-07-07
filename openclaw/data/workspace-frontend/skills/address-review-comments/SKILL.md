---
name: address-review-comments
description: Walk every reviewer comment on my PR and either apply a fix or reply with citation; re-run gates and re-request review.
trigger: State 7 — ADDRESS_REVIEW. Reviewer left `request_changes` or comments.
inputs: PR URL; reviewer comments; docs/ui/* spec; ROLE.md.
outputs: Updated commits on the branch; replies on each comment thread; re-request review when verdict can change to `approve`.
---

# address-review-comments

1. **Fetch all review comments.** Use the git host CLI to list every unresolved comment on the PR.

2. **Categorize each comment** into one of:
   - (A) Clear correctness bug or test gap → fix.
   - (B) Style/clarity nit → apply fix. Only exception: if the fix would require touching files outside `project/frontend/**`, do NOT apply — file a question to reviewer (or project-lead if scope is ambiguous) noting the cross-boundary nature.
   - (C) Spec/contract dispute (reviewer asks for behavior that contradicts ui-spec, components.md, tokens, or the API contract) → do NOT capitulate. Reply on the thread with the citation; file `question` to the appropriate owner (uiux or architect).
   - (D) Out-of-scope ask (creep) → reply citing the ticket scope; file `escalation` severity=`low` to project-lead if reviewer pushes back.
   - (E) Already-correct, reviewer misread → reply with the relevant code/spec citation explaining the existing behavior.

3. **For each (A)/(B) comment:**
   - Apply the smallest correct fix.
   - Commit with subject `[<TICKET-ID>] address review — <short>`.
   - Reply on the comment thread referencing the commit SHA.

4. **For each (C) comment:**
   - Reply on the comment thread: cite the spec § / `P-NN` / token id / contract field that defines current behavior.
   - File `question` to the owner of that artifact:
     - components/spec/tokens → `uiux`
     - contract/endpoints → `architect`
   - Mark ticket `status: blocked`. Wait for the answer.
   - When answered, either: update the spec was the right move → reviewer's request becomes valid → fix; OR spec wins → reply with the confirmation and ask reviewer to re-resolve.

5. **For each (D) comment:**
   - Reply: "Out of scope for <TICKET-ID> (acceptance does not include this). Recommend a follow-up ticket."
   - If reviewer pushes back → `escalation` severity=`low` to project-lead with both sides.

6. **For each (E) comment:**
   - Reply with the code reference (`L<line>`) showing existing handling, plus the test that exercises it.

7. **Re-run all gates** (lint, type-check, tests, `tokens-lint`, `axe-check`) before re-requesting review. If any new gate fails, return to IMPLEMENT.

8. **Push amendments.** `git push --force-with-lease` only (never `--force`).

9. **Re-request review.** Use the git host CLI to re-request review from `reviewer`. Do not assume silence = approval.

10. **Log** outcomes in `memory/YYYY-MM-DD.md`: which comments were fixed, which were disputed, which questions were filed.

## Forbidden during this skill

- Silently changing acceptance criteria.
- Silently changing tokens or components without an upstream spec change.
- Disabling a11y rules to make reviewer happy (only ADR-backed disables allowed, per ROLE.md Forbidden #4).
- Self-merging "because reviewer is slow" (CONVENTIONS.md §6.6).

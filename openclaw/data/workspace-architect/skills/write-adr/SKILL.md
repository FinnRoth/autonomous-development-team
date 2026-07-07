---
name: write-adr
description: Generate a new ADR file with auto-numbering, status=proposed, and the fixed section template.
trigger: ASSESS state determined that a decision must be recorded (new policy, new dependency, supersession of an existing ADR).
inputs:
  - question: the decision to be made (one sentence)
  - decision: the choice, stated declaratively
  - alternatives: list of at least 2 alternatives with one-line rationale each
  - supersedes (optional): id of ADR being superseded
  - ticket_id: the originating ticket
outputs:
  - docs/architecture/adr/ADR-NNN-<slug>.md (status: proposed)
  - (if supersedes) edits to the superseded ADR's frontmatter
---

# Procedure

1. Compute `NNN`: list `docs/architecture/adr/`, parse the leading integer from each filename, take max+1, zero-pad to 3. Never reuse a number.
2. Compute `<slug>`: lowercase, kebab-case, max 6 words, derived from the `decision` argument.
3. Write the file at `docs/architecture/adr/ADR-NNN-<slug>.md` with this exact frontmatter:
   ```yaml
   ---
   id: ADR-NNN
   title: <human title — sentence case, no trailing punctuation>
   status: proposed
   date: <today, YYYY-MM-DD>
   supersedes: <ADR-MMM or null>
   superseded_by: null
   ticket_id: <TICKET-ID>
   ---
   ```
4. Body — exactly these sections, in this order, headed by `##`:
   1. `## Context` — why the question exists; cite tickets, prior ADRs, and observed pain.
   2. `## Decision` — declarative; one paragraph maximum, plus optional bullet list of rules.
   3. `## Consequences`
      - `### Positive`
      - `### Negative`
      - `### Neutral`
   4. `## Alternatives` — one subsection per alternative (`### <alt name>`) with `pros`, `cons`, and `why-not-chosen`.
   5. `## Related` — list of related ADR ids, tickets, and external links.
5. If `supersedes` is non-null, open the prior ADR file and set `superseded_by: ADR-NNN`. Do not change its `status` yet — that happens at FREEZE.
6. Lint: ensure the file contains every required section (`grep -E '^## (Context|Decision|Consequences|Alternatives|Related)$'` returns 5 matches). If not, fail loudly; do not commit a partial ADR.
7. Stage on a new branch `architect/<TICKET-ID>-ADR-NNN`. Commit subject `[<TICKET-ID>] ADR-NNN: <title>`.
8. Return the path and id to the caller (workflow then proceeds to SOLICIT_REVIEW).
9. Append `memory/YYYY-MM-DD.md`: `drafted ADR-NNN <slug> (proposed)`.

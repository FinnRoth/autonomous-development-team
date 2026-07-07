---
name: draft-epic
description: Turn a completed Q&A document into one Epic ticket and its child Story tickets, with strict schema validation.
trigger: A Q&A-<topic>.md file with `status: complete` exists and has not yet been converted into tickets.
inputs: docs/requirements/Q&A-<topic>.md.
outputs: docs/tickets/EPIC-NN.md, one or more docs/tickets/STORY-NN.md, updated docs/project/glossary.md, updated docs/project/risk-register.md.
---

# draft-epic — deterministic procedure

## Step 1 — Determine next IDs

List existing tickets:

```
ls docs/tickets/EPIC-*.md | wc -l    → next EPIC index = count + 1
ls docs/tickets/STORY-*.md | wc -l   → next STORY index = count + 1
```

Format: zero-padded two-digit (e.g., `EPIC-03`, `STORY-12`). If count ≥ 99, switch to three-digit.

## Step 2 — Draft the Epic

Open the Q&A summary footer. Create `docs/tickets/EPIC-NN.md`:

```yaml
---
id: EPIC-NN
type: epic
title: <derive from Q1 purpose; ≤8 words; verb-first>
parent: null
owner: unassigned
status: backlog
priority: <P0 if Q6 has a deadline within 1 month or Q12 says "push existing", else P1>
estimate: <S | M | L | XL — based on rough story count: 1-2 stories=S, 3-4=M, 5-7=L, 8+=XL>
created: <ISO>
acceptance:
  - <copy verbatim from Q3 success criterion; convert to single testable statement>
depends_on: []
blocks: []
---

## Context

<Q1 verbatim>

## Users

<Q2 verbatim>

## Scope

<bullet list derived from Q1+Q5+Q8; each bullet = one major capability>

## Non-goals

<verbatim from Q4 bullets>

## Constraints

<verbatim from Q5, Q6, Q7>

## Integrations

<verbatim from Q9>

## Open questions

<any Q with `Status: vague` or `Status: declined`; phrase as open question>
```

## Step 3 — Decompose into Stories

Use `sequential-thinking` to identify candidate Stories. Rules:

1. Each Story = one user-facing capability OR one technical enabler.
2. A Story is "rightsized" if its acceptance criteria fit on one page AND it can plausibly be done by ≤2 agents collaborating.
3. If a candidate Story has >5 acceptance criteria, split it.
4. If two candidate Stories share >50% of their acceptance criteria, merge them.

For each Story, write `docs/tickets/STORY-NN.md`:

```yaml
---
id: STORY-NN
type: story
title: <verb-first, ≤10 words>
parent: EPIC-NN
owner: unassigned
status: backlog
priority: <inherit Epic priority unless explicitly different>
estimate: <S | M | L>
created: <ISO>
acceptance:
  - "<criterion 1; must be testable; cite Q&A line in body>"
  - "<criterion 2>"
depends_on: [<other STORY-XX ids>]
blocks: [<other STORY-XX ids>]
---

## Context

<one paragraph; cite Q&A by Q-number>

## Scope

<bullet list>

## Non-goals

<bullet list; derived from Epic Q4>

## Open questions

<any unknowns; will surface as `question` messages from the implementing agent>

## Traceability

- Acceptance #1 ← Q&A-<topic>.md §Q<n>
- Acceptance #2 ← Q&A-<topic>.md §Q<n>
```

## Step 4 — Update Epic with Story list

Append to EPIC-NN body:

```
## Stories

- STORY-NN — <title>
- STORY-NN+1 — <title>
- …
```

Also fill the Epic's `blocks` field with any cross-Epic dependencies the user mentioned in Q12.

## Step 5 — Update glossary

Scan the Q&A for any noun that appears ≥3 times and is not already in `docs/project/glossary.md`. For each such term, prompt me (internally) to write a one-line definition; append:

```markdown
- **<term>** (<added ISO>): <one-line definition; cite Q&A source>.
```

Do not invent definitions — if the term's meaning is unclear from the Q&A, leave it out and add a TODO under "Open questions" in the Epic.

## Step 6 — Update risk register

For each entry in Q&A Q10 (known risks) and Q11 (deal-breakers) that is NOT already in `docs/project/risk-register.md`:

Append a row with severity (high if from Q11 deal-breakers, med for Q10), owner `project-lead`, status `open`, review_by `<created ISO + 14d>`.

## Step 7 — Quality-gate run

Self-check every gate from `ROLE.md` §Quality Gates items 1-6 (item 7, feasibility, is for after architect review).

For each failure, fix in place and re-run. Do NOT skip a gate.

The topological-sort check for Gate 3 (circular depends_on):
1. Build the dependency graph from STORY-NN `depends_on` fields within this Epic.
2. Attempt a topological sort.
3. If sort fails, identify the cycle, identify the cycle, break it (usually by removing one direction, or merging the two Stories), document the change in the Epic's Open Questions, and re-run.

## Step 8 — Commit

```
git add docs/tickets/EPIC-NN.md docs/tickets/STORY-*.md docs/project/glossary.md docs/project/risk-register.md
git commit -m "[EPIC-NN] Draft Epic from Q&A-<topic> with <N> Stories"
git push
```

## Step 8a — Mirror tickets to board-api

After the git commit in Step 8 succeeds, for each ticket file just committed (the Epic and all Stories):

1. Read the frontmatter fields from the file.
2. Call `board_create_ticket` with all CONVENTIONS.md §3 fields plus the `body` (the markdown content after the frontmatter).
3. If `board_create_ticket` returns 409 (ticket id already exists), call `board_update_ticket` with the updated fields instead.
4. Log the result to `memory/YYYY-MM-DD.md`.

**On board-api unreachable:** Log the error to memory, proceed without error. The markdown files are the fallback source of truth. Run the `sync-board-api` skill on the next monitor cycle to reconcile.

## Step 9 — Hand off to REVIEW_WITH_ARCHITECT

Return control to the workflow. Next state per `WORKFLOWS.md`: REVIEW_WITH_ARCHITECT (send handoff to architect; do NOT update board.md yet).

## On-error

- Cannot derive a measurable acceptance criterion → loop back to INTERROGATE for that Q.
- Story count is 0 (Epic too small) → consider whether it should be a Story under an existing Epic instead; if so, abandon Epic creation and recreate as a Story.
- Story count is >12 → Epic too big; split into two Epics by theme before continuing.

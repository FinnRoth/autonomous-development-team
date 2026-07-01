---
name: intake-story
description: Pull a Story from the qa column, parse its ticket, and produce the case-file skeleton.
trigger: A handoff arrives putting STORY-NN in the qa column, OR I find a Story in qa column without a case file.
inputs:
  - story_id (e.g. STORY-07)
  - docs/tickets/<story-id>.md (must exist)
  - linked PR id from the handoff (if any)
outputs:
  - docs/qa/cases/<story-id>.md (skeleton with acceptance criteria copied verbatim)
  - row added to docs/qa/coverage-matrix.md with status `intake`
---

# intake-story

Deterministic intake procedure for a Story landing in the qa column.

## Steps

1. **Read the handoff** (or the board entry). Extract: `story_id`, optional `pr_id`, optional `notes_from_reviewer`.

2. **Verify the ticket exists.** Run `ls docs/tickets/<story-id>.md`. If absent → send `question` to project-lead "Story <story-id> moved to qa column but `docs/tickets/<story-id>.md` not found." Stop. Wait for answer.

3. **Read the ticket** in full. Confirm `type: story` (or `task`, `bug`). Confirm `status: qa` in frontmatter. If status is something else, send `question` to project-lead asking for status reconciliation; stop.

4. **Copy the acceptance block verbatim** into local memory. Do not paraphrase. Acceptance is the contract.

5. **Read linked artifacts** in this order:
   - `docs/architecture/openapi.yaml` — find the endpoints the Story touches (search by ticket id in commit log of openapi, or by endpoint names mentioned in ticket body).
   - `docs/ui/ui-spec.md` and `docs/ui/flows/<flow>.md` — find the flow the Story modifies.
   - Linked ADR(s) referenced in the ticket body.
   - `docs/reviews/PR-<pr_id>.md` if a PR is linked — note any concerns the reviewer raised; these are pre-found bug suspects.

6. **Confirm build state.** Run `cd project && git pull`. Verify the running app responds at `FRONTEND_URL` and `BACKEND_URL` (per `docs/project/dev-env.md`). If unreachable → escalation severity `high` to project-lead. Stop.

7. **Create the case-file skeleton** at `docs/qa/cases/<story-id>.md`:

```markdown
---
story_id: <STORY-ID>
linked_pr: <PR-ID or null>
intake_date: <ISO-8601 date>
status: intake | design | automating | exploring | qa-complete | blocked
---

# Test cases — <STORY-ID>: <story title>

## Acceptance Criteria (verbatim from ticket)
1. <criterion 1>
2. <criterion 2>
...

## Happy Path Cases
<one row per criterion, table: id | scenario | steps | expected | automated | linked_test>

## Edge Cases
<table with same columns>

## Negative Cases
<table with same columns>

## Cross-Cutting Cases
<table with same columns; a11y, mobile, browser back/forward, deep-link reload>

## Exploratory Log
<populated during EXPLORE state; one bullet per probe with timestamp + outcome>

## Linked Bugs
<populated as bugs are filed; format: BUG-NN (Sx) — <summary>>

## Automation Status
- total_cases: 0
- automated: 0
- blocked: 0
- last_run: never
```

8. **Update coverage matrix.** Append (or update) the row for this Story in `docs/qa/coverage-matrix.md`:

```
| STORY-ID | title | status | total_cases | automated | open_bugs | last_run |
| -------- | ----- | ------ | ----------- | --------- | --------- | -------- |
| <id>     | <t>   | intake | 0           | 0         | -         | -        |
```

9. **Commit on branch** `qa/<STORY-ID>-intake` in `docs/`:
   - `git checkout -b qa/<STORY-ID>-intake`
   - `git add docs/qa/cases/<STORY-ID>.md docs/qa/coverage-matrix.md`
   - `git commit -m "[<STORY-ID>] qa: intake — case skeleton"`
   - `git push origin qa/<STORY-ID>-intake`
   - Open PR with title `[<STORY-ID>] qa: intake` against the default branch of `<project>-docs`.

10. **Update `memory/state.md`**: set `current_story: <STORY-ID>`, `state: DESIGN_CASES`.

11. **Transition to DESIGN_CASES** (see `WORKFLOWS.md §3`).

## Failure modes
- Ticket frontmatter malformed → `question` to project-lead asking for ticket fix; stay in INTAKE.
- Acceptance block empty → `question` to project-lead requesting acceptance criteria; stay in INTAKE.
- Build unreachable → `escalation` severity `high` to project-lead; stay in INTAKE.

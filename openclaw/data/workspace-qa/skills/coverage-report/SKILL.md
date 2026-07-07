---
name: coverage-report
description: Regenerate docs/qa/coverage-matrix.md from the current set of case files.
trigger: After every Story transitions in/out of qa-complete; OR on weekly heartbeat to refresh the matrix.
inputs:
  - docs/qa/cases/*.md (all case files)
  - docs/qa/bug-reports/*.md (all bug reports)
  - board_list_tickets() results (for Story titles and statuses)
outputs:
  - docs/qa/coverage-matrix.md (fully regenerated)
  - weekly handoff to project-lead with the matrix
---

# coverage-report

Deterministic regeneration of the coverage matrix.

## Steps

1. **Enumerate all case files.** `ls docs/qa/cases/*.md`. For each, parse frontmatter (`story_id`, `status`, `intake_date`) and the `Automation Status` block (`total_cases`, `automated`, `blocked`, `last_run`).

2. **Enumerate all bug reports.** `ls docs/qa/bug-reports/BUG-*.md`. For each, parse frontmatter (`id`, `severity`, `status`, `related_story`).

3. **Cross-reference with board-api.** For each `story_id`, call `board_get_ticket(id=<story_id>)` to get the title and current ticket status.

4. **Build the matrix.** Overwrite `docs/qa/coverage-matrix.md` with this exact structure:

```markdown
# QA Coverage Matrix

Generated: <ISO-8601 timestamp>
Total stories tracked: <N>
Stories qa-complete: <N>
Stories in qa state: <N>
Stories blocked: <N>
Open bugs: S1=<n>, S2=<n>, S3=<n>, S4=<n>
Closed bugs (this period): <N>
Regression tests in suite: <N>

## Matrix

| Story | Title | Ticket status | QA status | Total cases | Automated | Blocked | Open bugs | Closed bugs | Last run |
|-------|-------|---------------|-----------|-------------|-----------|---------|-----------|-------------|----------|
| STORY-01 | Login | done | qa-complete | 9 | 9 | 0 | - | BUG-03 | 2025-11-04 |
| STORY-02 | ... | ... | ... | ... | ... | ... | ... | ... | ... |

## Open bugs detail

| Bug | Severity | Story | Suspected owner | Filed | Age (h) | Status |
|-----|----------|-------|-----------------|-------|---------|--------|
| BUG-NN | S2 | STORY-07 | backend | 2025-11-04 | 18 | open |

## Flaky tests

| Test | Stories | Failure rate (last 10 runs) | Status |
|------|---------|------------------------------|--------|
| ... | ... | ... | investigating |

## Regression suite

| File | Guards bug | Story |
|------|------------|-------|
| qa-tests/regression/BUG-14.spec.ts | BUG-14 | STORY-07 |

## Notes

<any narrative the matrix can't capture: known gaps, risky areas, recurring failure clusters>
```

5. **Numbers must add up.** Sanity checks before saving:
   - Sum of (automated + blocked + remaining) per story = total_cases for that story.
   - Total open bugs in summary line = number of rows in "Open bugs detail".
   - No story listed as qa-complete with open S1/S2 bugs (that would be a contradiction — log a warning).

6. **Identify clusters.** If ≥3 bugs in the past month share `suspected_owner` AND area (heuristic: same Story parent epic or same backend service path), note it in the "Notes" section as a regression hotspot — material for an `escalation` to project-lead (see `PROTOCOLS.md §3.1` example).

7. **Commit** to `docs/`:
   - `git checkout -b qa/coverage-<ISO-date>`
   - `git add docs/qa/coverage-matrix.md`
   - `git commit -m "[QA] coverage matrix refresh <ISO-date>"`
   - `git push`
   - Open PR via `gh`; request reviewer (Mira) like any other PR. Do NOT self-merge.

8. **Send weekly handoff to project-lead** with summary line (see `PROTOCOLS.md §1.1` example "Coverage report (weekly)"). Send only on the weekly cycle, not every regeneration — too noisy otherwise.

9. **Log** in `memory/YYYY-MM-DD.md`: `coverage-report regenerated. <N> stories, <N> open bugs.`

## Failure modes
- Frontmatter in a case file is malformed → log "skipped <file>: malformed frontmatter" in Notes; do NOT crash the regeneration. File a follow-up to fix the case file (it's mine to fix).
- Bug report missing related_story → list under a separate "Orphan bugs" subsection and fix the bug file next cycle.

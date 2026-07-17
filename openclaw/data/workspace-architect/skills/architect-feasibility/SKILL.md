---
name: architect-feasibility
description: From an Epic id, produce a feasibility report covering stack-fit, data/api deltas, cross-cutting impact, risks, recommendation, and required ADRs.
trigger: A `handoff` comment from `project-lead` referencing `EPIC-NN` is returned by board_get_unread(agent="architect"), OR a heartbeat re-opens a stale feasibility request.
inputs:
  - ticket: EPIC-NN id (read from board-api via board_get_ticket)
  - vision: docs/project/vision.md
  - any referenced Q&A files under docs/requirements/
  - current architecture artifacts (overview.md, data-model.md, each service's api/<service>/openapi.yaml, protocols.md, accepted ADRs)
outputs:
  - docs/architecture/feasibility/feasibility-report-EPIC-NN.md (committed via PR)
---

# Procedure

1. Call `board_get_ticket(id="EPIC-NN")` to retrieve the Epic. If the ticket is not found or type is not `epic`, post a `question` comment to `project-lead` and STOP.
2. Read in order: the Epic body, its `acceptance` list, `docs/project/vision.md`, every artifact referenced in the originating handoff comment's `body`, then `docs/architecture/overview.md`, `data-model.md`, `protocols.md`, and the index of accepted ADRs.
3. Extract a flat list of **capabilities** the Epic requires. Format: `C-1: <imperative phrase>`. Capabilities must be testable.
4. For each capability, classify:
   - `stack-fit: native | adapter-needed | incompatible`
   - `data-delta: none | additive | breaking`
   - `api-delta: none | additive | breaking`
   - `cross-cutting: none | auth | error | pagination | idempotency | versioning | observability`
5. Invoke `context7` for any library/SDK that appears in the Epic (e.g., "Stripe", "Auth0"). Record version + license + maintenance status.
6. Invoke `sequential-thinking` to enumerate at least 2 alternatives for each `adapter-needed` or `incompatible` capability. Pick one with rationale.
7. Build a **risks** table with columns `risk | likelihood (L/M/H) | impact (L/M/H) | mitigation`.
8. Build a **required-ADRs** list: each entry is `ADR-NNN (proposed) — <slug> — <one-line decision>`. Numbering is the next free integer at time of report; if multiple ADRs are needed, reserve consecutive ids and document them.
9. End the report with exactly one **recommendation line**, chosen from:
   - `feasible` — proceed as-is.
   - `feasible-with-changes` — proceed after listed ADRs accepted.
   - `infeasible` — escalate to `project-lead` (post an `escalation` comment separately, `severity: high`).
10. Write the report to `docs/architecture/feasibility/feasibility-report-EPIC-NN.md` with this exact section order:
    1. `# Feasibility Report — EPIC-NN: <title>`
    2. `## Capabilities` (numbered list)
    3. `## Stack Fit` (table)
    4. `## Data Deltas` (subsections per entity)
    5. `## API Deltas` (subsections per endpoint group)
    6. `## Cross-Cutting Impact`
    7. `## Risks` (table)
    8. `## Alternatives Considered`
    9. `## Required ADRs`
    10. `## Recommendation` (exactly one line)
11. Commit on branch `architect/EPIC-NN-feasibility`. Push. Open PR titled `[EPIC-NN] Feasibility report`.
12. Post a `handoff` reply comment to `project-lead` (see PROTOCOLS.md §S-1) referencing the report and any drafted ADRs in the body.
13. If recommendation = `infeasible`, additionally post an `escalation` comment (severity `high`) per PROTOCOLS.md §S-5.
14. Append a one-line entry to `memory/YYYY-MM-DD.md`: `feasibility EPIC-NN → <recommendation>`.

---
name: claim-task
description: Atomically claim a ready ticket from board-api and create a working branch.
trigger: board_get_ready_tickets(owner=frontend) returns at least one ticket and the IDLE state selects one.
inputs: TICKET_ID (e.g. STORY-07)
outputs: board-api ticket marked in_progress; local branch frontend/<TICKET-ID>-<slug>; memory note.
---

# claim-task

Deterministic procedure. Run from workspace root.

## Step 1 — Claim the ticket atomically

Call the `board_claim_ticket` MCP tool:
```
board_claim_ticket(ticket_id=TICKET_ID, agent="frontend")
```

**On 409 response:** The ticket was claimed by another agent or its dependencies (e.g., uiux spec not done) are not met.
- Log the reason to `memory/YYYY-MM-DD.md`.
- Return to IDLE immediately — do NOT attempt to claim a different ticket in this step.

**On 200 response:** Proceed. Extract from the response:
- `acceptance` — the array of testable acceptance criteria (verbatim)
- `body` — the narrative context (Context, Scope, Non-goals, Open questions)
- `depends_on` — confirm uiux story is done before starting implementation

## Step 2 — Update local code repo

```sh
cd project
git checkout main
git pull --ff-only
```

## Step 3 — Build the slug

- Lowercase the ticket title.
- Replace non-alphanumerics with `-`.
- Collapse runs of `-` to one.
- Trim leading/trailing `-`.
- Truncate to 40 chars at the last `-` boundary.

## Step 4 — Create the working branch

```sh
git checkout -b frontend/<TICKET-ID>-<slug>
```
On "branch exists": check out the existing branch; if its log shows unrelated commits, STOP and file `escalation` to project-lead.

## Step 5 — Print the contract to memory

Append to `memory/YYYY-MM-DD.md`:
- `claimed: <TICKET-ID> at <ISO>`
- The full ticket body (from board-api response).
- The acceptance list verbatim — exact strings to paste into the PR body.
- The branch name.
- Pointers to artifacts to read in SPIKE: `docs/ui/ui-spec.md`, relevant page files, `docs/ui/design-tokens.json`, `docs/architecture/api/<service>/openapi.yaml` (`<service>` = the code repo per `project/repos.md`, if an endpoint is involved).

## Step 6 — Transition state to SPIKE

Return control to the workflow. Next state per `WORKFLOWS.md`: SPIKE.

## On-error

- 409 from board_claim_ticket → return to IDLE (dependency enforcement: uiux ticket may not be done yet).
- Code repo non-fast-forward → STOP, file escalation to project-lead.

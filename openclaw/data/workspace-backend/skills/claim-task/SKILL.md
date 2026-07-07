---
name: claim-task
description: Atomically claim a ready ticket from board-api and create a working branch.
trigger: board_get_ready_tickets(owner=backend) returns at least one ticket and the IDLE state selects one.
inputs: TICKET_ID (e.g. TASK-12)
outputs: board-api ticket marked in_progress; docs mirror commit; local branch backend/<TICKET-ID>-<slug>; memory note.
---

# claim-task

Deterministic procedure. Run from workspace root.

## Step 1 — Claim the ticket atomically

Call the `board_claim_ticket` MCP tool:
```
board_claim_ticket(ticket_id=TICKET_ID, agent="backend")
```

**On 409 response:** The ticket was claimed by another agent or its dependencies are not done.
- Log the reason to `memory/YYYY-MM-DD.md`.
- Return to IDLE immediately — do NOT attempt to claim a different ticket in this step (IDLE will re-poll).

**On 200 response:** Proceed. Extract from the response:
- `acceptance` — the array of testable acceptance criteria (verbatim)
- `body` — the narrative context (Context, Scope, Non-goals, Open questions)
- `depends_on` — for reference

## Step 2 — Mirror status to docs

Pull docs repo and flip status in the markdown mirror:
```sh
cd docs && git pull --ff-only
```
On non-fast-forward: log to memory; the board-api claim already succeeded, so proceed anyway.
Edit `docs/tickets/<TICKET-ID>.md`: set frontmatter `status: in_progress`.
```sh
cd docs
git add tickets/<TICKET-ID>.md
git commit -m "[<TICKET-ID>] backend claims ticket"
git push
```
On push failure: log to memory and continue — the board-api record is authoritative.

## Step 3 — Update local code repo

```sh
cd ../project
git checkout main
git pull --ff-only
```

## Step 4 — Build the slug

- Lowercase the ticket title.
- Replace non-alphanumerics with `-`.
- Collapse runs of `-` to one.
- Trim leading/trailing `-`.
- Truncate to 40 chars at the last `-` boundary.

## Step 5 — Create the working branch

```sh
git checkout -b backend/<TICKET-ID>-<slug>
```
On "branch exists": check out the existing branch; if its log shows unrelated commits, STOP and file `escalation` to project-lead.

## Step 6 — Print the contract to memory

Append to `memory/YYYY-MM-DD.md`:
- `claimed: <TICKET-ID> at <ISO>`
- The full ticket body (from board-api response).
- The acceptance list verbatim — exact strings to paste into the PR body.
- The branch name.
- Pointers to artifacts to read in SPIKE: `docs/architecture/api/openapi.yaml`, `docs/architecture/data-model.md`, relevant ADRs, `docs/architecture/protocols.md`.

## Step 7 — Transition state to SPIKE

Return control to the workflow. Next state per `WORKFLOWS.md`: SPIKE.

## On-error

- 409 from board_claim_ticket → return to IDLE (re-poll on next heartbeat).
- Docs git push failure → log and continue; board-api claim is authoritative.
- Code repo non-fast-forward → STOP, file escalation to project-lead.

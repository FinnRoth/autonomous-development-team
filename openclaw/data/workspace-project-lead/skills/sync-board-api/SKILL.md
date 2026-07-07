---
name: sync-board-api
description: Reconcile board-api from the docs repo tickets. Used after migration, board-api restart, or detected drift between board-api and docs/tickets/*.md.
trigger: project-lead detects board-api is missing tickets, or user/PL manually requests sync.
inputs: docs/<docs-repo-name>/tickets/ directory (all ticket markdown files)
outputs: board-api reconciled with all markdown tickets; sync report in memory.
---

# sync-board-api

Deterministic reconciliation procedure.

## Step 1 — Pull docs

```sh
cd docs && git pull --ff-only
```

## Step 2 — List all ticket files

```sh
ls docs/tickets/*.md
```

If empty: log "no tickets found" and stop.

## Step 3 — For each ticket file

For each file at `docs/tickets/<ID>.md`:

1. Parse the YAML frontmatter to extract all CONVENTIONS.md §3 fields (id, type, title, parent, owner, status, priority, estimate, created, acceptance, depends_on, blocks).
2. Extract the body (markdown content after the frontmatter separator).
3. Call `board_get_ticket(ticket_id=<id>)`:
   - If 404 (not found): call `board_create_ticket` with parsed fields + body. Log: `CREATED <id>`.
   - If 200 (exists): compare key fields (status, owner, acceptance, depends_on). If any differ: call `board_update_ticket` with the markdown values. Log: `UPDATED <id>` or `OK <id>`.

## Step 4 — Report

Append to `memory/YYYY-MM-DD.md`:
- Total tickets processed
- Count of CREATED / UPDATED / OK
- Any errors

## On-error

- If board-api returns error on a specific ticket: log it, continue with the rest.
- If board-api is completely unreachable: abort with message "board-api unreachable — retry when service is healthy".

Return "DONE".

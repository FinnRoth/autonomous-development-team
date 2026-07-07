---
name: weekly-status
description: Generate a user-facing weekly summary from board-api, handoff-log.md, and decision-log.md; send as a handoff to user.
trigger: Heartbeat detects 7 days since last weekly-status run; or user asks for status explicitly.
inputs: board-api (board_get_board, board_list_tickets), docs/handoff-log.md, docs/project/decision-log.md, docs/project/risk-register.md.
outputs: outbound handoff message to user with the summary; entry in docs/handoff-log.md.
---

# weekly-status — deterministic procedure

## Step 1 — Compute the window

- `window_end` = now (ISO).
- `window_start` = now - 7 days (ISO).
- ISO week label, e.g. `2026-W26`.

## Step 2 — Aggregate the board

Call `board_get_board()` to get the full board snapshot and `board_list_tickets()` to get all tickets. Count:

- Stories with `status: done` and `updated_at` within window.
- Stories with `status: in_progress` and `updated_at` within window.
- Stories currently `blocked`.
- Bugs (type `bug`) opened (`created_at` in window) and closed (`status: done`, `updated_at` in window).

## Step 3 — Aggregate handoffs

`git log --since=window_start docs/handoff-log.md` — count entries by from/to pair. Spot any agent that has not produced or received anything in the window (potential stuck agent).

## Step 4 — Aggregate decisions

Read `decision-log.md`. List decisions made in window.

## Step 5 — Aggregate risks

Read `risk-register.md`. List:

- Risks newly opened in window.
- Risks whose review_by is within next 7 days.
- Risks status-changed in window.

## Step 6 — Aggregate open escalations to user

Scan `outbox/` for messages with `to: "user"` and `type: "escalation"` that have not yet received a user-channel acknowledgment (tracked in `memory/escalation-state.json`).

## Step 7 — Compose the summary

Format (markdown, brief, scannable):

```markdown
# Project status — week <ISO-week>

**Window:** <window_start> → <window_end>

## Headline

<one sentence: "On track" / "At risk" / "Off track because <X>">

## What landed

- STORY-XX: <title> — done
- STORY-YY: <title> — done
- BUG-ZZ: <title> — closed

## In flight

- STORY-AA: <title> — in_progress (<owner>, started <date>)
- STORY-BB: <title> — in_review (<owner>)

## Blocked / your input needed

- <ticket> — blocked because <reason>; pending: <what or who>
- Open escalation(s) awaiting your decision:
  1. <escalation summary> — see message <ISO timestamp>

## Risks

- New: <list>
- Closing watch this week: <list>

## Decisions you made

- <D-id>: <one-line>

## What's next (planned for next week)

- <ticket(s) the team will pick up>
```

Constraints:
- Keep total length ≤ 400 words.
- No agent IDs without their human-friendly name in parentheses on first mention this week (e.g., `backend (Forge)`).
- Never include code, configs, or stack traces. Link to the ticket instead.

## Step 8 — Send

Write `outbox/<ISO>-user-handoff.json`:

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "user",
  "ticket_id": "weekly-status-<ISO-week>",
  "artifact_paths": [],
  "summary": "<headline line>",
  "acceptance": ["user acknowledges or replies with direction"],
  "blocking_questions": [
    "<any decisions you need from user, one per item>"
  ]
}
```

The full markdown body goes in the message body (the OpenClaw gateway carries both structured JSON and a human-readable rendering).

## Step 9 — Update state

Append to `memory/weekly-status-state.json`:

```json
{
  "last_sent": "<ISO>",
  "week": "<ISO-week>"
}
```

Append to `docs/handoff-log.md`:

```
<ISO> | project-lead → user | handoff | weekly-status-<ISO-week> | "<headline>"
```

## On-error

- Board returns no tickets at all → still send the summary; headline = "Quiet week. Blockers: <list>". Do not skip the user check-in.
- Multiple unanswered escalations to user → group them in one numbered list under "your input needed".
- board-api unreachable → retry once after 30 s; if still failing, escalate to user before sending partial summary.

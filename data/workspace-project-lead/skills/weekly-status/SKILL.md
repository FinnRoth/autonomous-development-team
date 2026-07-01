---
name: weekly-status
description: Generate a user-facing weekly summary from docs/board.md, handoff-log.md, and decision-log.md; send as a handoff to user.
trigger: Heartbeat detects 7 days since last weekly-status run; or user asks for status explicitly.
inputs: docs/board.md, docs/handoff-log.md, docs/project/decision-log.md, docs/project/risk-register.md.
outputs: outbound handoff message to user with the summary; entry in docs/handoff-log.md.
---

# weekly-status — deterministic procedure

## Step 1 — Compute the window

- `window_end` = now (ISO).
- `window_start` = now - 7 days (ISO).
- ISO week label, e.g. `2026-W26`.

## Step 2 — Aggregate the board

Read `docs/board.md`. Count:

- Stories that moved to `done` in window (cross-check via `git log --since=window_start docs/board.md`).
- Stories moved to `in_progress` in window.
- Stories currently `blocked`.
- Bugs opened in window, bugs closed in window.

If the board doesn't track timestamps directly, use `git log --since` on the board file and the tickets folder.

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
  "artifact_paths": ["docs/board.md"],
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

Commit and push docs.

## On-error

- No movement at all in window → still send the summary; headline = "Quiet week. Blockers: <list>". Do not skip the user check-in.
- Multiple unanswered escalations to user → group them in one numbered list under "your input needed".
- Board file corrupt → restore from git, then run.

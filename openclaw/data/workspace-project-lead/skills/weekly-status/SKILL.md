---
name: weekly-status
description: Generate a user-facing weekly summary from board-api and decision-log.md; deliver to the user via chat.
trigger: Heartbeat detects 7 days since last weekly-status run; or user asks for status explicitly.
inputs: board-api (board_get_board, board_list_tickets, board_get_ticket for comment/handoff history), docs/project/decision-log.md, docs/project/risk-register.md.
outputs: user-facing weekly summary delivered via chat.
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

Read the comment threads on active tickets via `board_get_ticket` (and `board_get_unread` for anything still unhandled). Count handoff comments by author/`to` pair within the window. Spot any agent that has neither posted nor received a comment in the window (potential stuck agent).

## Step 4 — Aggregate decisions

Read `decision-log.md`. List decisions made in window.

## Step 5 — Aggregate risks

Read `risk-register.md`. List:

- Risks newly opened in window.
- Risks whose review_by is within next 7 days.
- Risks status-changed in window.

## Step 6 — Aggregate open escalations to user

List escalations I have relayed to the user (via chat) that have not yet received a user-channel acknowledgment (tracked in `memory/escalation-state.json`, keyed by decision id from `decision-log.md`).

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

Deliver the full markdown summary to the user directly in **chat**. I am the only agent that addresses the user, and I do it via chat — not via a board-api comment (`to: "user"` is not valid) and not via a file. If any decisions are needed from the user, list them under "Blocked / your input needed" so the chat message carries both the status and the asks.

## Step 9 — Update state

Append to `memory/weekly-status-state.json`:

```json
{
  "last_sent": "<ISO>",
  "week": "<ISO-week>"
}
```

## On-error

- Board returns no tickets at all → still send the summary; headline = "Quiet week. Blockers: <list>". Do not skip the user check-in.
- Multiple unanswered escalations to user → group them in one numbered list under "your input needed".
- board-api unreachable → retry once after 30 s; if still failing, escalate to user before sending partial summary.

---
name: escalate-to-user
description: Format an escalation message to the user and post it via the user channel; record it in the decision log as pending.
trigger: Scope/budget/deadline change needed; architect feasibility blocker beyond my authority; QA P0/P1 risking deadline; any agent-to-agent deadlock I cannot break; user input genuinely required.
inputs: A subject, options (≥2), and optionally my recommendation.
outputs: outbound escalation message to user; entry in decision-log.md as pending_user_confirmation; entry in handoff-log.md.
---

# escalate-to-user — deterministic procedure

## Step 1 — Confirm escalation is warranted

I do NOT escalate when:
- I can decide it myself within my authority (priorities of unstarted Stories within an Epic, ticket re-routing within the team, glossary additions).
- The escalation is really an `interrogate-user` task (a new feature) — use that skill instead.
- The escalation is asking the user to read something they already received — re-link, don't escalate.

I DO escalate when ANY of:
- Scope change (adding/removing a Story or Epic).
- Deadline change.
- Budget change.
- Stack change (after ADR-001).
- A trade-off where the user must choose (fix vs. ship, scope cut vs. slip).
- A risk has materialized that affects vision.md's "non-goals" boundary.
- An ADR amendment is needed.

## Step 2 — Draft the escalation

Required fields:

- **summary** — one line, plain English, ≤120 chars.
- **requested_decision** — phrased so the answer is one of the listed options.
- **options** — at least two, ideally three. Each option is a single sentence stating the trade-off (what we gain, what we give up).
- **recommendation** (optional but encouraged) — name one option and the reason in ≤30 words.
- **severity** — `low` (informational), `med` (decision needed within 7 days), `high` (within 2 days), `blocker` (work paused until decided).

Quality rules:
1. Never present an option as "do nothing" without naming what doing nothing costs.
2. Never present three options that all favor the same outcome — at least two must be meaningfully different.
3. Use the user's words from the most recent Q&A or chat whenever I'm referencing prior intent.

## Step 3 — Write the outbox file

`outbox/<ISO>-user-escalation.json`:

```json
{
  "type": "escalation",
  "from": "project-lead",
  "to": "user",
  "severity": "<low | med | high | blocker>",
  "summary": "<one-line>",
  "requested_decision": "<plain ask>",
  "options": [
    "Option A: <what we do — gain / give up>",
    "Option B: <what we do — gain / give up>"
  ],
  "recommendation": "<optional; option letter + reason>"
}
```

## Step 4 — Append to decision-log

Append to `docs/project/decision-log.md`:

```
<ISO> | D-NNN | pending_user_confirmation | <summary> | options: A=<…>, B=<…> | recommended: <letter or none>
```

`D-NNN` is the next decision id (count existing entries + 1).

## Step 5 — Append to handoff-log

```
<ISO> | project-lead → user | escalation | D-NNN | "<summary>"
```

## Step 6 — Commit docs

```
git add docs/project/decision-log.md docs/handoff-log.md
git commit -m "Escalation D-NNN: <summary>"
git push
```

## Step 7 — Update tracking

Append to `memory/escalation-state.json`:

```json
{
  "open": [
    {"id": "D-NNN", "sent": "<ISO>", "severity": "<…>", "summary": "<…>"}
  ]
}
```

When the user responds, the response goes into the next state's handling (REPLAN or back to MONITOR), and this entry moves from `open` to `resolved` with `resolution: <option chosen>` and a new immutable line in `decision-log.md`:

```
<ISO> | D-NNN | resolved | <summary> | chosen: <Option A | B | …> | <user verbatim>
```

## Step 8 — Pause dependent work

If severity is `high` or `blocker`:
1. Identify which tickets are blocked by this decision.
2. Call `board_transition_ticket(id=<ticket-id>, agent="project-lead", to="blocked")` for each blocked ticket.
3. Send a courtesy `question` to each blocked owner: "Paused pending user decision D-NNN. ETA on decision: <when>."

## Step 9 — Reminders

If user does not reply within the severity SLA:
- `low` → no reminder; surface in next `weekly-status`.
- `med` → one reminder after 5 days.
- `high` → one reminder after 1 day; if still silent at 2 days, repeat once.
- `blocker` → one reminder after 4 hours of work-day; thereafter once per day.

Reminders are short and reference the original escalation id:

> "Friendly nudge: decision D-NNN is still open (severity <…>). Original ask: <summary>. — Atlas 🧭"

## On-error

- Tried to escalate something I should have decided myself → catch in Step 1; abort and decide.
- Options list collapses to one real choice → reword as a `question` rather than escalation.
- User answers with something not in the options → treat as new intent: record their verbatim answer, ask one clarifying question, and re-issue the escalation if still ambiguous.

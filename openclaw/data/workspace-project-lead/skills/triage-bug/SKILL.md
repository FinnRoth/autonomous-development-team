---
name: triage-bug
description: Classify an incoming QA bug report into priority/owner/parent-story; create a BUG-* ticket in board-api; dispatch handoff to fix owner.
trigger: Inbox contains a `handoff` from `qa` with a path under `docs/qa/bug-reports/`.
inputs: The QA bug-report markdown file path (from handoff.artifact_paths). The current board state.
outputs: BUG-NN ticket created in board-api, outbound handoff to the fix owner, possible escalation to user if P0/P1 threatens deadline.
---

# triage-bug — deterministic procedure

## Step 1 — Read the bug report

Open the file under `docs/qa/bug-reports/`. Extract:

- **Summary** (one line).
- **Steps to reproduce** (numbered list).
- **Expected vs actual** behavior.
- **Affected ticket** (Story or Task id, if QA cited one).
- **Severity tag** from QA (`crash | data-loss | functional | cosmetic`).
- **Reproducibility** (`always | sometimes | once`).

If any of these fields is missing, send a `question` back to qa requesting the missing field and STOP this skill until they reply.

## Step 2 — Determine priority

Use this matrix exactly:

| QA severity | Reproducibility = always | sometimes | once |
|---|---|---|---|
| crash | P0 | P0 | P1 |
| data-loss | P0 | P1 | P1 |
| functional | P1 | P2 | P2 |
| cosmetic | P2 | P3 | P3 |

If the bug affects a Story whose parent Epic is `P0`, bump priority by one level (cap at P0).

## Step 3 — Determine owner

1. If QA cited an affected ticket → set owner to that ticket's owner.
2. Else, map by area of failure:
   - API/endpoint/DB/server error → `backend`
   - Rendering/state/client interaction → `frontend`
   - Visual/layout-only inconsistency with the spec → `uiux` (rare; usually wraps back to frontend after spec update)
   - Build/CI/repo config → `architect`
3. If unclear, default to `architect` and let them triage further.

## Step 4 — Decide: new ticket or attach to existing

- If there is an open Story with `status ∈ {in_progress, in_review, qa}` whose acceptance directly relates → attach: add a `## Bugs` section to that Story (via `board_update_ticket`) with a reference to the QA report path, AND still file a BUG-NN ticket in board-api as a `depends_on` for visibility.
- Otherwise → create a standalone BUG-NN ticket.

## Step 5 — Create BUG-NN in board-api

Query board-api for the next bug id: count existing tickets of type `bug` and use `BUG-` + (count + 1), zero-padded to two digits (e.g. `BUG-01`).

Call:

```
board_create_ticket({
  id: "BUG-NN",
  type: "bug",
  title: "<bug summary, ≤10 words, verb-first ('fix …', 'prevent …')>",
  parent: "<STORY-id this bug belongs to, or the Epic if no Story fits>",
  owner: "<agent id from Step 3>",
  status: "backlog",
  priority: "<P0|P1|P2|P3 from Step 2>",
  estimate: "S",
  acceptance: [
    "Steps to reproduce in <qa-report-path> no longer reproduce",
    "Regression test added (qa owns)"
  ],
  depends_on: [],
  blocks: [],
  body: "Source: <docs/qa/bug-reports/...md>\n\n## Summary\n<one-line>\n\n## Steps to reproduce\n<copy from QA report>\n\n## Expected\n<copy>\n\n## Actual\n<copy>\n\n## Triage notes\n- Priority derived from QA severity=<…>, reproducibility=<…>, parent Epic priority=<…>.\n- Owner chosen: <agent> because <reason>."
})
```

## Step 6 — Deadline impact check

If the new bug's priority is P0 or P1 AND there is an Epic with a deadline within 14 days AND this bug touches a Story in that Epic:

→ run the `escalate-to-user` skill with severity `high`, summarizing the trade-off (fix and slip vs. defer and ship). Recommend an option per `SOUL.md` heuristics. Do NOT decide yourself.

## Step 7 — Dispatch handoff to owner

Write `outbox/<ISO>-<owner>-handoff.json`:

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "<owner>",
  "ticket_id": "BUG-NN",
  "artifact_paths": [
    "<docs/qa/bug-reports/...md>"
  ],
  "summary": "<bug summary>; priority <P>; QA repro provided.",
  "acceptance": [
    "Steps to reproduce no longer reproduce",
    "Regression test added (qa owns post-fix)"
  ],
  "blocking_questions": []
}
```

Append to `docs/handoff-log.md`.

## Step 8 — Transition ticket to ready

After dispatching the handoff, update the ticket status in board-api:

```
board_update_ticket({ id: "BUG-NN", status: "ready" })
```

If a Story status must move to `blocked` because of this bug, update it via `board_update_ticket` as well.

## Step 9 — Commit handoff log

```
git add docs/handoff-log.md
git commit -m "[BUG-NN] Triage <summary> (P<n>, owner=<agent>)"
git push
```

## Step 10 — Acknowledge qa

Write `outbox/<ISO>-qa-handoff.json` acknowledgement:

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "qa",
  "ticket_id": "BUG-NN",
  "artifact_paths": [],
  "summary": "Triaged: priority <P>, owner <agent>. Await fix; please prepare regression test.",
  "acceptance": ["qa drafts regression test referencing BUG-NN once fix is in_review"],
  "blocking_questions": []
}
```

## On-error

- Multiple Stories plausibly affected → file BUG ticket against the deepest-parent Story; mention the other Story ids in the `body` field.
- Owner agent in STANDBY (no project) → impossible if onboarded; if it happens, escalate to user immediately.
- Bug repro relies on production data → ask qa for a sanitized repro before assigning fix owner.

# WORKFLOWS.md — Atlas's state machine

I move between seven named states. At any moment I am in exactly one. State transitions are deterministic: each state has an entry condition, an exit condition, a fixed action set, output artifacts, and on-error behavior.

The pre-onboarding STANDBY state from `CONVENTIONS.md` §9 also applies to me until the user has run `onboard-project`.

> **Path shorthand:** `docs/<docs-repo-name>/` = the primary docs-type repo clone (slug defined in `docs/<docs-repo-name>/project/repos.md`). Substitute the real slug from that file in all paths below. If the file does not exist yet, I am in STANDBY running `onboard-project`.

```
                ┌────────┐
                │  IDLE  │ ◀───────────────────────────┐
                └────┬───┘                             │
                     │ user intent received            │
                     ▼                                 │
              ┌─────────────┐                          │
              │ INTERROGATE │                          │
              └──────┬──────┘                          │
                     │ Q&A complete                    │
                     ▼                                 │
                ┌──────┐                               │
                │DRAFT │                               │
                └──┬───┘                               │
                   │ Epic + Stories drafted            │
                   ▼                                   │
        ┌──────────────────────────┐                   │
        │ REVIEW_WITH_ARCHITECT    │                   │
        └────────────┬─────────────┘                   │
                     │ feasibility approved            │
                     ▼                                 │
                ┌────────┐                             │
                │PUBLISH │                             │
                └───┬────┘                             │
                    │ tickets published                    │
                    ▼                                  │
                ┌────────┐                             │
                │MONITOR │ ──── stuck/regression ──▶ REPLAN
                └───┬────┘                             │
                    │ nothing actionable               │
                    └─────────────────────────────────▶┘
```

---

## 1. IDLE

- **Entry condition:** no pending user message; no actionable unread comment; board is healthy.
- **Exit condition:** user sends new intent OR an unread comment (from `board_get_unread`) demands routing.
- **Actions:**
  1. Reply `HEARTBEAT_OK` on heartbeat polls.
  2. Sleep until next stimulus.
- **Output artifacts:** none.
- **On error:** never errors. If somehow stuck, fall through to MONITOR.

## 2. INTERROGATE

- **Entry condition:** user expressed a new project, a new feature request, a change request, or asked an open-ended "can we…" question.
- **Exit condition:** the `interrogate-user` skill returns `Q&A: complete` (every checklist field has a non-vague answer or a recorded "user declined to answer").
- **Actions:**
  1. Open or create `docs/<docs-repo-name>/requirements/Q&A-<topic>.md`.
  2. Execute the `interrogate-user` skill end-to-end.
  3. After every user answer, re-read the prior answers for contradictions; flag and resolve before continuing.
  4. Do NOT yet write tickets or board entries.
- **Output artifacts:** `docs/<docs-repo-name>/requirements/Q&A-<topic>.md` (committed to docs repo).
- **On error:**
  - User unresponsive → wait one cycle, send one polite ping, then park in IDLE with a `memory/YYYY-MM-DD.md` note "interrogation paused on <topic>".
  - User contradicts themselves → ask them to choose; record both versions in Q&A with a timestamp; do not silently pick one.

## 3. DRAFT

- **Entry condition:** Q&A for the topic is `complete`.
- **Exit condition:** Epic + Stories drafted in memory, all Quality Gates 1–6 from `ROLE.md` pass, no Quality Gate 7 yet (that's for after REVIEW).
- **Actions:**
  1. Execute the `draft-epic` skill.
  2. Run the self-check from `ROLE.md` §Quality Gates (items 1–6).
  3. If a gate fails, fix and re-run the gate; do not proceed.
  4. Update `docs/<docs-repo-name>/project/glossary.md` with any new domain terms surfaced in Q&A.
  5. Update `docs/<docs-repo-name>/project/risk-register.md` with any new risks surfaced (status `open`, severity per my judgement).
- **Output artifacts:** `docs/<docs-repo-name>/project/glossary.md` (updated), `docs/<docs-repo-name>/project/risk-register.md` (updated). Ticket data exists only in the draft skill's working output — no markdown ticket files are written yet and no board-api calls are made until PUBLISH.
- **On error:** any quality gate failure → fix the offending ticket draft and re-run gate. If I cannot reconcile (e.g. ambiguity in Q&A), drop back to INTERROGATE for that gap.

## 4. REVIEW_WITH_ARCHITECT

- **Entry condition:** DRAFT exited cleanly.
- **Exit condition:** architect's `handoff` comment arrives (read via `board_get_unread`) pointing to `docs/<docs-repo-name>/architecture/feasibility-report-EPIC-NN.md` AND that file's frontmatter `status: approved` (or `approved_with_conditions` whose conditions I have logged in `decision-log.md`).
- **Actions:**
  1. Post a `handoff` comment to `architect` per `PROTOCOLS.md` §Handoffs I send.
  2. Stay in this state, polling `board_get_unread(agent="project-lead")` each cycle, up to 5 cycles before nudging.
  3. On architect reply:
     - `approved` → exit to PUBLISH.
     - `approved_with_conditions` → write conditions into `decision-log.md` as `pending_user_confirmation`, then run `escalate-to-user` skill; remain in this state until user confirms; then PUBLISH.
     - `rejected` → return to DRAFT with architect's feedback as additional Q&A material; may require return to INTERROGATE.
- **Output artifacts:** outbound `handoff` comment to architect, possibly `docs/<docs-repo-name>/project/decision-log.md`.
- **On error:**
  - Architect silent >5 cycles → post a `question` comment (nudge). After 10 cycles total, escalate to user.
  - Architect's report missing required fields → reply with a `question` comment citing missing fields.

## 5. PUBLISH

- **Entry condition:** REVIEW_WITH_ARCHITECT exit condition satisfied.
- **Exit condition:** tickets created in board-api, set to `ready`, and contextual starter handoffs dispatched.
- **Actions:**
  1. Re-run ALL 7 Quality Gates (now including the feasibility report gate).
  2. For each Epic and Story in the draft: call `board_create_ticket` with all ticket fields. Then call `board_transition_ticket` to move each ticket from `backlog` to `ready`.
  3. Dispatch contextual starter handoffs (as comments):
     - To `uiux` for any Story requiring UI work — a `handoff` comment referencing the Story id and the UX-relevant Q&A.
     - To `architect` for any Story requiring schema/contract authoring — a `handoff` comment referencing the Story.
     - Backend and frontend self-assign from board-api via their heartbeat poll. No explicit assignment handoff is needed. Tickets at `status: ready` with `owner: backend` or `owner: frontend` will be automatically claimed.
  4. `git add . && git commit && git push` on the docs repo (glossary, risk-register only — no ticket markdown files).
- **Output artifacts:** tickets created and transitioned in board-api, outbound `handoff` comments.
- **On error:**
  - Quality gate fails at publish time → do NOT create any board-api tickets; drop back to DRAFT.
  - `board_create_ticket` fails → retry once; if still failing, log to `memory/YYYY-MM-DD.md` and notify user via `escalate-to-user` with severity `med`.
  - Git push fails → retry once; if still failing, log to `memory/YYYY-MM-DD.md` and notify user via `escalate-to-user` with severity `med`.

## 6. MONITOR

- **Entry condition:** PUBLISH exited cleanly, OR I am in steady state with at least one open Epic.
- **Exit condition:** either (a) something needs my action and I transition to the appropriate state, or (b) there are no unread comments and board is healthy and I transition to IDLE.
- **Actions (every cycle):**
  1. Pull the docs repo (`git -C repos/<docs-slug> pull --ff-only`).
  2. Call `board_list_tickets(status="in_progress")` to get all in-progress tickets. Check `updated_at` field — tickets not updated in >24 cycles get a nudge.
  3. For each `in_progress` ticket whose `updated_at > 24 cycles ago`: post a `question` comment to its owner asking for status.
  4. For each `blocked` ticket: confirm the blocker is being addressed; if blocker is a user decision, ensure an open escalation exists. **Dispatch ALL other unblocked ready tasks immediately — do not let one blocked ticket stall the rest of the board.**
  5. Call `board_get_board()` and check for anomalies (stale tickets, unexpected statuses). No board.md file is written or regenerated.
  6. Process unread comments — call `board_get_unread(agent="project-lead")`. For each (in arrival order):
     - `handoff` from architect → may trigger return to REVIEW_WITH_ARCHITECT outcome handling.
     - `handoff` from reviewer (post-merge) → verify QA has received a handoff for the merged Story; if not, post a `handoff` comment to QA now.
     - `handoff` from qa (bug report) → run `triage-bug` skill → may create a new bug ticket via `board_create_ticket` → may trigger REPLAN.
     - `question` to me → reply with a `handoff` comment (decision) within 1 cycle if I can, else `escalate-to-user`.
     - `escalation` to me → if within my authority, decide and reply; else `escalate-to-user`.
     - **Any technical problem surfaced** (auth, build, env, contract) → delegate via a `handoff` comment to the correct technical agent. Never attempt to solve it myself.
     - After handling each, call `board_ack_comment(comment_id=<id>, agent="project-lead")`.
  7. If 7 days since last weekly summary, run `weekly-status` skill.
- **Output artifacts:** nudges (outbound `question` comments), possible new bug ticket in board-api, updated `risk-register.md`, possible `weekly-status` to user.
- **On error:**
  - Malformed comment → `board_ack_comment` it, log to daily memory, continue.
  - `board_get_board()` fails → retry once; if still failing, escalate to user.

## 7. REPLAN

- **Entry condition:** any of:
  - User changes scope/deadline/budget.
  - QA bug at priority P0 or P1 arrives as an unread `handoff` comment (via `board_get_unread`).
  - Architect rejects an in-flight Epic's feasibility mid-build.
- **Exit condition:** affected tickets updated in board-api, and a decision-log entry stating WHY the replan happened and WHAT changed.
- **Actions:**
  1. Pause any new dispatches (do not send new handoffs until REPLAN exits).
  2. Append a `decision-log.md` entry with timestamp, trigger, and proposed change.
  3. Determine impact: which Stories must be re-prioritized, deferred, or cancelled.
  4. Run `escalate-to-user` with the impact analysis and request explicit confirmation (no silent re-prioritization, ever).
  5. On user confirmation, call `board_transition_ticket` and/or `board_update_ticket` (priority, owner, depends_on) for every affected ticket.
  6. Re-run Quality Gates on every touched ticket draft before updating board-api.
  7. Push docs repo (decision-log only), then post revised `handoff` comments to affected agents.
- **Output artifacts:** tickets updated in board-api, new `decision-log.md` entry, outbound `escalate-to-user` message, outbound revised handoffs.
- **On error:**
  - User does not confirm within 3 cycles → send one polite reminder; if still no answer, do NOT proceed with replan; leave the team paused on the affected Stories and log the wait.
  - Conflicting user instructions → reply with a single clarifying question listing the conflict in plain words.

---

## STANDBY (pre-onboarding)

Applies until the user has run `onboard-project` (i.e. `repos/` does not yet exist).

- **Entry condition:** session start with no `repos/` directory.
- **Exit condition:** user provides project intent → trigger `onboard-project` skill → after success, transition to IDLE.
- **Actions:** wait. On any user message, respond by initiating the `onboard-project` skill.
- **Output artifacts:** none until onboarding starts.
- **On error:** never errors. STANDBY is the safe default.

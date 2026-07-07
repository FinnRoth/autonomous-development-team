# WORKFLOWS — Architect (Cassius 🏛️)

State machine. Each state has: name, entry condition, exit condition, actions, output artifacts, on-error.

Top-level cycle: `IDLE → INTAKE → ASSESS → DRAFT_ADR → SOLICIT_REVIEW → FREEZE → PROPAGATE → AUDIT → IDLE`.

`AUDIT` may loop back to `INTAKE` if it finds drift; otherwise returns to `IDLE`.

---

## 1. IDLE

- **Entry:** session start with no unprocessed `inbox/` items and no outstanding ADR in `proposed`.
- **Exit:** a new message lands in `inbox/`, OR `board_get_ready_tickets(owner="architect")` returns a non-empty result, OR a heartbeat triggers `AUDIT`.
- **Actions:**
  1. Read `ROLE.md`, `WORKFLOWS.md`, `CONVENTIONS.md`.
  2. `git -C repos/<docs-slug> pull --ff-only` (pull the docs repo; substitute slug from `docs/<docs-repo-name>/project/repos.md`).
  3. Call `board_list_tickets(owner="architect", status="ready")` — review any ready tickets assigned to me.
  4. Call `board_get_ready_tickets(owner="architect")` — if non-empty, pick the highest-priority ticket, call `board_claim_ticket`, and enter INTAKE state.
  5. Reply `HEARTBEAT_OK` if no work.
- **Output artifacts:** none.
- **On-error:** if `git pull` fails, file `question` to `project-lead` (severity not required for questions).

## 2. INTAKE

- **Entry:** at least one unprocessed file in `inbox/`, or a ticket was claimed via `board_claim_ticket` in IDLE.
- **Exit:** all `inbox/` messages classified and moved to `inbox/processed/` (archived, not deleted).
- **Actions:**
  1. For each message file, parse JSON and validate against the schema in `PROTOCOLS.md`.
  2. Classify: `handoff` → go to ASSESS; `question` → answer inline (no state transition needed beyond writing the reply to `outbox/`); `escalation` received → should not happen (I do not receive escalations as primary recipient). If received, forward to `project-lead`.
  3. If `handoff.ticket_id` references an Epic, scope = feasibility. If it references a Story/Task referencing a contract, scope = ADR-or-contract-change. Tag the work item accordingly.
  4. Call `board_transition_ticket(ticket_id=<TICKET-ID>, agent="architect", to="in_progress")`.
  5. Move processed message to `inbox/processed/<original-filename>`.
- **Output artifacts:** archived messages; possibly draft reply files in `outbox/`.
- **On-error:** unparsable message → write `escalation` to `project-lead` (`severity: low`, `requested_decision: "re-send valid message"`); move malformed file to `inbox/malformed/`.

## 3. ASSESS

- **Entry:** a `handoff` accepted in INTAKE, classified as feasibility or contract-change.
- **Exit:** an `assess-result` decision is locked: `(a) no-architecture-impact`, `(b) needs-ADR`, `(c) needs-feasibility-report-only`, or `(d) blocked-pending-clarification`.
- **Actions:**
  1. Read every artifact in `handoff.artifact_paths`.
  2. Cross-check against current `data-model.md`, `protocols.md`, `openapi.yaml`, and recent `accepted` ADRs.
  3. Use `sequential-thinking` MCP to enumerate at least 2 alternatives.
  4. Use `context7` MCP to verify any library/framework claim involved.
  5. If scope = Epic, invoke skill `architect-feasibility` and emit `feasibility-report-EPIC-NN.md`. Decide between (a)/(b)/(c)/(d).
  6. If scope = Story/Task contract change, decide if it fits within existing ADRs (path a), needs a new ADR (path b), or is blocked (path d).
- **Output artifacts:** `docs/architecture/feasibility-report-EPIC-NN.md` (when scope is Epic); a working-notes file in `memory/YYYY-MM-DD.md`.
- **On-error:**
  - Missing/unreadable artifact → `question` to sender asking for the exact path.
  - Requirement incompatible with stack → file `escalation` to `project-lead`, severity `high`, recommendation drawn from `architect-feasibility`.

## 4. DRAFT_ADR

- **Entry:** ASSESS exit = `needs-ADR`.
- **Exit:** ADR file exists at `docs/architecture/adr/ADR-NNN-<slug>.md` with `status: proposed`.
- **Actions:**
  1. Invoke skill `write-adr` with the decision input collected in ASSESS.
  2. ADR is numbered by `write-adr` (next free integer, zero-padded to 3).
  3. Frontmatter: `id`, `title`, `status: proposed`, `date: <today ISO>`, `supersedes: null` (or prior ADR id), `superseded_by: null`.
  4. Body sections required (in order): `Context`, `Decision`, `Consequences` (subsections `positive`, `negative`, `neutral`), `Alternatives`, `Related`.
  5. If the ADR implies an OpenAPI or data-model change, draft those changes in the **same branch** but commit them after ADR is accepted (see PROPAGATE).
  6. Commit ADR to a new branch `architect/<TICKET-ID>-ADR-NNN`.
- **Output artifacts:** ADR file; branch.
- **On-error:** numbering collision → re-scan adr/ and increment; never reuse a number.

## 5. SOLICIT_REVIEW

- **Entry:** ADR draft committed on a branch.
- **Exit:** Reviewer's verdict is `approve` (→ FREEZE) or `request_changes` (→ back to DRAFT_ADR).
- **Actions:**
  1. Push branch.
  2. Open PR against the `docs`-type repo's `main` branch. Title `[<TICKET-ID>] ADR-NNN: <title>`. Body lists Alternatives and key Consequences.
  3. Send `handoff` to `reviewer` with `artifact_paths: ["docs/<docs-repo-name>/architecture/adr/ADR-NNN-<slug>.md"]`.
  4. If the ADR is FE/BE-cross-cutting, also send `handoff` to `backend` and `frontend` with `type: handoff`, `acceptance: ["ack within 1 cycle: aligned or objection with rationale"]`.
  5. Call `board_transition_ticket(ticket_id=<TICKET-ID>, agent="architect", to="in_review")`.
  6. Wait for reviewer verdict (poll `inbox/`).
- **Output artifacts:** PR; one or more `handoff` outbox messages.
- **On-error:**
  - `request_changes` → return to DRAFT_ADR, update ADR (still `status: proposed`, keep id).
  - Two cycles without verdict → `question` to `project-lead`.

## 6. FREEZE

- **Entry:** Reviewer `approve` on the ADR PR.
- **Exit:** ADR is merged with `status: accepted` and any prior superseded ADR has its `superseded_by` field updated.
- **Actions:**
  1. Update ADR frontmatter: `status: accepted`.
  2. If this ADR supersedes a prior one, edit the prior ADR's frontmatter: set `superseded_by: ADR-NNN` and `status: superseded`. Do this in the **same PR**.
  3. Reviewer (not me) merges the PR.
  4. After merge, `git -C repos/<docs-slug> pull --ff-only`.
  5. Call `board_transition_ticket(ticket_id=<TICKET-ID>, agent="architect", to="done")`.
- **Output artifacts:** merged ADR; possibly modified prior ADR.
- **On-error:** if merge fails due to conflict, rebase and re-push. Do not force-push `main`.

## 7. PROPAGATE

- **Entry:** ADR is `accepted` on `main`.
- **Exit:** all dependent artifacts updated; FE/BE notified; generated contracts committed and pushed **before** I send the FE/BE handoffs.
- **Actions:**
  1. If the ADR mandates an OpenAPI change: edit `docs/<docs-repo-name>/architecture/api/openapi.yaml`, run skill `validate-openapi`, run skill `generate-contracts`, commit on a new branch, open PR. **Do NOT send FE/BE handoffs until the contracts PR is merged and contracts are on `main`.**
  2. If the ADR mandates a data-model change: run skill `propose-data-model-change`, regenerate Mermaid ER, commit, open PR.
  3. If the ADR mandates a folder layout change: edit `docs/<docs-repo-name>/architecture/folder-structure.md`, commit `.gitkeep` skeleton files into the relevant `code`-type repos on new branches, open PRs.
  4. After all PRs are merged: send `handoff` to `backend` AND `frontend` summarizing what changed, pointing to the merged ADR + contracts paths, and explicitly stating: "Generated contracts at `.architecture/contracts/` in the relevant code repo are ready. Pull `main` before starting."
  5. Call `board_transition_ticket(ticket_id=<TICKET-ID>, agent="architect", to="done")` after all propagation PRs are merged and handoffs are sent.
  6. **Compatibility note in handoffs:** every PROPAGATE handoff must include a section `## Compatibility` listing: which API operations changed (added/removed/modified), which types changed, and which existing callers (if any) need updates. Backend and frontend must acknowledge receipt before starting work on affected tickets.
- **Output artifacts:** OpenAPI updates; data-model updates; folder-structure updates; regenerated contracts; outbound handoffs.
- **On-error:**
  - `validate-openapi` fails → revert OpenAPI change, file `escalation` (`severity: med`) to `project-lead`.
  - `generate-contracts` produces non-empty diff after a re-run → contracts generator is non-idempotent; `escalation` (`severity: med`).

## 8. AUDIT

- **Entry:** scheduled (~weekly heartbeat) OR a QA/Reviewer escalation forwarded by PL says "contract drift".
- **Exit:** drift report produced; if drift exists, re-enter INTAKE with the drift as a self-issued handoff.
- **Actions:**
  1. Run `audit-folder-structure`. Report deltas.
  2. Run `validate-openapi`.
  3. Run `generate-contracts` and check diff. Non-empty = drift.
  4. Spot-check three random `accepted` ADRs: their `Decision` still observable in code/contracts?
  5. **Frontend–backend compatibility check:** run `generate-contracts` against the current `openapi.yaml`. Compare the generated types against what both the backend subtree and the frontend subtree import from `.architecture/contracts/` in their respective code repos. Any mismatch = contract drift.
  6. Write `docs/<docs-repo-name>/architecture/audit-<YYYY-MM-DD>.md` summarizing all findings including compatibility status.
- **Output artifacts:** `docs/<docs-repo-name>/architecture/audit-<YYYY-MM-DD>.md`.
- **On-error:** if any tool errors, file `question` to `project-lead`. Never skip the audit silently.

---

## Cross-cutting rules

- I never run two writing states in parallel on the same artifact.
- A `handoff` reply is sent in **every** terminal state transition that resolves the originating ticket.
- Every state writes a one-line entry to `memory/YYYY-MM-DD.md` so I can reconstruct the day.
- If I am uncertain which state I am in on wake, I scan `outbox/` for the last 24h and `docs/<docs-repo-name>/architecture/adr/` for any `proposed` ADR, then resume.
- **Contracts always precede feature work.** Generated contracts in `.architecture/contracts/` (inside the relevant code repo) must be on `main` BEFORE either backend or frontend claims a ticket that depends on them. If a developer claims a ticket and contracts are not yet available, I file a `question` to that developer flagging the dependency.

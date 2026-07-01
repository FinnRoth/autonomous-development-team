---
name: claim-task
description: Claim an assigned frontend ticket and prepare a working branch.
trigger: A handoff with ticket_id arrives from project-lead (or QA bug), or a ready ticket with owner=frontend is found on docs/board.md.
inputs: docs/tickets/<TICKET-ID>.md; docs/board.md; ROLE.md; CONVENTIONS.md
outputs: Updated ticket frontmatter (status=in_progress); local working branch frontend/<TICKET-ID>-<slug> pushed with upstream set.
---

# claim-task

Deterministic procedure for entering State 2 — CLAIM_TASK (see WORKFLOWS.md).

1. **Read the ticket.** Open `docs/tickets/<TICKET-ID>.md`. Verify the frontmatter contains: `id`, `type`, `title`, `parent`, `owner`, `status`, `priority`, `estimate`, `created`, `acceptance` (non-empty list), `depends_on`, `blocks` (CONVENTIONS.md §3). If any field is malformed, STOP and send an `escalation` to `project-lead` severity=`med` with `summary` "Malformed ticket frontmatter".

2. **Verify ownership.** Confirm `owner: frontend` OR confirm a `handoff` from `project-lead` reassigning to me exists in `inbox/`. If neither, STOP — do not claim.

3. **Verify status.** Confirm `status: ready`. If not, STOP — do not claim. (CONVENTIONS.md §6.9.)

4. **Verify dependencies.** For each id in `depends_on`, open `docs/tickets/<id>.md` and confirm `status: done`. If any dependency is not `done`, STOP — leave the ticket in `ready` and continue scanning the inbox.

5. **Read the spec surface.** For each `P-NN` referenced in the ticket body or acceptance, open `docs/ui/pages/P-NN.md`. Open `docs/ui/ui-spec.md` at the cited §s. Open `docs/ui/components.md` and `docs/ui/design-tokens.json`. If the ticket touches data, open `docs/architecture/openapi.yaml` and confirm the relevant endpoints exist in `project/.architecture/contracts/` (generated client). Open relevant ADRs under `docs/architecture/adr/`.

6. **Acceptance auditable from FE.** Walk each acceptance bullet. If any is server-only or untestable from FE alone, STOP and file an `escalation` to `project-lead` severity=`med` requesting a rewrite or split.

7. **Compute slug.** `<slug>` = lowercase, hyphen-joined first 4-6 words of ticket `title`, alphanumerics + hyphens only. Example: `TASK-31` "Add onboarding error banner" → `add-onboarding-error-banner`.

8. **Update ticket frontmatter.** In `docs/` repo, set `status: in_progress`. Commit with subject `[<TICKET-ID>] claim — start work`. Push.

9. **Create branch.** In `project/` repo:
   - `git fetch origin`
   - `git checkout main && git pull --ff-only`
   - `git switch -c frontend/<TICKET-ID>-<slug>`
   - `git push -u origin frontend/<TICKET-ID>-<slug>`

10. **Log to memory.** Append to `memory/YYYY-MM-DD.md`: ISO timestamp, ticket id, branch name, summary of consumed artifacts.

11. **Hand off control to `scaffold-page`/`scaffold-component`.** Proceed to State 3 — IMPLEMENT.

## On error

- Branch already exists locally and is mine and clean → reuse (`git switch frontend/<TICKET-ID>-<slug>`).
- Branch exists on remote with foreign commits → STOP, file `escalation` severity=`high` to project-lead.
- `main` cannot fast-forward → `git pull --rebase origin main` only on the feature branch, never on `main`.

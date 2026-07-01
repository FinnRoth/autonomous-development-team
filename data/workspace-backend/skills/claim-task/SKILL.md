---
name: claim-task
description: Move an assigned ticket from ready to in_progress and create a working branch.
trigger: A ticket in docs/board.md has owner=backend, status=ready, all depends_on are done, and the IDLE state selected it.
inputs: TICKET_ID (e.g. TASK-12)
outputs: docs commit flipping ticket status; local branch backend/<TICKET-ID>-<slug>; memory note with ticket body and acceptance.
---

# claim-task

Deterministic procedure. Run from workspace root.

1. **Pull docs**
   ```sh
   cd docs && git pull --ff-only
   ```
   On non-fast-forward: STOP, file `escalation` to project-lead, abort.

2. **Verify the ticket file exists**
   ```sh
   test -f docs/tickets/<TICKET-ID>.md || { echo "ticket missing"; exit 1; }
   ```
   If missing: STOP, file `question` to project-lead, abort.

3. **Verify ownership and state**
   - Parse YAML frontmatter of `docs/tickets/<TICKET-ID>.md`.
   - Assert `owner == "backend"`.
   - Assert `status == "ready"`.
   - For each id in `depends_on`: open `docs/tickets/<dep>.md` and assert `status == "done"`.
   - On any failure: STOP, file `escalation` to project-lead with the exact assertion that failed.

4. **Extract acceptance and ticket body** — store them in a local variable for step 9.

5. **Build the slug**
   - Lowercase the ticket title.
   - Replace non-alphanumerics with `-`.
   - Collapse runs of `-` to one.
   - Trim leading/trailing `-`.
   - Truncate to 40 chars at the last `-` boundary.

6. **Flip ticket status to in_progress**
   - Edit `docs/tickets/<TICKET-ID>.md`: set frontmatter `status: in_progress`.
   - Commit:
     ```sh
     cd docs
     git add tickets/<TICKET-ID>.md
     git commit -m "[<TICKET-ID>] backend claims ticket"
     git push
     ```
   - On push failure: pull, re-check ticket still claimable, retry once. Then escalate.

7. **Update local project repo**
   ```sh
   cd ../project
   git checkout main
   git pull --ff-only
   ```

8. **Create the branch**
   ```sh
   git checkout -b backend/<TICKET-ID>-<slug>
   ```
   On "branch exists": check out the existing branch with `git checkout backend/<TICKET-ID>-<slug>`; if its log shows unrelated commits, STOP and escalate.

9. **Print the contract to memory**
   - Append to `memory/YYYY-MM-DD.md`:
     - `claimed: <TICKET-ID> at <ISO>`
     - The full ticket body (after frontmatter).
     - The acceptance list verbatim — exact strings I will later paste into the PR body.
     - The branch name.
     - Pointers to consumed artifacts I will read in SPIKE: `docs/contracts/openapi.yaml`, `docs/architecture/data-model.md`, relevant ADRs, `docs/architecture/protocols.md`.

10. **Transition state** to `SPIKE` per WORKFLOWS.md §3.

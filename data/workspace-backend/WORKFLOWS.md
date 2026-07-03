# WORKFLOWS — Forge 🔧 (backend)

My state machine is per-ticket. At any time I may have at most one ticket in `CLAIM..MERGED` and one in `POST_MERGE`. New tickets queue in `IDLE`.

States flow strictly:

```
IDLE → CLAIM → SPIKE → IMPLEMENT → TEST → SELF_REVIEW → OPEN_PR → ADDRESS_REVIEW → MERGED → POST_MERGE → IDLE
```

`ADDRESS_REVIEW` loops back to itself until reviewer's verdict is `approve`. Any state may transition sideways to `BLOCKED` (a side state, not numbered here); recovery returns to the state I came from.

---

## 1. IDLE

- **Entry condition:** session start with no claimed ticket, OR I just finished `POST_MERGE`.
- **Exit condition:** I find a ticket in `docs/board.md` with `owner: backend`, `status: ready`, all `depends_on` are `done`, and the highest priority among such tickets — then I move to `CLAIM`.
- **Actions:**
  1. Run startup read order (see AGENTS.md).
  2. Process `inbox/` — for each message: handle or queue; archive to `inbox/archive/YYYY-MM-DD/`.
  3. `cd docs && git pull --ff-only`.
  4. Open `docs/board.md`; pick the next ticket per the exit condition.
  5. If no ticket: emit a heartbeat note in `memory/YYYY-MM-DD.md` and remain in IDLE.
- **Output artifacts:** none on disk beyond memory notes.
- **On-error:**
  - `git pull` fails → file `escalation` to `project-lead`, severity `med`, remain in IDLE.
  - Inbox message malformed → archive to `inbox/malformed/`, log in memory, continue.

---

## 2. CLAIM

- **Entry condition:** a ready ticket has been selected in IDLE.
- **Exit condition:** ticket status flipped to `in_progress`, branch created locally, working copy clean → move to `SPIKE`.
- **Actions:** run skill `claim-task` with `TICKET-ID`:
  1. `cd docs && git pull --ff-only`.
  2. Verify `docs/tickets/<ID>.md` exists, `owner: backend`, `status: ready`, all `depends_on` complete (cross-check `docs/board.md`).
  3. Edit `docs/tickets/<ID>.md` frontmatter: `status: in_progress`. Commit `[<ID>] claim` to `docs/`, push.
  4. `cd project && git checkout main && git pull --ff-only`.
  5. `git checkout -b backend/<ID>-<slug>` (slug = lowercase, kebab-case from ticket title, ≤ 40 chars).
  6. Print to my memory log: full ticket body, the acceptance checklist verbatim, and links to consumed artifacts.
- **Output artifacts:** docs commit flipping status; new local branch.
- **On-error:**
  - `depends_on` not done → revert any partial edits, file `escalation` to `project-lead` ("attempted to claim <ID> but <DEP> still <status>"), return to IDLE.
  - Branch already exists → checkout it; if it has unrelated commits, file `escalation` to `project-lead`.

---

## 3. SPIKE

- **Entry condition:** ticket claimed, branch checked out.
- **Exit condition:** I can describe in writing (in memory) every consumed contract artifact and have identified every file I will touch → move to `IMPLEMENT`.
- **Actions:**
  1. Read `docs/contracts/openapi.yaml` — locate every operationId implicated by the acceptance criteria.
  2. Read `docs/architecture/data-model.md` — identify entities/migrations needed.
  3. Read all relevant `docs/architecture/ADR-*.md` (especially stack, persistence, auth).
  4. Read `docs/architecture/protocols.md` if cross-service.
  5. For every third-party library I will call: `context7` resolve + query for current syntax.
  6. Write to `memory/YYYY-MM-DD.md`: ticket id, file plan (paths I will create/edit), migration plan (if any), open questions.
  7. If any open question is blocking, file a `question` and transition to `BLOCKED`; otherwise continue.
- **Output artifacts:** plan note in `memory/`.
- **On-error:**
  - Contract ambiguity → `question` to architect, → BLOCKED.
  - Acceptance contradictory → `question` to project-lead, → BLOCKED.

---

## 4. IMPLEMENT

- **Entry condition:** plan written; no blocking question outstanding.
- **Exit condition:** all planned files written/edited and a local smoke run (start the app, hit one happy-path endpoint or unit-call the new function) succeeds → move to `TEST`.
- **Actions:**
  1. For every new endpoint, run skill `scaffold-endpoint` with the operationId to get route+handler+test stub in the right folder per `docs/architecture/folder-structure.md`.
  2. For every schema delta announced by architect, run skill `write-migration`.
  3. Implement handlers, services, persistence.
  4. Wire DI/config explicitly — no globals.
  5. Update `.env.example` if new config keys; queue a `handoff` to architect (not sent yet — bundled with PR open).
  6. Commit incrementally with `[<ID>] <imperative>` subjects.
- **Output artifacts:** source under `project/backend/**`, migrations, possibly `.env.example` delta.
- **On-error:**
  - Need a new dependency → check ADRs; if uncovered, file `question` to architect, → BLOCKED.
  - Discover a contract bug → STOP, file `question` to architect, → BLOCKED.

---

## 5. TEST

- **Entry condition:** implementation complete, local smoke passed.
- **Exit condition:** lint, format, type-check, and tests for touched files all green → move to `SELF_REVIEW`.
- **Actions:** run skill `run-tests` in focus mode for touched files:
  1. Write/extend unit tests for every touched function.
  2. Write integration test per new endpoint (request → response, plus one error path).
  3. Run lint, format, type-check.
  4. Run focused test command on touched files; then full backend test suite.
  5. If a migration was added, run `migrate up` then `migrate down` then `migrate up` against a scratch DB and assert idempotency.
- **Output artifacts:** test files under `project/backend/tests/**`; CI-equivalent green log captured in memory.
- **On-error:**
  - A pre-existing test fails unrelated to my change → file `escalation` to `project-lead`, do NOT disable, → BLOCKED.
  - A test I wrote fails → fix code, not test (unless the test is wrong, in which case fix the test).

---

## 6. SELF_REVIEW

- **Entry condition:** all checks green.
- **Exit condition:** the `self-review` checklist is fully ticked → move to `OPEN_PR`.
- **Actions:** run skill `self-review`:
  1. `git diff --name-only origin/main..HEAD` — confirm every path is under `project/backend/`, `project/migrations/`, or `.env.example`. Any other path → STOP, escalate or revert.
  2. Re-run lint/format/type-check/tests.
  3. Verify migrations have `down`.
  4. Re-read PR template; confirm I can fill every section.
  5. Verify no new dependency lacks an ADR.
  6. Confirm acceptance checklist is satisfied or each unchecked item has a tracked `question`.
- **Output artifacts:** a self-review note in `memory/`.
- **On-error:** scope creep → revert offending files, optionally file a follow-up ticket idea to project-lead. Any failure returns me to `IMPLEMENT` or `TEST` as appropriate.

---

## 7. OPEN_PR

- **Entry condition:** self-review clean.
- **Exit condition:** PR opened, `handoff` sent to reviewer, ticket status flipped to `in_review` → move to `ADDRESS_REVIEW`.
- **Actions:** run skill `open-pr`:
  1. `git push -u origin backend/<ID>-<slug>`.
  2. Build PR body from template (Ticket link, Summary, Acceptance, Changes, Tests, Out-of-scope, Risks) using ticket + commit log.
  3. Open PR via host CLI; title `[<ID>] <imperative>`.
  4. Flip ticket status to `in_review` in `docs/tickets/<ID>.md`; commit + push to docs.
  5. Write `outbox/<ISO>-reviewer-handoff.json` per `PROTOCOLS.md`.
  6. If `.env.example` was changed, also write `outbox/<ISO>-architect-handoff.json` noting the env delta for re-blessing.
- **Output artifacts:** remote branch, open PR, docs commit, outbox messages.
- **On-error:** push rejected (branch protection / stale) → `git fetch && git rebase origin/main`, re-run tests, re-push. Repeated failure → `escalation` to project-lead.

---

## 8. ADDRESS_REVIEW

- **Entry condition:** PR is open, reviewer assigned.
- **Exit condition:** reviewer verdict is `approve` AND CI is green → move to `MERGED` (reviewer performs the merge; I do NOT self-merge per CONVENTIONS.md §13).
- **Actions:** loop:
  1. Watch `inbox/` and the PR thread (via `gh pr view <num> --comments`) for reviewer comments.
  2. **When reviewer posts a review (REQUEST_CHANGES or comments):**
     - Read **every** inline comment and the summary. Do not skip any.
     - Classify each item:
       - `[Required]` — MUST fix before re-requesting review. No exceptions.
       - `[Suggested]` — fix if it makes the code better in the current context; if not, reply explaining why it doesn't apply here (a justified decline is acceptable; silence is not).
       - `[Nit]` — fix or decline with a one-line reply; your call.
     - Run skill `address-review-comments`:
       1. Apply code changes for all Required items.
       2. Apply or consciously decline Suggested and Nit items; leave a reply on each declined item.
       3. Push all changes as one or more follow-up commits with `[<ID>] address review: <brief>` messages.
       4. Reply "addressed in <SHA>" on every Required thread. Reply to every Suggested/Nit thread with either the fix SHA or a brief rationale for decline.
     - After all threads are resolved, re-request review: `gh pr review --request-changes --body ""` followed by `gh pr request-review --reviewer <reviewer-agent-id>` (or equivalent for the git host).
  3. On `question` from reviewer → answer in PR thread; if it's a contract question, route to architect with a `question`.
  4. On `approve`: stop loop, mark internal state as approved, **do not merge**. Wait for reviewer to perform the merge.
- **Output artifacts:** follow-up commits, PR thread replies, optional question/escalation messages.
- **On-error:**
  - Reviewer asks for something that contradicts the ADR → file `escalation` to project-lead, citing both the reviewer comment and the ADR section.
  - Reviewer and I disagree after one back-and-forth → `escalation` to project-lead. I do NOT unilaterally override review comments.
  - CI fails on my fix push → fix CI before re-requesting review. Never re-request review with red CI.

---

## 9. MERGED

- **Entry condition:** PR merged into `main` by reviewer (or project-lead).
- **Exit condition:** local cleanup done → move to `POST_MERGE`.
- **Actions:**
  1. `git checkout main && git pull --ff-only`.
  2. `git branch -d backend/<ID>-<slug>`.
  3. `git push origin --delete backend/<ID>-<slug>` ONLY if branch is mine (it is).
  4. Update memory with merged SHA.
- **Output artifacts:** clean local repo.
- **On-error:** merge conflict on my branch before merge was actually a `ADDRESS_REVIEW` issue; if I'm in MERGED it shouldn't happen. If the remote branch can't be deleted (protected), leave it.

---

## 10. POST_MERGE

- **Entry condition:** branch cleanup done.
- **Exit condition:** QA handoff sent, ticket status `qa`, memory archived → return to IDLE.
- **Actions:**
  1. Flip ticket status to `qa` in `docs/tickets/<ID>.md`; commit + push docs.
  2. Write `outbox/<ISO>-qa-handoff.json` with the merged SHA, the acceptance criteria, and links to changed files.
  3. Append a post-mortem note to `MEMORY.md` (what was tricky, what I would do differently).
  4. Return to IDLE.
- **Output artifacts:** docs commit, qa handoff, memory entry.
- **On-error:** QA inbox missing → `escalation` to project-lead.

---

## BLOCKED (side state)

- **Entry:** any state where I filed a `question` or `escalation` whose answer I need before progressing.
- **Actions while blocked:**
  1. Do not advance the state machine.
  2. Poll `inbox/` for the reply.
  3. After 1 cycle without reply, send a follow-up `question` referencing the original.
  4. After 2 cycles without reply, `escalation` to project-lead.
- **Exit:** reply received → return to the originating state with new context.

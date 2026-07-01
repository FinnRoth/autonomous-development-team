# WORKFLOWS.md — Iris's State Machine

This is deterministic. Each state has an entry condition, exit condition, actions, output artifacts, and on-error behavior. I do not skip states.

Top-level cycle:

```
IDLE → INTAKE → PAGE_INVENTORY → FLOWS → WIREFRAMES → COMPONENT_PASS
     → STATES_PASS → TOKENS_PASS → SPEC_WRITE → FIGMA_SYNC → HANDOFF → REVISIONS → IDLE
```

`REVISIONS` is a re-entry state — it can fire from `HANDOFF` (frontend question), from QA (usability finding), or from `project-lead` (scope tweak). It loops back to whichever earlier state owns the artifact that needs changing.

---

## 1. IDLE

- **Entry condition:** No active Story/Epic assigned to me. `inbox/` empty of unhandled messages.
- **Exit condition:** A `handoff` from `project-lead` lands in `inbox/` with a Story or Epic ticket id; OR a `handoff` from `qa` with a usability finding (→ REVISIONS); OR a `question` from `frontend` (→ REVISIONS or answer directly).
- **Actions:**
  1. Run session startup (read `ROLE.md`, `WORKFLOWS.md`, `CONVENTIONS.md`, `PROTOCOLS.md`).
  2. `git -C docs/ pull --ff-only`.
  3. Scan `inbox/`. If empty, write a one-line entry to `memory/YYYY-MM-DD.md` and stop.
  4. If `docs/` does not exist → STANDBY (CONVENTIONS.md §9).
- **Output artifacts:** none (or a memory entry).
- **On-error:** if `git pull` fails (merge conflict in `docs/ui/**`), enter REVISIONS to resolve before doing anything else.

## 2. INTAKE

- **Entry condition:** A `handoff` from `project-lead` exists in `inbox/` with `ticket_id` pointing to a Story or Epic.
- **Exit condition:** I have a written acceptance summary in `memory/YYYY-MM-DD.md` and a branch `uiux/<TICKET-ID>-<slug>` checked out on `docs/`.
- **Actions:**
  1. Read the ticket file `docs/tickets/<TICKET-ID>.md`. Copy the `acceptance:` block verbatim to memory (CONVENTIONS.md §6.8).
  2. Read `docs/requirements/*` referenced in the handoff.
  3. Read `docs/architecture/data-model.md` and `docs/architecture/openapi.yaml`. List every entity and endpoint this Story touches.
  4. If any data shape is ambiguous → file a `question` to `architect` and **stay in INTAKE** (do not proceed). Update ticket `status: blocked`.
  5. Update ticket `status: in_progress`. Commit.
  6. Create branch `uiux/<TICKET-ID>-<slug>` from default branch.
  7. Archive the handoff to `inbox/archive/`.
- **Output artifacts:** memory entry; ticket status update; new branch.
- **On-error:** If acceptance criteria are untestable / contradictory → `escalation` to `project-lead`, `severity: high`. Set ticket `status: blocked`. Stay in INTAKE until resolved.

## 3. PAGE_INVENTORY

- **Entry condition:** INTAKE complete; data shapes clear.
- **Exit condition:** `docs/ui/pages/<page>.md` exists for every page implied by the Story, each with full frontmatter; `§1 Pages` of `ui-spec.md` updated with one row per new page.
- **Actions:**
  1. Run skill `inventory-pages` with the Story id as input.
  2. For each new page: allocate the next P-NN id (monotonic across the project, never reuse).
  3. Create `docs/ui/pages/<page>.md` with frontmatter (`id`, `name`, `route`, `owner_story`, `wireframe`, `figma_frame` — `figma_frame` may be `TBD` here; WIREFRAMES/FIGMA_SYNC will fill it).
  4. Append rows to `§1 Pages` in `docs/ui/ui-spec.md`. Sort by P-NN ascending.
  5. Commit: `[<TICKET-ID>] inventory pages` (CONVENTIONS.md §2 branch & PR naming).
- **Output artifacts:** `docs/ui/pages/P-NN.md` (new), `docs/ui/ui-spec.md` (updated §1).
- **On-error:** If two pages collide on the same `route` → use a sub-route; if neither feels right, `escalation` to `project-lead`.

## 4. FLOWS

- **Entry condition:** PAGE_INVENTORY complete.
- **Exit condition:** Every user-facing flow implied by the Story has a `docs/ui/flows/F-NN.md` file with a success row AND an error row; `§2 Flows` table in `ui-spec.md` updated.
- **Actions:**
  1. Run skill `draft-flow` for each distinct flow (entry, primary task, recovery, sign-out, etc.).
  2. For each flow: F-NN id, trigger, sequence (numbered steps referencing P-NN), success outcome, error outcome.
  3. Append rows to `§2 Flows`. Sort by F-NN ascending.
  4. Commit: `[<TICKET-ID>] draft flows`.
- **Output artifacts:** `docs/ui/flows/F-NN.md` (new), `docs/ui/ui-spec.md` (updated §2).
- **On-error:** If a flow's error branch requires a page I have not inventoried, return to PAGE_INVENTORY for that page only.

## 5. WIREFRAMES

- **Entry condition:** FLOWS complete.
- **Exit condition:** Every page in `§1 Pages` has both `docs/ui/wireframes/<P-NN>.png` and `docs/ui/wireframes/<P-NN>.svg`.
- **Actions:**
  1. For each P-NN: draft wireframe in Figma frame `P-NN — <page name>` (size 1440×900 desktop or 390×844 mobile per the route).
  2. Run skill `figma-sync` to export PNG (2x) + SVG into `docs/ui/wireframes/`.
  3. Update each page file's `figma_frame` URL.
  4. Commit: `[<TICKET-ID>] wireframes`.
- **Output artifacts:** wireframe PNG+SVG files; updated page frontmatter.
- **On-error:** If a wireframe requires a component not yet in `components.md`, defer (go to COMPONENT_PASS first, then return).

## 6. COMPONENT_PASS

- **Entry condition:** WIREFRAMES complete (or a wireframe revealed a missing component).
- **Exit condition:** Every component used in any wireframe in scope is listed in `docs/ui/components.md` with name, purpose, props sketch, used-in pages.
- **Actions:**
  1. Diff component usage in wireframes against `docs/ui/components.md`.
  2. For each new component: append an entry; choose a name from the existing vocabulary if at all possible. **Do not add a near-duplicate** (e.g., `PrimaryButton` if `Button` with `variant: primary` already exists).
  3. Update `§3 Components` rows in `ui-spec.md`.
  4. Commit: `[<TICKET-ID>] components catalog`.
- **Output artifacts:** updated `components.md` and `ui-spec.md §3`.
- **On-error:** If a wireframe insists on a component shape that conflicts with the existing primitive, prefer the existing primitive and adjust the wireframe; or escalate if the wireframe is right and the primitive is wrong.

## 7. STATES_PASS

- **Entry condition:** COMPONENT_PASS complete.
- **Exit condition:** Every component (new or touched) has all 5 states filled in `docs/ui/states.md`: loading / empty / error / success / disabled. `n/a` allowed only with a written reason.
- **Actions:**
  1. Run skill `states-matrix` to emit blank entries for new components.
  2. Fill each state with a 1–3-line description, referencing a wireframe variant if visual.
  3. Update `§4 States Matrix` links in `ui-spec.md`.
  4. Commit: `[<TICKET-ID>] states matrix`.
- **Output artifacts:** updated `states.md`.
- **On-error:** If a component genuinely has no `empty` state (e.g., a non-list element), write `n/a — reason: not a list`. Bare `n/a` fails the quality gate.

## 8. TOKENS_PASS

- **Entry condition:** STATES_PASS complete.
- **Exit condition:** `docs/ui/design-tokens.json` validates against its schema; every wireframe/component reference uses a token name, not a raw value.
- **Actions:**
  1. Run skill `tokens-validate`.
  2. If a value is missing (e.g., a new accent color), add it to `design-tokens.json` with a semantic name (`color.accent.500`, not `color.purple-x`).
  3. Update `§5 Design Tokens` cross-reference in `ui-spec.md`.
  4. Commit: `[<TICKET-ID>] tokens`.
- **Output artifacts:** `design-tokens.json` (updated).
- **On-error:** `tokens-validate` fails → fix until it passes; never push a `handoff` with a token-validation failure.

## 9. SPEC_WRITE

- **Entry condition:** TOKENS_PASS complete.
- **Exit condition:** `lint-ui-spec` passes on `docs/ui/ui-spec.md` and §6 Accessibility, §7 Responsive, §8 Open questions are up to date.
- **Actions:**
  1. Re-read `ui-spec.md` end-to-end.
  2. Verify §6 Accessibility lists any per-page deviation (target: WCAG 2.1 AA floor).
  3. Verify §7 Responsive lists breakpoints used by the new pages.
  4. Update §8 Open questions: any unresolved `question` to `architect` listed as `state: open`; resolved ones as `state: answered` with the resolution sentence.
  5. Run skill `lint-ui-spec`.
  6. Commit: `[<TICKET-ID>] spec`.
- **Output artifacts:** updated `ui-spec.md`.
- **On-error:** lint failure → fix, do not advance.

## 10. FIGMA_SYNC

- **Entry condition:** SPEC_WRITE complete.
- **Exit condition:** Figma file `ADT/<project>` contains a frame named exactly `P-NN — <page name>` for every row in `§1 Pages`. No extra frames. No missing frames. Each `docs/ui/pages/<P-NN>.md` `figma_frame` URL is set.
- **Actions:**
  1. Run skill `figma-sync` in "push wireframes + pull export" mode.
  2. Verify 1:1 mapping; remove any orphan Figma frames (after archiving them).
  3. Commit any updated `figma_frame` URLs.
- **Output artifacts:** synced Figma frames; updated page frontmatter.
- **On-error:** Figma auth failure → check `FIGMA_TOKEN`; if persistent, `escalation` to `project-lead`.

## 11. HANDOFF

- **Entry condition:** All quality gates 1–10 from `ROLE.md` pass.
- **Exit condition:** A PR is open on `<project>-docs` for branch `uiux/<TICKET-ID>-<slug>`, AND an `outbox/<ISO>-frontend-handoff.json` is written, AND ticket `status: in_review`.
- **Actions:**
  1. Open PR. Title: `[<TICKET-ID>] UI spec for <slug>`. Body includes the verbatim Acceptance checklist from the ticket (CONVENTIONS.md §7.4).
  2. Write the `handoff` message (schema in PROTOCOLS.md): `from: uiux`, `to: frontend`, `ticket_id`, `artifact_paths` (page files, flow files, `ui-spec.md` pinned commit, `components.md`, `design-tokens.json`).
  3. Update ticket `status: in_review`.
  4. Log the handoff in `memory/YYYY-MM-DD.md`.
- **Output artifacts:** PR; outbox message; ticket status.
- **On-error:** If `reviewer` requests changes on the docs PR → REVISIONS.

## 12. REVISIONS

- **Entry condition:** Any of: `question` from `frontend`; `handoff` from `qa` with usability finding; `escalation` resolution from `project-lead` requiring spec change; `reviewer` change request on my PR; merge conflict on `docs/ui/**`.
- **Exit condition:** Triggering issue resolved AND quality gates still pass AND a fresh `handoff` (if recipients are blocked) is sent.
- **Actions:**
  1. Classify the trigger: which state's artifact needs to change?
  2. Return to the **earliest** state whose artifact is affected (e.g., a new component → COMPONENT_PASS; a missing flow error branch → FLOWS).
  3. Re-run states forward from there. Re-run `lint-ui-spec` and `tokens-validate` before exiting.
  4. If a `question` from `frontend` can be answered without changing artifacts, reply with a `question`-shaped response and stay in REVISIONS only long enough to log the answer in `§8 Open questions`.
- **Output artifacts:** updated artifacts; possibly a fresh `handoff` message.
- **On-error:** If REVISIONS reveals a true scope conflict → `escalation` to `project-lead`, return to IDLE after resolution.

---

## Cross-cutting rules

- I commit at the end of every state. No mega-commit at the end.
- I never skip a state. If a state has no work (e.g., no new components needed) I record "no-op" in the commit message and move on.
- I never enter HANDOFF with `§8 Open questions` containing any unresolved item that blocks the Story.
- Branches are always `uiux/<TICKET-ID>-<slug>` (CONVENTIONS.md §2).

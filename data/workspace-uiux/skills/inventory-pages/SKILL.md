---
name: inventory-pages
description: Turn a Story or set of Stories into a deterministic P-NN page list with route and owner-story.
trigger: WORKFLOWS.md state 3 (PAGE_INVENTORY); also invoked on REVISIONS when a flow reveals a missing page.
inputs: A ticket id (Story/Epic) OR a comma-separated list. Read access to `docs/tickets/`, `docs/requirements/`, `docs/architecture/data-model.md`, `docs/architecture/openapi.yaml`, `docs/ui/ui-spec.md`, `docs/ui/pages/`.
outputs: One `docs/ui/pages/P-NN.md` per new page (with full frontmatter), plus appended rows to §1 Pages in `docs/ui/ui-spec.md`.
---

# Skill: inventory-pages

Deterministic procedure. Do every step. Commit at the end.

## Steps

1. **Resolve scope.** Read `docs/tickets/<TICKET-ID>.md` for each input ticket. If the ticket is an Epic, also read every Story whose `parent` equals that Epic id.

2. **Extract user-facing screens.** From the ticket body + acceptance criteria, list every distinct screen the user must reach. Use these heuristics, in order:
   - Each acceptance criterion of the form "User can <verb> ..." implies at least one screen.
   - Each entity in `data-model.md` that the Story touches usually implies a list view AND a detail/edit view, unless the Story says otherwise.
   - Each "settings / profile / billing / preferences" mention implies one settings sub-page.
   - Sign-in / sign-up / forgot-password are separate screens unless explicitly combined.

3. **Deduplicate against existing pages.** Read `docs/ui/ui-spec.md` §1 Pages. For each candidate screen, check by `route` and by `name`. If a match exists, do NOT create a new page; reuse the existing P-NN.

4. **Allocate P-NN ids.** Determine the highest existing `P-NN` in §1 Pages (default `P-00`). Allocate the next monotonic ids in order of the candidate list. Never reuse a deprecated id.

5. **Decide each route.** Use these rules:
   - Public surfaces: `/`, `/about`, `/pricing`, `/sign-in`, `/sign-up`, `/forgot-password`.
   - Authed surfaces: `/app`, `/app/<feature>`, `/app/<feature>/<id>`.
   - Settings: `/settings/<area>`.
   - Lists vs detail: `/<noun-plural>` for list, `/<noun-plural>/<id>` for detail, `/<noun-plural>/new` for create.
   - Never use a verb in the route (`/edit-profile` ✗ → `/settings/profile` ✓).
   - Routes are kebab-case, never camelCase.

6. **Pick the owner story.** Each page MUST point to exactly one Story id (the one that introduces the page). If two Stories share the same screen, pick the earlier one and note the second in the page body.

7. **Write each page file** at `docs/ui/pages/<P-NN>.md` with frontmatter:

   ```yaml
   ---
   id: P-NN
   name: <Human Name>
   route: /path/here
   owner_story: STORY-NN
   wireframe: docs/ui/wireframes/P-NN.png
   figma_frame: TBD
   ---
   ```

   Followed by a body with these subsections (all required, even if short):
   - `## Purpose` — one sentence.
   - `## Primary action` — what the user is most likely there to do.
   - `## Data dependencies` — entities/endpoints from data-model.md / openapi.yaml.
   - `## Components used` — list of component names from `components.md` (may be `TBD` at this state; COMPONENT_PASS fills it).
   - `## Notes` — anything odd.

8. **Update §1 Pages in `docs/ui/ui-spec.md`.** Append a row per new page:

   | id | name | route | owner-story | wireframe-path |
   |---|---|---|---|---|
   | P-NN | <name> | /path | STORY-NN | docs/ui/wireframes/P-NN.png |

   Sort by P-NN ascending. Do not edit other sections.

9. **Lint check.** Run skill `lint-ui-spec` and stop if it fails.

10. **Commit.** `[<TICKET-ID>] inventory pages: add P-NN..P-MM` on branch `uiux/<TICKET-ID>-<slug>`.

## Failure modes

- Two pages collide on the same route → use a sub-route; if neither sub-route reads right, send an `escalation` to `project-lead` (severity: low).
- A candidate screen has no clear owner Story → send a `question` to `project-lead`; do NOT invent a Story id.
- A page implies data not in `data-model.md` → send a `question` to `architect` and stop; the page file may exist as a stub with `figma_frame: TBD` only after the question is resolved.

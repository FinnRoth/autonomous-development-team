---
name: lint-ui-spec
description: Enforce the FROZEN canonical structure of `docs/ui/ui-spec.md` and check that every Story has at least one page.
trigger: End of every WORKFLOWS state that touches `ui-spec.md`; mandatory before HANDOFF (state 11).
inputs: Read access to `docs/ui/ui-spec.md`, `docs/ui/pages/`, `docs/ui/flows/`. Board-api access for story cross-reference.
outputs: Pass/fail. On fail, a concrete list of violations printed to the agent log + a memory entry.
---

# Skill: lint-ui-spec

Pure validator. Never edits files. Either passes silently or fails with a numbered list of violations.

## Checks (run in order; report ALL failures, do not stop at the first)

1. **Section headings exist, in exact order, with exact spelling:**
   - `## §0 Conventions`
   - `## §1 Pages`
   - `## §2 Flows`
   - `## §3 Components`
   - `## §4 States Matrix`
   - `## §5 Design Tokens`
   - `## §6 Accessibility rules`
   - `## §7 Responsive rules`
   - `## §8 Open questions`

   Any rename, reorder, deletion, or insertion of a new top-level §-section → FAIL with line number.

2. **§1 Pages table header** is exactly `| id | name | route | owner-story | wireframe-path |` (case + spacing exact). Each row has 5 cells. Each `id` matches `P-\d{2,}`.

3. **Each row of §1 Pages corresponds to an existing `docs/ui/pages/<P-NN>.md` file** AND that file has full frontmatter (`id`, `name`, `route`, `owner_story`, `wireframe`, `figma_frame`).

4. **Each P-NN file's `wireframe` path exists** on disk (both `.png` and `.svg` recommended; `.png` required, `.svg` warning if missing).

5. **Each P-NN file's `figma_frame`** is either a `https://www.figma.com/...` URL OR exactly `TBD` (allowed only outside HANDOFF state — FAIL on `TBD` during HANDOFF).

6. **§2 Flows table header** is exactly `| id | name | trigger | sequence | success | error |`. Each row has 6 cells. Each `id` matches `F-\d{2,}`.

7. **Each F-NN file** has H2 sections `## Trigger`, `## Sequence`, `## Success`, `## Error`, `## States touched`, `## Out of scope`. Missing any → FAIL.

8. **Every Story listed as `owner_story` in any P-NN file has a ticket in board-api.** Call `board_get_ticket(id=<STORY-ID>)` — 404 response → FAIL.

9. **Every Story with `type: story` AND `status` in {`ready`, `in_progress`, `in_review`, `qa`, `done`} (check via `board_list_tickets()`) has at least one P-NN file whose `owner_story` equals its id.** Backlog stories are exempt.

10. **§3 Components rows reference `docs/ui/states.md` entries** that exist for every listed component.

11. **§4 States Matrix links to `docs/ui/states.md`** and `states.md` contains an entry per component in §3 with all 5 keys (`loading`, `empty`, `error`, `success`, `disabled`). Empty value or missing key → FAIL. Value of `n/a` without a `reason:` field → FAIL.

12. **§5 Design Tokens** has a link to `docs/ui/design-tokens.json`. `tokens-validate` skill is invoked recursively; its failure is reported as part of `lint-ui-spec`'s failure set.

13. **§8 Open questions:** every entry has `state:` field in `{open, answered}`. During HANDOFF, no entry blocking the ticket id may be `state: open`.

## Pass behavior

- Exit code 0. Print: `lint-ui-spec: OK (<N pages>, <M flows>, <K components>)`.

## Fail behavior

- Exit code 1. Print numbered list of violations with file:line.
- Append to `memory/YYYY-MM-DD.md`: `lint-ui-spec FAIL — <count> violations on <commit>`.
- Do NOT commit. Do NOT proceed to HANDOFF.

## Bypass

There is no bypass. Fix the violations.

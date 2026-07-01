---
name: figma-sync
description: Push wireframes/mockups to Figma via the figma MCP; pull exported PNG+SVG into `docs/ui/wireframes/`; ensure 1:1 mapping between Figma frames and §1 Pages.
trigger: WORKFLOWS.md states 5 (WIREFRAMES) and 10 (FIGMA_SYNC). Also on REVISIONS after wireframe edits.
inputs: The set of P-NN ids in scope. Figma file `ADT/<project>`. Auth via `FIGMA_TOKEN` env var.
outputs: PNG + SVG files at `docs/ui/wireframes/<P-NN>.{png,svg}`; updated `figma_frame` URL in each P-NN page file; Figma file with exactly one frame per P-NN named `P-NN — <page name>`.
---

# Skill: figma-sync

Two modes: `push` (text spec → Figma frame skeleton) and `pull` (Figma frame → exported assets). Default behavior is **both**, push then pull.

## Steps

1. **Read inputs.**
   - List P-NN ids in scope.
   - For each P-NN, read `docs/ui/pages/<P-NN>.md` to get `name`, `route`, and `figma_frame` (may be `TBD`).
   - Confirm `FIGMA_TOKEN` is present in env. If missing → STOP; escalate to `project-lead`.

2. **List existing Figma frames** in `ADT/<project>` via the figma MCP. Build a map `{frame_name → frame_id}`.

3. **Diff sets:**
   - `desired`: `{"P-NN — <name>"}` for each in-scope P-NN.
   - `existing`: frames whose names start with `P-` (any suffix).
   - `to_create` = desired - existing.
   - `to_rename`: existing frames whose P-NN id matches but `<name>` part differs (rename, do not delete).
   - `orphan` = existing (P- prefix) - desired - to_rename. Do NOT delete; archive into a page named `_archive` inside Figma and log a memory entry.

4. **Create frames in `to_create`:**
   - Desktop pages (route does not start with `/m/` or `/mobile/`): 1440×900.
   - Mobile pages (route starts with `/m/` or `/mobile/`, or P-NN file metadata says `viewport: mobile`): 390×844.
   - Apply the design-system styles (color/typography tokens) on creation. Do not paint anything outside tokens.
   - Place all frames on a single Figma page named `Wireframes`.

5. **Push current wireframe content** to each frame (only if the agent has produced an updated draft locally — typically yes after WIREFRAMES state). The wireframe content comes from either the SVG sketch the agent prepared OR a from-scratch construction using tokenized primitives.

6. **Pull assets:**
   - For each in-scope P-NN frame, export PNG at 2x resolution to `docs/ui/wireframes/<P-NN>.png`.
   - Export SVG to `docs/ui/wireframes/<P-NN>.svg`.

7. **Update page frontmatter:**
   - For each P-NN, set `figma_frame` to the canonical URL `https://www.figma.com/file/<file_id>/ADT-<project>?node-id=<frame_id>`.

8. **Verify 1:1 mapping:**
   - For every row in §1 Pages of `ui-spec.md`, there is exactly one Figma frame `P-NN — <name>`.
   - For every Figma frame starting with `P-`, there is exactly one row in §1 Pages, OR it is on the `_archive` page.
   - Any mismatch → FAIL. Log violations; do NOT proceed to HANDOFF.

9. **Commit:**
   - `[<TICKET-ID>] figma sync: <N> frames, <M> assets`.
   - Files staged: `docs/ui/wireframes/**`, `docs/ui/pages/<P-NN>.md` for any updated `figma_frame`.

## Hard rules

- Never delete a Figma frame. Archive only.
- Never embed `FIGMA_TOKEN` in any committed file or memory entry. Refer to it as `<set-by-env>`.
- Never paint an ad-hoc color in a Figma frame. Use design-system styles bound to tokens.
- Never push if `tokens-validate` is failing — the Figma file would inherit non-conformant values.

## Failure modes

- Figma auth 401 → `FIGMA_TOKEN` invalid; `escalation` to `project-lead`.
- Rate limit (429) → back off and retry up to 3 times; if persistent, partial commit + memory entry, retry next cycle.
- Mapping diff produces > 5 orphan frames → STOP and `escalation` to `project-lead`; something larger is wrong.

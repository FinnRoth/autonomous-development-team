---
name: states-matrix
description: Emit a blank states matrix entry for each new component and refuse to advance until all 5 states are filled (or marked `n/a` with a written reason).
trigger: WORKFLOWS.md state 7 (STATES_PASS). Also on REVISIONS when a new component appears.
inputs: List of component names from `docs/ui/components.md` not yet present in `docs/ui/states.md`.
outputs: Updated `docs/ui/states.md` with all 5 keys for every component; FAIL signal if any state is unfilled.
---

# Skill: states-matrix

The five states are **fixed**: `loading`, `empty`, `error`, `success`, `disabled`. They are written in this order. Every component in `components.md` has an entry. There is no sixth state.

## Steps

1. **Diff.** Read `components.md`. Read `states.md`. Build the set of components missing in `states.md`.

2. **Emit blank entry** for each missing component:

   ```markdown
   ### <ComponentName>

   - **loading:** _TODO_
   - **empty:** _TODO_
   - **error:** _TODO_
   - **success:** _TODO_
   - **disabled:** _TODO_
   ```

   (Append; do not reorder existing entries.)

3. **Nag.** Print a one-line reminder per `_TODO_`:
   `states-matrix: <ComponentName>.<state> is _TODO_ — fill or mark "n/a — reason: ..."`.

4. **Validate.** Refuse to exit the skill with an "ok" status while any `_TODO_` remains.

## Filling rules (when the agent does the writing)

- Each state value is a 1–3-line description, may reference a wireframe variant ("see `docs/ui/wireframes/P-07.png` row 2").
- `loading`: what the user sees during async fetch. Default: Skeleton primitive in the same footprint as the loaded content. Never a centered spinner unless explicitly justified.
- `empty`: what the user sees with zero items. Use the `EmptyState` primitive. Must include a primary CTA OR explicit reason no CTA exists.
- `error`: what the user sees on a failure. Use `ErrorBoundary` primitive. Must include retry affordance OR explicit reason none is possible.
- `success`: what the user sees on completion. May be transient (toast) or persistent (banner). Reference the token used (e.g., `color.success.500`).
- `disabled`: what the user sees when the component is not interactive. Must define cursor, opacity token, and (if interactive) the reason shown on hover/focus.

## Allowed `n/a`

Only when a state is genuinely impossible. Format:

```markdown
- **empty:** n/a — reason: this component is not a list and cannot be empty
```

Bare `n/a` is a FAIL. The reason is mandatory.

## Forbidden

- New state keys (no `hovered`, `focused`, `pressed` at this level — those are component-internal, not lifecycle states).
- Removing a state from an existing entry.
- Filling with vague text ("looks good", "default styling", "TBD"). All FAIL.

## Output

- Updated `docs/ui/states.md`.
- Commit: `[<TICKET-ID>] states matrix: <N> components updated`.
- Exit code 0 only if every component in `components.md` has all 5 keys filled with non-TODO content.

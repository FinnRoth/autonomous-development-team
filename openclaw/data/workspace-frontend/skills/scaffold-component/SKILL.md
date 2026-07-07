---
name: scaffold-component
description: Generate a new component file (plus story/test) from an entry in components.md, with states-matrix tests.
trigger: State 3 — IMPLEMENT. The page or another component needs a component listed in components.md that doesn't exist in code yet.
inputs: docs/ui/components.md entry; docs/ui/design-tokens.json; docs/ui/states.md.
outputs: A component source file; a story/playground file (or framework equivalent); a test scaffold with the states matrix.
---

# scaffold-component

1. **Verify the entry exists.** Open `docs/ui/components.md` and locate the component by name. The entry must include: name, props table, tokens used, states catalog, accessibility notes, Figma frame. If anything is missing, STOP and file `question` to uiux.

2. **Compute file paths** per project convention (TOOLS.md Local notes). Typical:
   - `project/frontend/src/components/<Name>/<Name>.<ext>`
   - `project/frontend/src/components/<Name>/<Name>.stories.<ext>` (Storybook/Histoire/Ladle, if used)
   - `project/frontend/tests/components/<Name>.spec.<ext>`

3. **Top-of-file comment (mandatory).**

```
// Component: <Name>
// Spec: docs/ui/components.md §C-XX
// Figma: <frame URL>
```

4. **Props.** Implement exactly the props in the spec entry — same names, same types, same defaults. Required props are non-optional. Do not invent extra props.

5. **Tokens-only styling.** Pull colors/spacing/typography/radii/shadows from `design-tokens.json` via the project's token-access pattern (CSS vars, theme object, Tailwind class, etc.). No hex, no `rgb()`, no magic px. `tokens-lint` must pass immediately.

6. **State rendering.** Implement every state listed in the spec entry. The component must accept whatever prop drives state (commonly `status`, `disabled`, `loading`, `error`, etc.) per the spec.

7. **Accessibility.**
   - Semantic HTML root element (do not use `div` where `button`/`nav`/`section` applies).
   - ARIA attributes per spec entry.
   - Keyboard interaction implemented (Enter/Space for buttons, Esc for dismissibles, arrow keys for lists if applicable).
   - Visible focus ring via token.
   - Color contrast confirmed via tokens.

8. **Story / playground file.** One story per state listed in the spec entry. Each story uses props from the spec only.

9. **Test scaffold (states matrix).** Cases (one per state):
   - renders without crashing in default state
   - renders Loading state
   - renders Empty state
   - renders Error state
   - renders Success state
   - renders Disabled state
   - passes axe in each state
   - keyboard interactions work (Tab order, Enter/Space, Esc as applicable)

10. **i18n.** If the component renders any text via prop defaults, route through the i18n helper with keys from the project's component namespace.

11. **Run `tokens-lint`** on the new files. Zero violations.

12. **Commit.** Subject `[<TICKET-ID>] scaffold component <Name>`.

## On error

- Spec entry incomplete (no props table, no tokens listed, no states catalog) → STOP, `question` to uiux requesting the entry be fleshed out before I generate code.
- Token referenced in the entry doesn't exist in `design-tokens.json` → STOP, `question` to uiux.
- The component you're being asked to build is actually two components per the spec entry's "compose with" guidance → build the leaf components first or `question` to uiux for clarification on which is the leaf.

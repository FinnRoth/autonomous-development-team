---
name: scaffold-page
description: Generate a new page/route file from a P-NN spec, with all five state stubs and a routing entry.
trigger: State 3 — IMPLEMENT. Ticket references a P-NN that has no corresponding page file yet.
inputs: docs/ui/pages/P-NN.md; docs/ui/ui-spec.md; docs/ui/components.md; docs/ui/design-tokens.json; existing routing config under project/frontend/**; generated API client at project/.architecture/contracts/.
outputs: A page source file with top-of-file P-NN comment; five state branches; a routing entry; a test stub file under project/frontend/tests/.
---

# scaffold-page

1. **Read `docs/ui/pages/P-NN.md`.** Extract:
   - route path (e.g. `/onboard/start`)
   - title
   - layout / parent layout
   - components used (each must already be in `components.md`; if not, STOP and file `question` to uiux)
   - data dependencies (which API client functions are called)
   - states required (always Loading, Empty, Error, Success, Disabled — confirm spec or file `question`)
   - i18n key namespace

2. **Compute file path.** Per project FE conventions (recorded in `TOOLS.md` Local notes). Typical examples:
   - React Router: `project/frontend/src/pages/<route-folder>/index.tsx`
   - Next.js App Router: `project/frontend/src/app/<route>/page.tsx`
   - Vue Router: `project/frontend/src/pages/<route>/index.vue`
   - SvelteKit: `project/frontend/src/routes/<route>/+page.svelte`

3. **Top-of-file comment (mandatory).** Insert as the very first line(s) of the file:

```
// Spec: P-NN — docs/ui/pages/P-NN.md
// ui-spec §<numbers cited by the page>
// Figma: <frame URL>
```

4. **Imports.**
   - The relevant generated client functions from `project/.architecture/contracts/`. No raw fetch/axios.
   - Only components named in `docs/ui/components.md`.
   - The i18n helper.
   - Token utilities only — never inline color/spacing literals.

5. **Five-state stubs.** Emit a render structure that branches on `status ∈ {loading, empty, error, success, disabled}` (exact shape per project state-machine convention, e.g. tagged unions, React Query state, etc.). Each branch renders the component (from `components.md`) corresponding to that state per `docs/ui/states.md`. Provide a TODO comment ONLY inside `success` if the data shape isn't yet wired, and only with a JIRA-style `// TODO(<TICKET-ID>): wire success body`.

6. **Routing entry.** Update the project's routing config to register the route with the correct layout. Confirm no two routes resolve to the same path.

7. **i18n keys.** Create the namespace if absent. Add placeholder keys with English defaults exactly as written in `ui-spec.md` (do not paraphrase).

8. **Test stub.** Create `project/frontend/tests/pages/P-NN.spec.<ext>` with cases:
   - renders Loading
   - renders Empty
   - renders Error
   - renders Success (mocked client)
   - renders Disabled (mocked client returning `blockedReason`)
   - axe passes on each state (use the framework's a11y test helper)

9. **Run `tokens-lint`** on the new file immediately. Zero violations.

10. **Commit.** Subject `[<TICKET-ID>] scaffold page P-NN`.

## On error

- Component not in `components.md` → STOP, `question` to uiux. Ticket → BLOCKED.
- Token missing → STOP, `question` to uiux. Ticket → BLOCKED.
- Endpoint missing in generated client → STOP, `question` to architect. Ticket → BLOCKED.
- Route already exists → reuse, do not create a sibling; check if the existing file already references `P-NN`. If a different `P-NN`, escalate severity=`med` to project-lead.

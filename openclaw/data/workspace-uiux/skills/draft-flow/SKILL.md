---
name: draft-flow
description: Turn a textual user-story into a deterministic `docs/ui/flows/F-NN.md` with steps, success, and error branches.
trigger: WORKFLOWS.md state 4 (FLOWS). Also on REVISIONS when an error branch was missing.
inputs: A Story id and (optionally) a specific flow name (e.g., "add-payment-method"). Read access to ticket, page files, data-model.md, api/<service>/openapi.yaml.
outputs: One `docs/ui/flows/F-NN.md` per flow + appended row(s) to §2 Flows in `ui-spec.md`.
---

# Skill: draft-flow

Every flow MUST have a success row and an error row. No exceptions.

## Steps

1. **Identify flows in scope.** From the Story's acceptance criteria, list distinct user journeys. A journey is one if:
   - It has a single trigger (button press, route entry, redirect).
   - It ends in a single success outcome OR a known error outcome.
   - It can be tested as a unit.

2. **Allocate F-NN ids.** Read `docs/ui/ui-spec.md` §2 Flows for the highest existing `F-NN`. Allocate the next monotonic ids.

3. **For each flow, write `docs/ui/flows/<F-NN>.md`** with frontmatter:

   ```yaml
   ---
   id: F-NN
   name: <short name, kebab-case>
   trigger: <what starts the flow — be specific>
   owner_story: STORY-NN
   pages: [P-07, P-08]      # P-NN ids touched by the flow
   ---
   ```

   And body sections (ALL required):

   - `## Trigger`
     One sentence. e.g., "User clicks 'Add payment method' on P-07."

   - `## Sequence`
     Numbered list. Each step is `<P-NN>: <action> → <outcome>`. e.g.:
     1. P-07: user clicks "Add" → modal opens on top of P-07.
     2. P-07 (modal): user fills card details → submit enabled.
     3. POST `/payment-methods` → 201 → modal closes, list refreshes.

   - `## Success`
     One sentence describing the success outcome AND its visual signal (toast, route change, banner). Cite the token used.

   - `## Error`
     At least one error path. Format: `<error condition> → <user-visible result> → <recovery affordance>`. e.g.:
     - Network failure → ErrorBoundary toast (token `color.danger.500`) → "Retry" button focused.
     - 422 validation → inline field error, submit re-disabled until fixed.
     - 402 payment declined → modal stays open with declined-state banner; "Try another card" focused.

   - `## States touched`
     For each component used in the flow, list which of `loading | empty | error | success | disabled` are exercised.

   - `## Out of scope`
     Anything a reader might think is part of this flow but is not (e.g., "Editing existing payment method — see F-04").

4. **Update §2 Flows in `ui-spec.md`.** Append:

   | id | name | trigger | sequence | success | error |
   |---|---|---|---|---|---|
   | F-NN | <name> | <trigger short> | <P-NN → P-NN> | <success short> | <error short> |

   Sort by F-NN ascending.

5. **Cross-link.** Update each P-NN page file's body section `## Notes` to list the flow ids it participates in (e.g., "Flows: F-03 (add payment method), F-04 (remove payment method).").

6. **Lint.** Run `lint-ui-spec`. The lint MUST fail if any `F-NN.md` lacks a `## Success` or `## Error` heading.

7. **Commit.** `[<TICKET-ID>] flows: add F-NN..F-MM`.

## Hard rules

- A flow with no `## Error` section is invalid. If you genuinely cannot think of an error path, write `## Error\n- None: this flow has no failure mode beyond network loss → ErrorBoundary toast applies.` That counts; pure absence does not.
- Never list a step that references a page not yet inventoried — go back to PAGE_INVENTORY first.
- Never use raw color names in the success/error descriptions. Reference tokens by name (e.g., `color.danger.500`, not `red`).

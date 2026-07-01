---
name: self-review
description: Walk my own diff against Quality Gates and Forbidden Actions before opening a PR.
trigger: State 5 — SELF_REVIEW. After TEST is green.
inputs: Current branch diff vs main; docs/tickets/<TICKET-ID>.md; docs/ui/ui-spec.md, pages/, components.md, design-tokens.json; ROLE.md.
outputs: A pass/fail report appended to memory/YYYY-MM-DD.md; either green-light to OPEN_PR or a return-to-IMPLEMENT signal with concrete fixes.
---

# self-review

Deterministic checklist. Every line is a hard gate. Any FAIL → return to IMPLEMENT.

1. **Diff scope check.** Run `git diff --stat origin/main...HEAD`. Confirm changed files are exclusively under `project/frontend/**` (source or tests). Any file outside these paths → FAIL with "scope violation: <path>".

2. **Generated contracts untouched.** Run `git diff origin/main...HEAD -- project/.architecture/contracts/`. Must be empty. Any diff → FAIL with "hand-edited generated contracts forbidden (ROLE.md Forbidden #3)".

3. **Acceptance criteria mapping.** For each acceptance bullet in the ticket frontmatter, identify the file(s) that satisfy it. If any acceptance has no matching code → FAIL with "acceptance N not implemented".

4. **P-NN comment on new pages.** For each new file under a routing/pages directory, `head -n 5 <file>` must contain `Spec: P-NN`. Missing → FAIL.

5. **Component provenance.** Extract the import list from every changed file. For each component imported from a project path that isn't a third-party package, confirm its name appears in `docs/ui/components.md`. If not → FAIL with "component X not in components.md — file question to uiux".

6. **Token discipline.** Run the `tokens-lint` skill. Zero violations required. Any FAIL → FAIL.

7. **a11y discipline.**
   - Run the `axe-check` skill on each touched route. Zero violations required.
   - Grep changed files for `eslint-disable.*jsx-a11y` or `vue/.*-a11y` (or framework equivalents). Each disable must be followed by an inline comment with `ADR-<NN>`. Missing ADR ref → FAIL.

8. **Five states matrix.** For each touched page/component representing an async surface, open the file and confirm presence of Loading, Empty, Error, Success, Disabled rendering branches (visible in code; states-matrix tests pass). Missing any → FAIL.

9. **No business logic on client.** Grep the diff and apply these mechanical rules — no manual adjudication.

   PERMITTED in client code:
   - Pure formatting helpers documented with the comment `// display-only`.
   - Input masks.
   - Locale formatters from the shared i18n util.
   - Optimistic UI rollback.
   - Debounced search filtering on client-cached lists.

   FORBIDDEN (FAIL):
   - `.toFixed(N)` on a numeric value lacking a `// display-only` annotation.
   - Role/permission gating expressed as a JS comparison against a literal role string (e.g. `role === 'admin'`). Gating must come from a flag prop/hook supplied by the server.
   - Arithmetic on monetary values.
   - Date math.
   - Ordering rules.
   - Eligibility checks.
   - Pricing.

   Any forbidden hit → FAIL with "business logic must move server-side; file question to architect".

10. **No endpoints outside the generated client.** Grep for `fetch(`, `axios(`, `XMLHttpRequest`, framework-native HTTP helpers. Every hit must call into `project/.architecture/contracts/`. Direct URL strings → FAIL.

11. **i18n.** Grep changed files for user-facing string literals in JSX/template positions. Each must be wrapped via the project's i18n helper. Hardcoded user-facing strings → FAIL.

12. **No hex/rgb/magic px.** Already covered by tokens-lint; re-check by grepping the diff for `#[0-9A-Fa-f]{3,8}\b`, `rgb\(`, `rgba\(`, `hsl\(`, and `\d+px` outside of token files. Any hit → FAIL.

13. **Tests for every touched file.** For each changed source file under `project/frontend/src/**`, confirm a corresponding test file under `project/frontend/tests/**` exists and is also in the diff. Missing → FAIL.

14. **Commit subjects.** `git log --oneline origin/main..HEAD` — every subject must start with `[<TICKET-ID>] ` (CONVENTIONS.md §2). Wrong → FAIL.

Post-step (side-effect, not a gate): Append result to `memory/YYYY-MM-DD.md` with ISO timestamp, PASS/FAIL, and the failing rule(s) if any.

If all 14 checks PASS → proceed to OPEN_PR; otherwise STOP and fix before re-running.
If any FAIL → return to IMPLEMENT with the failing rule numbers listed.

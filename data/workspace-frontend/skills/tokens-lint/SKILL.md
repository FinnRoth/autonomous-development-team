---
name: tokens-lint
description: Scan the FE source tree for hardcoded styling (hex/rgb/hsl literals, magic px, inline style literals) and fail the build if any are found outside of token files.
trigger: Continuously during IMPLEMENT; mandatory before SELF_REVIEW and OPEN_PR. Also called by self-review and open-pr skills.
inputs: project/frontend/** (or, with --diff, only changed files in the current branch); docs/ui/design-tokens.json (authoritative token list).
outputs: A report listing every violation (file, line, snippet, rule); exit code 0 on clean / 1 on any violation.
---

# tokens-lint

1. **Scope.** Operate on `project/frontend/**` by default. With flag `--diff`, restrict to files changed in the current branch vs `origin/main`. Always skip:
   - `project/frontend/node_modules/**`
   - `project/frontend/dist/**`, `build/**`, `.next/**`, `.svelte-kit/**`
   - `project/frontend/tests/__snapshots__/**`
   - The token files themselves: `design-tokens.json`, any generated `*.tokens.{ts,js,css}` under `project/frontend/src/styles/tokens/`.

2. **Rules (each rule emits a violation with file/line/snippet).**

   - **T1 — hex literals.** Regex: `#[0-9A-Fa-f]{3,8}\b`. Allow only inside skipped paths.
   - **T2 — rgb/rgba/hsl/hsla literals.** Regex: `\b(?:rgba?|hsla?)\s*\(`.
   - **T3 — magic px.** Regex: `\b\d+(?:\.\d+)?px\b` outside of `*.tokens.*` files. Exempt: `0px` exactly; values inside an obvious media query string (`@media`); values inside a comment.
   - **T4 — magic rem/em (>0).** Regex: `\b\d*\.?\d+(?:rem|em)\b`. Same exemptions as T3.
   - **T5 — inline style literal color/spacing.** Regex (framework-aware): `style\s*=\s*\{?\{[^}]*\b(?:color|background|backgroundColor|padding|margin|border|fontSize|lineHeight|borderRadius|boxShadow)\b\s*:\s*["'][^"']*["']`. Hits → violation.
   - **T6 — Tailwind arbitrary values for colored properties.** Regex: `(?:bg|text|border|ring|fill|stroke|shadow)-\[#[0-9A-Fa-f]{3,8}\]` and `(?:bg|text|border|ring|fill|stroke|shadow)-\[(?:rgb|hsl)a?\(`. (Only relevant if project uses Tailwind.)
   - **T7 — Unknown token reference.** For files referencing token names (e.g. `var(--color-…)`, `theme.colors.…`, `tokens.color.…`), the referenced path must exist in `design-tokens.json`. Build a flat set of valid token paths at startup; any reference not in the set → violation.
   - **T8 — Disable directive without ADR.** Any inline comment of the form `// tokens-lint-disable` or `/* tokens-lint-disable */` MUST be followed on the same or next line by `ADR-<NN>`. Otherwise → violation.

3. **Run order.** Build the valid-token set first (T7 needs it). Then iterate files; for each file, apply T1–T6 line-by-line, T7 on token-reference matches, T8 on disable directives.

4. **Output format.** One line per violation:

```
<relative-path>:<line>:<col> [T<rule>] <snippet (≤120 chars)>
```

End with a summary:

```
tokens-lint: <N> violation(s) across <M> file(s)
```

5. **Exit codes.** `0` if zero violations. `1` otherwise. Quality gates require `0` (ROLE.md §"Quality Gates" #4).

6. **CI hook.** This skill is wired into the pre-PR check chain; `open-pr` skill runs it and embeds the output in the PR body under `## Tool outputs`.

## Forbidden during this skill

- Adding entries to the skip list to "make a file pass". The skip list is fixed above. If a tool emits generated CSS in a non-listed location, file an `escalation` to project-lead to amend this skill via convention.
- Silencing a violation with `tokens-lint-disable` without an ADR.

---
name: tokens-validate
description: Schema-check `docs/ui/design-tokens.json`; verify every color/spacing/typography/radius/shadow/motion reference in the design corpus comes from a token, not a raw value.
trigger: WORKFLOWS.md state 8 (TOKENS_PASS) and as part of `lint-ui-spec`.
inputs: Read access to `docs/ui/design-tokens.json`, `docs/ui/components.md`, `docs/ui/states.md`, `docs/ui/pages/`, `docs/ui/flows/`, `docs/ui/ui-spec.md`. (Wireframes are checked via the figma-sync invariant, not here.)
outputs: Pass/fail. On fail: a list of offending references and their files.
---

# Skill: tokens-validate

Two checks: (A) schema of `design-tokens.json`, (B) every reference in the corpus is a token.

## A. Schema check for `design-tokens.json`

The JSON must validate against this schema (semantically — implement in code; this is the contract):

```yaml
type: object
required: [color, spacing, typography, radii, shadow, motion]
properties:
  color:
    type: object
    additionalProperties: false
    patternProperties:
      "^(neutral|primary|accent|success|warning|danger|info)$":
        type: object
        patternProperties:
          "^(50|100|200|300|400|500|600|700|800|900)$":
            type: string
            pattern: "^#[0-9a-fA-F]{6}$"
  spacing:
    type: object
    patternProperties:
      "^(0|1|2|3|4|5|6|7|8|9|10|12|14|16|20|24|32|40|48|64)$":
        type: string
        pattern: "^[0-9]+px$"
  typography:
    type: object
    required: [family, scale, weight, line]
    properties:
      family:
        type: object
        required: [sans, mono]
      scale:
        type: object
        patternProperties:
          "^(xs|sm|md|lg|xl|2xl|3xl|4xl|5xl)$":
            type: string
            pattern: "^[0-9.]+(px|rem)$"
      weight:
        type: object
        patternProperties:
          "^(regular|medium|semibold|bold)$":
            type: integer
      line:
        type: object
        patternProperties:
          "^(tight|snug|normal|relaxed|loose)$":
            type: number
  radii:
    type: object
    patternProperties:
      "^(none|sm|md|lg|xl|full)$":
        type: string
  shadow:
    type: object
    patternProperties:
      "^(none|sm|md|lg|xl)$":
        type: string
  motion:
    type: object
    required: [duration, easing]
    properties:
      duration:
        type: object
        patternProperties:
          "^(instant|fast|normal|slow)$":
            type: string
            pattern: "^[0-9]+ms$"
      easing:
        type: object
```

Any schema violation → FAIL with JSON pointer of the offending location.

## B. Reference check across the corpus

Scan every Markdown file under `docs/ui/` (recursively) and every value in page/flow frontmatter. Token references look like `color.danger.500`, `spacing.4`, `radii.md`, `typography.scale.lg`, `motion.duration.fast`, etc.

Flag any of the following as **violations**:

1. **Raw hex codes**: any `#[0-9a-fA-F]{3,8}` anywhere in `docs/ui/**/*.md` outside `design-tokens.json` itself.
2. **Raw px/rem values**: `[0-9]+(px|rem)` outside `design-tokens.json` (unless inside a code fence labeled `// raw — does not ship`).
3. **Named CSS colors**: `red`, `blue`, `green`, `purple`, etc. in non-prose contexts (i.e., not in a sentence like "the user sees a red banner" — those are fine in flow descriptions; in component prop sketches they are violations).
4. **Font family strings**: `Inter`, `Helvetica`, `Arial`, `sans-serif`, etc. outside tokens.
5. **Token references that do not exist** in `design-tokens.json` (e.g., `color.danger.550` when the palette only has `500` and `600`).

## Steps

1. Load and validate `design-tokens.json` against schema A. Collect violations.
2. Walk the corpus; for each match against B.1–B.5, record `file:line: <excerpt>`.
3. Print all violations. Exit non-zero if any.
4. On pass: print `tokens-validate: OK (<N tokens>, <M references checked>)`.

## Common fixes

- New color the design needs → add it to `design-tokens.json` under the right ramp + step. Re-run.
- A value that genuinely cannot be tokenized (a one-off marketing graphic) → keep it in an asset file, not in `docs/ui/**`. The skill does not scan binary assets.

## Bypass

None. Tokens are the law.

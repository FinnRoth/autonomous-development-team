---
name: onboard-ui
description: ONE-TIME first-project skill. Reads `project-lead`'s onboarding Q&A, then produces the `ui-spec.md` skeleton, `design-tokens.json` with modern accessible defaults, and `components.md` with primitive components.
trigger: First time `uiux` receives a `handoff` from `project-lead` after `onboard-project` has been run AND `docs/ui/ui-spec.md` does not exist. Never run twice.
inputs: Read access to `docs/requirements/`, `docs/project/onboarding-Q&A.md`, `docs/architecture/` (may be empty). Write access to `docs/ui/`.
outputs: `docs/ui/ui-spec.md` (skeleton with §0–§8 sections), `docs/ui/design-tokens.json` (sane defaults), `docs/ui/components.md` (primitives), `docs/ui/states.md` (with primitives filled), empty `docs/ui/pages/`, empty `docs/ui/flows/`, empty `docs/ui/wireframes/`.
---

# Skill: onboard-ui

Run ONCE per project. Refuse to run if `docs/ui/ui-spec.md` already exists (FAIL with message: "already onboarded; nothing to do").

## Steps

1. **Read the onboarding context.**
   - `docs/project/onboarding-Q&A.md` (project-lead's notes).
   - `docs/requirements/*.md` if any exist.
   - `docs/architecture/data-model.md` and `openapi.yaml` if any exist (likely empty at this stage; that is fine).

2. **Pick a personality for the design system** based on the onboarding Q&A. Map answers like this:
   - "B2B / professional / utility" → neutral palette anchored on cool gray; primary `#2563eb` (indigo-600); accent muted; sans family Inter; tight typographic scale.
   - "Consumer / social / fun" → warmer neutrals; primary `#0ea5e9` (sky-500) OR `#7c3aed` (violet-600) depending on tone; sans Inter or Sora; relaxed scale.
   - "Health / finance / regulated" → high-contrast neutrals; primary `#1e40af` (blue-800); accent reserved; bold weights for emphasis; tight scale.
   - "No signal" → default to the B2B set above. Document the choice in `§0 Conventions`.

3. **Write `docs/ui/design-tokens.json`** with the chosen palette and the following non-negotiable defaults:

   ```json
   {
     "color": {
       "neutral": {
         "50": "#fafafa", "100": "#f5f5f5", "200": "#e5e5e5", "300": "#d4d4d4",
         "400": "#a3a3a3", "500": "#737373", "600": "#525252", "700": "#404040",
         "800": "#262626", "900": "#171717"
       },
       "primary": {
         "50": "#eff6ff", "100": "#dbeafe", "200": "#bfdbfe", "300": "#93c5fd",
         "400": "#60a5fa", "500": "#3b82f6", "600": "#2563eb", "700": "#1d4ed8",
         "800": "#1e40af", "900": "#1e3a8a"
       },
       "accent": {
         "50": "#f5f3ff", "100": "#ede9fe", "200": "#ddd6fe", "300": "#c4b5fd",
         "400": "#a78bfa", "500": "#8b5cf6", "600": "#7c3aed", "700": "#6d28d9",
         "800": "#5b21b6", "900": "#4c1d95"
       },
       "success": {
         "50": "#f0fdf4", "100": "#dcfce7", "200": "#bbf7d0", "300": "#86efac",
         "400": "#4ade80", "500": "#22c55e", "600": "#16a34a", "700": "#15803d",
         "800": "#166534", "900": "#14532d"
       },
       "warning": {
         "50": "#fffbeb", "100": "#fef3c7", "200": "#fde68a", "300": "#fcd34d",
         "400": "#fbbf24", "500": "#f59e0b", "600": "#d97706", "700": "#b45309",
         "800": "#92400e", "900": "#78350f"
       },
       "danger": {
         "50": "#fef2f2", "100": "#fee2e2", "200": "#fecaca", "300": "#fca5a5",
         "400": "#f87171", "500": "#ef4444", "600": "#dc2626", "700": "#b91c1c",
         "800": "#991b1b", "900": "#7f1d1d"
       },
       "info": {
         "50": "#ecfeff", "100": "#cffafe", "200": "#a5f3fc", "300": "#67e8f9",
         "400": "#22d3ee", "500": "#06b6d4", "600": "#0891b2", "700": "#0e7490",
         "800": "#155e75", "900": "#164e63"
       }
     },
     "spacing": {
       "0": "0px", "1": "4px", "2": "8px", "3": "12px", "4": "16px",
       "5": "20px", "6": "24px", "7": "28px", "8": "32px", "9": "36px",
       "10": "40px", "12": "48px", "14": "56px", "16": "64px",
       "20": "80px", "24": "96px", "32": "128px", "40": "160px",
       "48": "192px", "64": "256px"
     },
     "typography": {
       "family": {
         "sans": "Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
         "mono": "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
       },
       "scale": {
         "xs": "0.75rem", "sm": "0.875rem", "md": "1rem", "lg": "1.125rem",
         "xl": "1.25rem", "2xl": "1.5rem", "3xl": "1.875rem",
         "4xl": "2.25rem", "5xl": "3rem"
       },
       "weight": {
         "regular": 400, "medium": 500, "semibold": 600, "bold": 700
       },
       "line": {
         "tight": 1.2, "snug": 1.35, "normal": 1.5, "relaxed": 1.625, "loose": 2
       }
     },
     "radii": {
       "none": "0px", "sm": "4px", "md": "8px", "lg": "12px", "xl": "16px", "full": "9999px"
     },
     "shadow": {
       "none": "none",
       "sm": "0 1px 2px 0 rgb(0 0 0 / 0.05)",
       "md": "0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)",
       "lg": "0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)",
       "xl": "0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)"
     },
     "motion": {
       "duration": {
         "instant": "0ms", "fast": "120ms", "normal": "200ms", "slow": "320ms"
       },
       "easing": {
         "standard": "cubic-bezier(0.2, 0, 0, 1)",
         "emphasized": "cubic-bezier(0.3, 0, 0, 1)",
         "decel": "cubic-bezier(0, 0, 0, 1)",
         "accel": "cubic-bezier(0.3, 0, 1, 1)"
       }
     }
   }
   ```

   (If the personality choice in step 2 changes the `primary` or `accent` ramp, swap those ramps; never delete keys.)

4. **Write `docs/ui/components.md` with primitives.** These exist on day 1:

   - **Button** — purpose: primary user action. Props sketch: `variant: primary|secondary|ghost|danger`, `size: sm|md|lg`, `disabled`, `loading`, `leadingIcon`, `trailingIcon`. Used in: TBD.
   - **Input** — purpose: single-line text entry. Props sketch: `type: text|email|password|number`, `label`, `helper`, `error`, `prefix`, `suffix`, `disabled`. Used in: TBD.
   - **Card** — purpose: surface a related cluster of content. Props sketch: `padding: sm|md|lg`, `as`, slot for header/body/footer. Used in: TBD.
   - **Dialog** — purpose: modal interaction. Props sketch: `open`, `onClose`, `size: sm|md|lg`, `title`, `description`. Used in: TBD.
   - **Toast** — purpose: transient feedback. Props sketch: `kind: success|error|info|warning`, `duration`, `action`. Used in: TBD.
   - **Skeleton** — purpose: loading placeholder matching content footprint. Props sketch: `width`, `height`, `radius`. Used in: TBD.
   - **EmptyState** — purpose: friendly nothing-here surface with optional CTA. Props sketch: `title`, `description`, `action`, `icon`. Used in: TBD.
   - **ErrorBoundary** — purpose: caught-error UI with retry. Props sketch: `error`, `onRetry`. Used in: TBD.

5. **Write `docs/ui/states.md` with the 5-state matrix filled for each primitive.** Use the rules from skill `states-matrix`. Do not leave `_TODO_` for primitives — fill them now.

6. **Write `docs/ui/ui-spec.md` skeleton** with the FROZEN §0–§8 sections:

   ```markdown
   # UI Spec — <project>

   _Canonical UI specification. Frontend (Vela 💠) implements from this file._

   ## §0 Conventions
   - Tokens are mandatory. No raw colors, spacing, type, radii, shadows, motion.
   - All components have 5 states: loading / empty / error / success / disabled.
   - All routes are kebab-case.
   - Personality: <chosen in step 2>.

   ## §1 Pages
   | id | name | route | owner-story | wireframe-path |
   |---|---|---|---|---|

   ## §2 Flows
   | id | name | trigger | sequence | success | error |
   |---|---|---|---|---|---|

   ## §3 Components
   See `docs/ui/components.md`.

   ## §4 States Matrix
   See `docs/ui/states.md`.

   ## §5 Design Tokens
   See `docs/ui/design-tokens.json`. Reference tokens by dotted name (e.g., `color.primary.600`).

   ## §6 Accessibility rules
   - WCAG 2.1 AA floor for all interactive surfaces.
   - All interactive elements reachable by keyboard in DOM order; visible focus ring (`shadow.md` or outline using `color.primary.500`).
   - Color is never the only signal (always pair with icon/text).
   - Honor `prefers-reduced-motion`: drop to `motion.duration.instant`.
   - Touch targets >= 44×44 px on mobile.

   ## §7 Responsive rules
   - Breakpoints: `sm: 640px`, `md: 768px`, `lg: 1024px`, `xl: 1280px`, `2xl: 1536px`.
   - Mobile-first: write base styles for `< sm`, add up.
   - Container max-width on `> 2xl` is `1440px`; never full-bleed for text content.

   ## §8 Open questions
   _(none — populated as `question`s to architect / project-lead resolve.)_
   ```

7. **Create empty directories:** `docs/ui/pages/`, `docs/ui/flows/`, `docs/ui/wireframes/`. Place a `.gitkeep` in each.

8. **Run `tokens-validate` and `lint-ui-spec`.** Both MUST pass on the skeleton (empty tables are OK; no Story has a page yet because there are no Stories in scope yet).

9. **Commit:** `[ONBOARD] uiux skeleton: ui-spec.md, design-tokens.json, components.md, states.md`. Open a PR.

10. **Send a `handoff` to `project-lead`** confirming onboarding:

    ```json
    {
      "type": "handoff",
      "from": "uiux",
      "to": "project-lead",
      "ticket_id": "ONBOARD",
      "artifact_paths": ["docs/ui/ui-spec.md", "docs/ui/design-tokens.json", "docs/ui/components.md", "docs/ui/states.md"],
      "summary": "uiux onboarding complete; awaiting first epic/story",
      "acceptance": ["ui-spec.md skeleton with §0–§8", "design-tokens.json validates", "primitives documented with all 5 states"],
      "blocking_questions": []
    }
    ```

11. **Mark this skill as run** by writing `docs/ui/.onboarded` (single file with the ISO timestamp). Future invocations FAIL fast on the presence of this file.

## Hard rules

- Never run twice. The presence of either `docs/ui/.onboarded` or `docs/ui/ui-spec.md` is a fail-fast condition.
- Never invent Stories or Pages here. This is a skeleton.
- Never paint tokens specific to one not-yet-conceived feature. Stick to the universal palette ramps above.
- Personality choice (step 2) is recorded in `§0 Conventions` so future-Iris cannot forget why the primary is what it is.

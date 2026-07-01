# TOOLS.md — MCP Servers Iris Uses

I am `uiux`. I have access to the following MCP servers. Scopes are declared here; the actual wiring happens later in `docker-compose.yml`.

## 1. `filesystem` — workspace-uiux scope

- **Scope (root):** `/home/node/.openclaw/workspace-uiux/`
- **Mode:** read+write
- **Use:** read/write everything inside my own workspace — `docs/` clone, `inbox/`, `outbox/`, `memory/`, `skills/`, and the `ROLE.md` / `WORKFLOWS.md` / `PROTOCOLS.md` / `SOUL.md` / `IDENTITY.md` / `USER.md` / `MEMORY.md` files.
- **Forbidden:** anything under `/home/node/.openclaw/workspace-<other>/`. I never reach into another agent's workspace (CONVENTIONS.md §6.1).

## 2. `git` — docs repo only

- **Repo:** `<project>-docs` (cloned at `docs/`)
- **Mode:** read+write on branches `uiux/*` and PRs into the docs default branch.
- **Use:** commit `docs/ui/**`, `docs/board.md` (read-only for me — `project-lead` owns it), `docs/tickets/<my-ticket>.md` updates (status field only).
- **Forbidden:**
  - I do NOT clone `<project>` (the code repo). I never need it.
  - Never `git push --force` to any shared branch (CONVENTIONS.md §6.2).
  - Never edit `docs/architecture/openapi.yaml` or `docs/architecture/data-model.md` (file a `question` to architect instead).
  - Never edit ticket frontmatter beyond `status` of a ticket I own.

## 3. `openclaw-messaging` — agent-to-agent JSON gateway

- **Use:** write `outbox/<ISO>-<to>-<type>.json` and let the gateway mirror into the recipient's `inbox/`. Read my own `inbox/`.
- **Message types:** `handoff`, `question`, `escalation` (CONVENTIONS.md §4, PROTOCOLS.md).
- **Forbidden:** sending `to: "user"` — that field is invalid from `uiux`. Only `project-lead` may set `to: "user"` (CONVENTIONS.md §4.3).

## 4. `figma` — design read/write

- **Use:** read frames from `ADT/<project>`; push wireframes/mockups; export PNGs into `docs/ui/wireframes/`.
- **Auth:** `FIGMA_TOKEN` env var, injected from `docker-compose.yml`. Placeholder value here:
  ```
  FIGMA_TOKEN=<set-by-compose>
  ```
- **File naming:** Figma file is `ADT/<project>`. Frames are named exactly `P-NN — <page name>` to match `docs/ui/pages/<page>.md` frontmatter.
- **Forbidden:** committing the `FIGMA_TOKEN` value to any file or message (CONVENTIONS.md §6.5).

## What I do NOT have

- No `project/` clone (I do not touch code — CONVENTIONS.md §1 says my owned area is `docs/ui/`).
- No CI runner / no shell to run app builds.
- No direct access to other agents' workspaces.

## Local notes

- Wireframe export resolution: 2x PNG, also keep the SVG.
- Default Figma frame size for desktop: 1440×900. Mobile: 390×844.
- I keep design-token defaults in `skills/onboard-ui/SKILL.md` so onboarding is deterministic.

# TOOLS — Architect (Cassius)

These are the MCP servers I rely on. Wiring is done by the OpenClaw harness; I declare scope here.

## 1. `filesystem` (scope: `workspace-architect`)

- Read/write across my own workspace: `AGENTS.md`, `ROLE.md`, `WORKFLOWS.md`, `PROTOCOLS.md`, `SOUL.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md`, `MEMORY.md`, `memory/`, `inbox/`, `outbox/`, `skills/`.
- Read/write across the cloned `docs/` tree, **restricted by convention to `docs/architecture/`**.
- Read across `project/` (entire tree) for audits.
- Write into `project/` is **restricted by convention to**:
  - `project/.architecture/contracts/` (generated TS + Python types)
  - folder-skeleton `.gitkeep` files when bootstrapping
- Never writes inside another `workspace-*`.

## 2. `git` (two scoped clients)

- **`docs/` — read/write.** Clone of `<project>-docs`. I branch as `architect/<TICKET-ID>-<slug>`, commit with `[<TICKET-ID>] <imperative>`, push to remote, open PR via the `gh` CLI (or `glab`/`tea` per `GIT_HOST_CLI` env, default `gh`) invoked through the OpenClaw shell-exec tool — NOT via any GitHub MCP server.
- **`project/` — read-only by default.** Exception: when I run `generate-contracts` or `bootstrap-stack`, I am allowed to push a `architect/<TICKET-ID>-contracts` branch limited to paths under `project/.architecture/contracts/` and `.gitkeep` folder-skeleton files.

## 3. `openclaw-messaging`

- Read `inbox/`, write `outbox/`. Send `handoff` (reply), `question`, `escalation` messages following the schemas in `CONVENTIONS.md §4`.

## 4. `context7`

- High-value. Whenever I evaluate a framework, library, or SDK during `architect-feasibility` or `bootstrap-stack`, I resolve the library id and query its docs. I do not trust training-data recall for stack decisions.

## 5. `sequential-thinking`

- Used during `architect-feasibility` and `write-adr` to enumerate options, trade-offs, and consequences before drafting. Output is summarized into the ADR, not pasted verbatim.

## 6. Git host via `gh` CLI (or `glab`/`tea`) — NOT an MCP server

- `gh` CLI (or `glab`/`tea` per `GIT_HOST_CLI` env, default `gh`): host-agnostic git-host commands (PRs, issues, reviews, comments). Token: `GIT_HOST_TOKEN` env var. Invoked via shell-exec, not via MCP.
- Open PRs against `<project>-docs` only.
- I do not merge PRs (Reviewer's job).
- I add the `architecture` label on PRs I open.

## Tools I do NOT have

- No shell into `project/backend/` or `project/frontend/` runtimes.
- No browser automation.
- No package-publishing rights.
- No CI admin.

If a workflow requires one of the above, I file a `question` to `project-lead`.

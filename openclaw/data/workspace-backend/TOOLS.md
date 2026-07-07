# TOOLS — MCP servers Forge uses

This file declares the MCP servers and scopes I rely on. The servers themselves are wired into my OpenClaw runtime; this file is the contract of what I expect.

## 1. `filesystem` (workspace-backend)

- **Scope:** `~/.openclaw/workspace-backend/` (full r/w, including `project/`, `docs/` read-mostly, `inbox/`, `outbox/`, `memory/`, `skills/`).
- **Read-only sub-scopes I respect by convention (not enforced):**
  - `docs/architecture/**` — owned by architect; I read only.
  - `docs/ui/**` — owned by uiux; I read only.
  - `docs/tickets/` does not exist — all ticket data lives in board-api.
- **Forbidden:** any other agent's workspace. See CONVENTIONS.md §6.

## 2. `git` + `gh` CLI (or `glab`/`tea`) — NOT a GitHub MCP server

- `gh` CLI (or `glab`/`tea` per `GIT_HOST_CLI` env, default `gh`): host-agnostic git-host commands (PRs, issues, reviews, comments). Token: `GIT_HOST_TOKEN` env var. Invoked via shell-exec, not via MCP.
- **Repos:**
  - `project/` (clone of `<project>` source repo) — full r/w on my branches.
  - `docs/` (clone of `<project>-docs`) — pull only; I never push, EXCEPT to flip `status` on a ticket I own.
- **Operations I perform:** `clone`, `fetch`, `pull --ff-only`, `checkout -b`, `add`, `commit`, `push` to my own branch namespace `backend/<TICKET-ID>-<slug>`, open PRs via the host CLI (invoked through shell-exec), comment on PR threads.
- **Forbidden:** push to `main`/`develop`/release branches, force-push to shared branches, delete branches I do not own, self-merge. See CONVENTIONS.md §6.

## 3. `openclaw-messaging`

- **Purpose:** drop messages into `outbox/` and watch `inbox/` for `handoff` / `question` / `escalation` JSON files.
- **Schemas:** frozen — see CONVENTIONS.md §4. My role-specific examples live in `PROTOCOLS.md`.
- **Archive policy:** processed inbox messages are moved to `inbox/archive/YYYY-MM-DD/`, never deleted.

## 4. `context7`

- **Purpose:** fetch current library/framework/SDK/API docs whenever I touch one (e.g., the web framework chosen by the architect, the ORM, the auth library). I use it BEFORE writing code that calls a third-party API, even for libraries I know.
- **Forbidden:** using context7 for general programming concepts, business logic, or refactoring guidance.

## 5. Shell exec (OpenClaw built-in)

- **Purpose:** run lint, type-check, test suite, migration up/down dry-runs, package manager commands.
- **Scope:** only inside `project/` and `project/backend/`. Never network installs outside the lockfile.

## 6. Database MCP — `wire when project chooses DB`

When the architect publishes the persistence ADR, project-lead will wire a DB MCP (e.g., `postgres`, `sqlite`, `mongodb`) scoped to the project's dev DB. Until then, I run migrations through the project's CLI via shell exec and inspect schemas through the ORM's introspection commands. I MUST NOT invent a DB MCP; I MUST flag the absence in any ticket that requires direct DB inspection by filing a `question` to the architect.

---

See CONVENTIONS.md §5 for the workspace layout these scopes correspond to.

## board-api-workers

Task board API. Authoritative structured ticket store for ADT.

**Allowed tools:**
- `board_get_ready_tickets` — poll for claimable tickets (filter by owner=backend)
- `board_claim_ticket` — atomically claim a ready ticket
- `board_get_ticket` — read full ticket details + comments
- `board_list_tickets` — list tickets with status/owner/type filters
- `board_transition_ticket` — transition ticket status
- `board_add_comment` — add comment or question to ticket thread
- `board_get_board` — full board snapshot
- `board_get_deps` — check dependency status

**Forbidden tools (project-lead only):**
- `board_create_ticket` — only project-lead creates tickets
- `board_update_ticket` — only project-lead edits ticket metadata

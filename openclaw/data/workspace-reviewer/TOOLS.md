# Tools Available to Mira 🔍

This file declares the MCP servers and CLI tools I rely on. Wiring lives in the host OpenClaw config; this file is the authoritative list of what I *use*.

## MCP servers

### `filesystem` (scoped)
- **Scope (read-write):** `~/.openclaw/workspace-reviewer/` only.
  - Includes `docs/reviews/` (my owned artifacts), `MEMORY.md`, `memory/`, `inbox/`, `outbox/`, `skills/`.
- **Scope (read-only):** `~/.openclaw/workspace-reviewer/project/` and `~/.openclaw/workspace-reviewer/docs/` (the cloned project + docs repos).
- **Forbidden:** any other `workspace-<agent>/` directory. See CONVENTIONS.md §6.

### `git` (read-only on `project/`, read-write on `docs/`)
- Used to: fetch PR branches, view diffs against `main`, view commit history, run `git log --since=<merge-sha>` for post-merge audits, commit updates to `docs/reviews/`.
- I **never** push to feature branches (CONVENTIONS.md §6.6, plus the role-specific "FORBIDDEN: commit code on a feature branch").
- I **never** force-push to `main`/`develop` (CONVENTIONS.md §6.2).

### `gh` CLI (or `glab`/`tea` per `GIT_HOST_CLI` env, default `gh`) — **CRITICAL**, NOT an MCP server
- `gh` CLI (or `glab`/`tea` per `GIT_HOST_CLI` env, default `gh`): host-agnostic git-host commands (PRs, issues, reviews, comments). Token: `GIT_HOST_TOKEN` env var. Invoked via shell-exec, not via MCP.
- This CLI is what lets me actually post reviews and merge PRs. The team supports GitHub, Gitea, Forgejo, GitLab — the concrete CLI is selected at onboarding by `project-lead` via `GIT_HOST_CLI`. There is NO `@modelcontextprotocol/server-github` (or equivalent) MCP server in this stack; every command below is executed by the OpenClaw shell-exec tool.
- Operations I perform:
  - `pr view <num> --json …` — pull PR metadata + diff
  - `pr diff <num>` — read the patch
  - `pr review <num> --request-changes --body …` — verdict REQUEST_CHANGES
  - `pr review <num> --approve --body …` — verdict APPROVE
  - `pr comment <num> --body …` — top-level review summary
  - inline review comments (host-CLI specific JSON payload)
  - `pr merge <num> --squash --delete-branch` — merge after approval + green CI
  - `pr checks <num>` — CI status (must be green to approve)
- Auth: token in the `GIT_HOST_TOKEN` env var (already wired by `docker-compose.yml`) — never committed.

### `openclaw-messaging`
- Reads `inbox/`, writes to `outbox/`, used to send `handoff` / `question` / `escalation` per CONVENTIONS.md §4.

### `context7`
- Used only to sanity-check framework idioms when a Required comment hinges on "the standard way to do X in framework Y". I do not use it to invent rules — I use it to confirm a rule I'm about to cite is real.

### `board-api` (workers subset)
- **Base URL:** `http://board-api:8000` (internal Docker network). Accessed via the `board-api` MCP server wired in `mcp-patch.json5`.
- **Tools I use:**

  | Tool | When | Arguments |
  |---|---|---|
  | `board_get_ticket` | INTAKE — authoritative source for ticket status and acceptance criteria | `ticket_id: string` |
  | `board_transition_ticket` | VERDICT APPROVE — move ticket to `qa` after merge | `ticket_id: string`, `agent: "reviewer"`, `to: "qa"` |

- **Tools I do NOT use:** `board_get_ready_tickets`, `board_claim_ticket`, `board_list_tickets`, `board_create_ticket`, `board_update_ticket`, `board_get_board`, `board_add_comment`, `board_get_deps`. Reviewer is handoff-driven; I do not self-assign or poll the board for work.
- **Error handling:** if `board_get_ticket` returns 404 → ticket is missing; follow the on-error path in WORKFLOWS.md State 2. If `board_transition_ticket` fails → retry once, then escalate `med` to project-lead; do not block the QA handoff.

## Tools I do NOT have
- No `playwright` / no browser automation — that's QA's domain.
- No `sap-jira` / `sap-wiki` / `sap-msteams` — not used by this project layout.
- No write access to `project/` — I review, I do not edit code.

## Environment variables I rely on
- `GIT_HOST_TOKEN` — git host auth, consumed by `gh`/`glab`/`tea` via shell-exec (already wired by `docker-compose.yml`)
- `LITELLM_API_KEY` — model access via `host.docker.internal:6655`
- `OPENCLAW_AGENT_ID=reviewer` — so messaging knows who I am

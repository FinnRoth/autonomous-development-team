# TOOLS — MCP servers and scopes for architect (Cassius 🏛️)

All MCP servers below are declared here; wiring happens in a later step. I never touch filesystem paths outside the scopes listed.

## MCP servers I use

### `filesystem` (workspace-architect)
- **Scope (read/write):**
  - `~/.openclaw/workspace-architect/` (everything in my workspace)
  - `~/.openclaw/workspace-architect/docs/<docs-repo-name>/architecture/**` (architecture subtree in docs repo)
  - `~/.openclaw/workspace-architect/docs/<docs-repo-name>/project/repos.md` (repo registry, updated after EPIC-01)
- **Scope (read-only):**
  - `~/.openclaw/workspace-architect/docs/<docs-repo-name>/project/**` (vision, requirements, Q&A)
  - `~/.openclaw/workspace-architect/docs/<docs-repo-name>/ui/**` (UI specs — read for data-model alignment)
  - `~/.openclaw/workspace-architect/code/<repo-name>/` (all code repos — read + own branches rw under `.architecture/contracts/` and skeleton `.gitkeep` paths)
- **Never touch:** any other `workspace-<agent>/` (CONVENTIONS.md §6.1).

### `git` + `gh` CLI (or `glab`/`tea`) — NOT a GitHub MCP server
- `gh` CLI (or `glab`/`tea` per `GIT_HOST_CLI` env, default `gh`): host-agnostic git-host commands (PRs, issues, reviews, repo creation). Token: `GIT_HOST_TOKEN` env var. Invoked via shell-exec, not via MCP.
- **Repos cloned in my workspace:**
  - `docs/<docs-repo-name>/` — docs repo, branch prefix `architect/<TICKET-ID>-ADR-NNN`
  - `code/<repo-name>/` — code repos, branch prefix `architect/<TICKET-ID>-<slug>` (contracts and skeleton only)
- **Forbidden ops:** `push --force` on `main`/`develop`/release; deleting branches I do not own (CONVENTIONS.md §6.2–§6.3). Never self-merge.

### Messaging — via `board-api` comments
- **Purpose:** all agent-to-agent messages (`handoff`, `question`, `escalation`) — CONVENTIONS.md §4. Post with `board_add_comment` (fields: `to`, `type` ∈ `handoff|question|escalation|info`, `notify`, `from_ticket`); read with `board_get_unread(agent="architect")`; clear with `board_ack_comment`.
- A comment is delivered the instant board-api stores it (CONVENTIONS.md §12). My role-specific examples live in `PROTOCOLS.md`.

### `context7`
- For up-to-date library/framework docs (language runtimes, ORMs, validation libs, auth libs, API frameworks).
- Prefer this over web search for any library API question, per server instructions.

### `sequential-thinking`
- For ADR deliberation: enumerate alternatives, weigh consequences, arrive at a decision.
- Required for every ASSESS state where `needs-ADR` is a candidate outcome.

## Environment variables I expect

| Var | Purpose |
|---|---|
| `LITELLM_API_KEY` | LLM access (CONVENTIONS.md §8) |
| `GIT_HOST_TOKEN` | PAT for `gh`/`glab`/`tea` — push, PR creation, repo creation |
| `GIT_HOST_CLI` | Which CLI to invoke (`gh` default) |

## Local notes (project-specific)

_(Populated after `onboard-project` runs. Currently STANDBY — see CONVENTIONS.md §9.)_

- Docs repo slug: _unset_
- Code repo slugs: _unset_
- OpenAPI paths (one per service): _unset_ (`architecture/api/<service>/openapi.yaml` per `project/repos.md`)
- Contracts generator command: _unset_

## board-api-workers

Task board API. Authoritative structured ticket store for ADT.

**Allowed tools:**
- `board_get_ready_tickets` — poll for claimable tickets (filter by owner=architect)
- `board_claim_ticket` — atomically claim a ready ticket
- `board_get_ticket` — read full ticket details + comments
- `board_list_tickets` — list tickets with status/owner/type filters
- `board_transition_ticket` — transition ticket status
- `board_add_comment` — post a `handoff`/`question`/`escalation`/`info` comment (the messaging channel); set `to`, `notify`, `from_ticket`
- `board_get_unread` — poll for comments addressed to me (heartbeat notification)
- `board_ack_comment` — mark a comment read/handled
- `board_get_board` — full board snapshot
- `board_get_deps` — check dependency status

**Forbidden tools (project-lead only):**
- `board_create_ticket` — only project-lead creates tickets
- `board_update_ticket` — only project-lead edits ticket metadata

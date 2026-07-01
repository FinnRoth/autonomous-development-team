# CLAUDE.md — Project brief for future Claude Code sessions

You are working on **ADT (Autonomous Development Team)** — a **reusable OpenClaw multi-agent template** that ships a 7-agent development team as a cloneable Docker setup. The template's own agents (defined here) will later run inside the OpenClaw container and do the actual work when a project is onboarded.

**Your job (Claude Code) is different from theirs (the ADT agents):** you generate and maintain the OpenClaw agent files and container config. You do **not** run the development workflow — the OpenClaw agents inside the container do.

---

## 1. What this repo actually is

A Docker Compose setup that boots an OpenClaw container (`adt-test-1-02`) with:

- **7 pre-configured agents** — each with its own workspace, role, skills, and MCP scope.
- **1 shared conventions file** — the single source of truth for cross-agent rules.
- **13 MCP servers** — wired per-agent via `codex.agents` in `openclaw.json`.

The team is **template-mode**: no project onboarded yet. On first user chat, `project-lead` runs its `onboard-project` skill.

---

## 2. Repo layout

```
adt-dev-1-02/
├── CLAUDE.md                     # ← this file
├── Dockerfile                    # extends ghcr.io/openclaw/openclaw:latest with gh + Playwright deps
├── docker-compose.yml            # container_name: adt-test-1-02, port 18789, env: LITELLM_API_KEY, FIGMA_TOKEN, GIT_HOST_TOKEN
├── .gitignore                    # tracks TEMPLATE only; excludes runtime state (see §7)
├── package.json, package-lock.json  # empty stubs left by the OpenClaw base image
└── data/                         # mounted into container at /home/node/.openclaw
    ├── adt-shared/               # SHARED across all agents (symlinked into each workspace)
    │   ├── CONVENTIONS.md        # ← THE single source of truth: team rules, message schemas, forbidden actions
    │   ├── mcp-patch.json5       # MCP server definitions with per-agent scoping
    │   └── default-agent-patch.json5  # makes project-lead the default agent
    └── workspace-<agent>/        # one per role (project-lead, architect, backend, uiux, frontend, reviewer, qa)
        ├── AGENTS.md             # startup instructions (OpenClaw base, customized per role)
        ├── SOUL.md               # temperament / persona
        ├── IDENTITY.md           # name + emoji + role_id
        ├── USER.md               # who tasks this agent, who it serves
        ├── TOOLS.md              # MCP scopes declared for this agent
        ├── ROLE.md               # THE role contract — read first every session
        ├── WORKFLOWS.md          # deterministic state machine (entry/exit/actions/outputs/on-error)
        ├── PROTOCOLS.md          # concrete SEND/RECEIVE message examples for this role
        ├── HEARTBEAT.md          # periodic-poll checklist
        ├── MEMORY.md             # long-term memory (empty stub in template)
        ├── CONVENTIONS.md        # symlink → adt-shared/CONVENTIONS.md
        ├── inbox/.gitkeep        # runtime message drop
        ├── outbox/.gitkeep       # runtime audit trail
        ├── memory/.gitkeep       # daily YYYY-MM-DD.md logs go here (ignored)
        └── skills/<name>/SKILL.md   # 5-9 role-specific deterministic skills
```

**Runtime-only paths (not in git):** `data/agents/`, `data/state/`, `data/logs/`, `data/identity/`, `data/devices/`, `data/plugin-skills/`, `data/workspace-attestations/`, `data/openclaw.json*`, `data/openclaw.sqlite*`, per-workspace `.git/`, `.openclaw/`, `openclaw-workspace-state.json`. The `.gitignore` is precise about this — see §7.

---

## 3. The 7 agents (canonical list)

| ID | Name | Emoji | Owns | Primary MCP |
|---|---|---|---|---|
| `project-lead` | Atlas | 🧭 | `docs/project/`, `docs/tickets/`, `docs/board.md` | filesystem, context7, sequential-thinking |
| `architect` | Cassius | 🏛️ | `docs/architecture/` (ADRs, openapi, data-model) | filesystem, context7, sequential-thinking |
| `backend` | Forge | 🔧 | `project/backend/**` | filesystem, context7 |
| `uiux` | Iris | 🎨 | `docs/ui/` (spec, flows, tokens, Figma) | filesystem, context7, figma (rw) |
| `frontend` | Vela | 💠 | `project/frontend/**` | filesystem, context7, figma (ro), playwright (opt) |
| `reviewer` | Mira | 🔍 | `docs/reviews/` (PR gating) | filesystem, context7 |
| `qa` | Krell | 🐛 | `docs/qa/`, `project/qa-tests/**` | filesystem, context7, playwright |

**`project-lead` is the default agent** — the user's front door. The `main` agent still exists (OpenClaw seed) but is not part of the team. No one talks to `main`.

Communication happens over OpenClaw's built-in agent-to-agent messaging using three **frozen** JSON schemas: `handoff`, `question`, `escalation`. See `data/adt-shared/CONVENTIONS.md` §4.

---

## 4. Key files to read before editing anything

**Every time.** Read these before making changes — they encode invariants:

1. `data/adt-shared/CONVENTIONS.md` — the single source of truth. Team roster, message schemas, ticket schema, forbidden actions, standby rules. **If a role file contradicts CONVENTIONS.md, CONVENTIONS.md wins.**
2. The affected agent's `ROLE.md`, `WORKFLOWS.md`, `PROTOCOLS.md` — the role contract.
3. This file (`CLAUDE.md`) for your own operating context.

Skip re-reading base OpenClaw templates (they're standard) unless the change is architectural.

---

## 5. Common tasks

### Rebuild the container after Dockerfile / compose change
```bash
docker compose down
docker compose up -d --build
```
Container name is `adt-test-1-02`. Health probe: `docker exec adt-test-1-02 curl -s localhost:18789/health`.

### Apply MCP-server changes
Edit `data/adt-shared/mcp-patch.json5`, then:
```bash
docker exec adt-test-1-02 openclaw config patch --file /home/node/.openclaw/adt-shared/mcp-patch.json5
# validate
docker exec adt-test-1-02 openclaw config validate
```
The actual `data/openclaw.json` is git-ignored (runtime state); the patch file is the source of truth. On a fresh clone, re-apply the patch.

### Add or modify a skill
Skills live at `data/workspace-<agent>/skills/<name>/SKILL.md`. Each has YAML frontmatter (`name`, `description`, `trigger`, `inputs`, `outputs`) followed by numbered deterministic steps.

**Rules:**
- Every step must be a concrete action, not "consider X" / "decide if Y".
- If you're tempted to write "decide" or "manual review", replace with mechanical rules.
- Steps that produce artifacts must name the exact path.

### Amend CONVENTIONS.md
Only via a proposal in a `project-lead` context. Other agents file an `escalation` with `requested_decision: "amend conventions §N"`. In your (Claude Code) role, only edit CONVENTIONS.md if the user explicitly asks — every agent references it.

### List agents / see MCP wiring
```bash
docker exec adt-test-1-02 openclaw agents list
docker exec adt-test-1-02 python3 -c "import json; c=json.load(open('/home/node/.openclaw/openclaw.json')); [print(f'{n:22} -> {s.get(\"codex\",{}).get(\"agents\",[])}') for n,s in c['mcp']['servers'].items()]"
```

### First-time onboarding of a real project (user story)
1. Set `FIGMA_TOKEN` and `GIT_HOST_TOKEN` in `docker-compose.yml`, `docker compose restart`.
2. User connects to the container's gateway → lands on `project-lead` (Atlas).
3. Atlas runs `skills/onboard-project` — interrogates the user, produces `docs/project/vision.md`, `EPIC-01`, hands off to `architect` for `ADR-001` (stack). All other agents stay in `STANDBY` until they receive their first handoff.

---

## 6. Invariants — do not break

These are enforced across every role file. Breaking them makes the team behave inconsistently.

1. **Only `project-lead` addresses the user directly.** Every other agent that needs a user decision files an `escalation` upward.
2. **Only three message types exist:** `handoff`, `question`, `escalation`. No `answer`, no `cc`, no other fields on the message envelope. Adding a field requires amending CONVENTIONS.md §4 and every agent's PROTOCOLS.md.
3. **Per-agent workspaces are isolated.** No agent writes into another agent's `workspace-*/`.
4. **No self-merge, no push to `main`.** Reviewer is the sole gatekeeper (except for reviewer's own docs — same rule via handoff back).
5. **Ticket schema is frozen** (CONVENTIONS.md §3). Frontmatter fields are exact; no extras.
6. **Template mode = STANDBY** for all non-`project-lead` agents until `onboard-project` runs.
7. **No `main` agent in the team roster.** It's an OpenClaw seed artifact, not a worker. Don't reference it in any ROLE / PROTOCOLS file.
8. **CONVENTIONS.md is symlinked**, not copied, into each workspace. If you regenerate a workspace, restore the symlink to `/home/node/.openclaw/adt-shared/CONVENTIONS.md`.

---

## 7. Git hygiene

Repo tracks the **template only**. Runtime state (sessions, sqlite, logs, device identity, per-workspace `.git`, daily memory files, inbox/outbox contents) is git-ignored. Sentinel `.gitkeep` files preserve empty runtime dirs.

- Author: `Finn Roth <finn.roth@sap.com>` (host global git config).
- Initial commit: `c273a71` — "Initial ADT template: 7 agents, 47 skills, 13 MCP servers".
- No remote yet (local-only per user preference).

**Before committing changes to agent files:**
```bash
git diff --cached --stat                   # sanity-check the file list
git check-ignore -v data/agents/…          # spot any runtime leak you almost committed
```

The `.gitignore` uses "default-ignore then re-include" for the `data/` tree; if you add a new top-level dir under `data/` that should be tracked, add an explicit `!/data/<newdir>/` re-include.

---

## 8. Environment / secrets

`docker-compose.yml` exposes three env vars into the container:

- `LITELLM_API_KEY` — for the local LiteLLM at `host.docker.internal:6655`. Model: `litellm/anthropic--claude-opus-4-6`.
- `FIGMA_TOKEN` — Figma PAT for `uiux` / `frontend`. Placeholder `REPLACE_ME_FIGMA_PAT` until real onboarding.
- `GIT_HOST_TOKEN` — PAT for `gh` / `glab` / `tea`. Placeholder `REPLACE_ME_GIT_TOKEN`. `GIT_HOST_CLI` selects which CLI (default `gh`).

**Never commit real tokens.** The placeholders are safe. Real values go into a `.env` file the user provides locally (or into their secrets manager if they later add remote deployment).

---

## 9. Where things live inside the container

`./data/` on the host = `/home/node/.openclaw/` inside `adt-test-1-02`. So:

- Host `data/adt-shared/CONVENTIONS.md` = container `/home/node/.openclaw/adt-shared/CONVENTIONS.md` (the symlink target).
- Host `data/workspace-project-lead/` = container `/home/node/.openclaw/workspace-project-lead/`.

All MCP filesystem servers are scoped to container paths (see `mcp-patch.json5`) — not host paths.

---

## 10. Meta: how this template was produced

Two Workflow runs during the initial build:

1. `adt-build-roles` — 7 parallel role-author subagents wrote every role package; then 7 parallel critique subagents adversarially reviewed each; then a cross-link audit checked handoff-graph symmetry.
2. `adt-fix-blockers` — applied the concrete fixes from critique + audit (deterministic-skills fixes for frontend, PROTOCOLS.md CC-field removal for qa, missing skills `bootstrap-test-plan` / `seed-test-accounts`, handoff-graph symmetrization across all 7 PROTOCOLS.md files).

Scripts saved under `.claude/projects/…/workflows/scripts/adt-build-roles-*.js` and `adt-fix-blockers-*.js` if you need to replay or learn the patterns.

**When making a substantive change to the template** (new role, new skill category, new invariant): follow the same pattern — author, adversarially critique, audit. Ultracode is on by default; use `Workflow` unless the change is a one-line edit.

---

## 11. Quick "what should I do first?" checklist

If you just booted into this repo and the user gives you a task:

1. `git log --oneline -5` — see what changed recently.
2. `docker ps --filter name=adt-test-1-02` — is the container up? `docker compose up -d` if not.
3. Read `data/adt-shared/CONVENTIONS.md`.
4. Read the affected agent's `ROLE.md` (if the task is agent-specific).
5. Only then edit.

The team's discipline lives in the files. Don't paper over it with clever code — edit the files.

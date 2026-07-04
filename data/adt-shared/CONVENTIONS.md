# ADT Shared Conventions (read before acting)

This file is identical in every agent's workspace at `~/CONVENTIONS.md` (symlink).
It is the **single source of truth** for cross-agent rules. If your role file disagrees with this, this file wins — file an `escalation` to project-lead about the conflict.

---

## 1. The team

| ID | Role | Owns |
|---|---|---|
| `project-lead` 🧭 Atlas | Orchestration, requirements, tickets, prioritization | `docs/project/`, `docs/tickets/`, `docs/board.md` |
| `architect` 🏛️ Cassius | Stack, contracts, structure, ADRs | `docs/architecture/` |
| `backend` 🔧 Forge | API, DB, server logic | `project/backend/` |
| `uiux` 🎨 Iris | UI spec, flows, Figma, tokens | `docs/ui/` |
| `frontend` 💠 Vela | Client app, components, state | `project/frontend/` |
| `reviewer` 🔍 Mira | PR review, gating | `docs/reviews/` |
| `qa` 🐛 Krell | E2E tests, bugs, regression | `docs/qa/`, `project/qa-tests/` |

The **user** is the final stakeholder. They talk to `project-lead` only. `project-lead` is the only agent allowed to address the user directly without a chain of trust.

There is **no `main` agent in the team** — `project-lead` is the default agent and the user's front door.

---

## 2. Repositories (template mode)

This OpenClaw setup is a **reusable template**. On startup there is no project yet.

When a project is onboarded, project-lead names it (slug `<project>`) and creates two remote repos:

1. `<project>` — the source code repo
2. `<project>-docs` — the planning/architecture/UI/QA docs repo

Each code/doc-touching agent clones BOTH into its own workspace:

```
~/.openclaw/workspace-<agent>/
├── project/   ← git clone of <project>
└── docs/      ← git clone of <project>-docs
```

`project-lead` and `uiux` only need `docs/`. `reviewer` clones `project/` read-only. All others clone both r/w (constrained to their own subtrees by convention).

Git remote can be **GitHub.com, Gitea, Forgejo, or GitLab** — the CLI is host-agnostic. The first onboarding skill (`onboard-project`) asks the user for the remote URL.

### Branch & PR naming

- Branches: `<agent>/<TICKET-ID>-<slug>` (e.g. `backend/TASK-12-jwt-refresh`)
- PR title: `[<TICKET-ID>] <imperative one-line>`
- Commit subject: `[<TICKET-ID>] <imperative>`
- Reviewer gate: no `main` push, no self-merge.

---

## 3. Ticket schema (frozen)

Every ticket file lives at `docs/tickets/<ID>.md` with this exact frontmatter:

```yaml
---
id: STORY-07
type: epic | story | task | bug
title: <short title>
parent: EPIC-02            # null for top-level
owner: backend             # canonical agent id or "unassigned"
status: backlog | ready | in_progress | in_review | qa | done | blocked
priority: P0 | P1 | P2 | P3
estimate: S | M | L | XL
created: <ISO-8601>
acceptance:
  - "criterion 1 (testable)"
  - "criterion 2"
depends_on: []
blocks: []
---
<body: context, scope, non-goals, open questions>
```

State machine: `backlog → ready → in_progress → in_review → qa → done`. `blocked` is a side state.

---

## 4. Agent-to-agent messages (frozen schemas)

Messages are JSON files written to `outbox/<ISO>-<to>-<type>.json` and delivered via the OpenClaw gateway. They are mirrored into the recipient's `inbox/`. Three types:

### 4.1 `handoff`
```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "architect",
  "ticket_id": "EPIC-02",
  "artifact_paths": ["docs/tickets/EPIC-02.md", "docs/requirements/Q&A-billing.md"],
  "summary": "Billing epic — ready for feasibility review",
  "acceptance": ["arch produces feasibility-report-EPIC-02.md within 1 cycle"],
  "blocking_questions": []
}
```

### 4.2 `question`
```json
{
  "type": "question",
  "from": "backend",
  "to": "architect",
  "ticket_id": "TASK-12",
  "question": "openapi.yaml says 'string' for amount but data-model says 'decimal'. Which is canonical?",
  "why_blocking": "cannot scaffold endpoint until resolved",
  "options_considered": ["use string + parse", "request schema fix"]
}
```

### 4.3 `escalation`
```json
{
  "type": "escalation",
  "from": "architect",
  "to": "project-lead",
  "severity": "high",
  "summary": "Requirement R-4 incompatible with chosen stack",
  "requested_decision": "drop R-4 or change stack",
  "options": ["scope cut", "stack migration ADR-008"],
  "recommendation": "scope cut for v1; revisit in v2"
}
```

`severity ∈ {low, med, high, blocker}`. `to: "user"` is only valid from `project-lead`.

---

## 5. Workspace file layout (every agent)

```
workspace-<agent>/
├── AGENTS.md           ← OpenClaw base, customized per agent
├── SOUL.md             ← persona
├── IDENTITY.md         ← name/emoji/role
├── USER.md             ← who tasks me + who I serve
├── TOOLS.md            ← MCP server scopes for this agent
├── ROLE.md             ← the role contract (THIS IS THE TOP-OF-SESSION READ)
├── WORKFLOWS.md        ← deterministic state machines
├── PROTOCOLS.md        ← message schemas + addressing
├── CONVENTIONS.md      ← symlink to /home/node/.openclaw/adt-shared/CONVENTIONS.md
├── MEMORY.md           ← per-agent long-term memory (private to this agent)
├── memory/YYYY-MM-DD.md
├── inbox/              ← incoming messages (read; do not delete — archive after processing)
├── outbox/             ← outgoing messages (audit log)
├── skills/<name>/SKILL.md
├── code/               ← ALL git clones and code go here (runtime, not in git)
├── docs/               ← ALL documents, specs, notes go here (runtime, not in git)
└── misc/               ← everything else (runtime, not in git)
```

**Workspace layout rules (mandatory):**
- `code/`, `docs/`, `misc/` are the only permitted locations for runtime-generated content.
- `code/` — git clones, source trees, generated code artefacts.
- `docs/` — specifications, ADRs, notes, design docs, review outputs.
- `misc/` — scratch files, temporary artefacts, anything that doesn't fit above.
- **Never create files or directories at workspace root** other than the known template files listed above. If you need to create something new, it goes inside `code/`, `docs/`, or `misc/`.

**Session startup order** (every wake):
1. **Authenticate git** — run the git-auth block from §11 before any git/gh command.
2. Read `ROLE.md` — what you do
3. Read `WORKFLOWS.md` — how you do it
4. Read `CONVENTIONS.md` (this file) — team rules
5. Scan `inbox/` — anything new
6. Pull `docs/` if you clone it
7. Look at `docs/board.md` for the current state

---

## 6. Forbidden actions (every agent)

1. Never write into another agent's `workspace-*` directory.
2. Never `git push --force` on `main`, `develop`, or release branches.
3. Never delete branches you do not own.
4. Never modify another agent's `ROLE.md`, `WORKFLOWS.md`, `PROTOCOLS.md`, `SOUL.md`, `IDENTITY.md`.
5. Never store secrets in committed files. Use `LITELLM_API_KEY` / `FIGMA_TOKEN` / etc. — env-var injection only.
6. Never bypass the reviewer for shared-branch merges. **Developer agents never self-merge their own PRs, ever.**
7. Never silently absorb scope creep — escalate.
8. Never invent acceptance criteria; copy them from the ticket.
9. Never claim a ticket whose `depends_on` are not all `done`.
10. Never address the user directly unless you are `project-lead`.
11. Never let a blocked task stop all other work. A blocked task means that specific task is paused; every other unblocked task must continue in parallel.
12. Never create files or directories at workspace root. All runtime output goes into `code/`, `docs/`, or `misc/` (see §5).

---

## 7. Quality gates that apply to all code work

1. Lint + format passes.
2. Type-check passes.
3. Unit tests for touched files exist and pass.
4. PR description contains the verbatim Acceptance checklist from the ticket.
5. Reviewer's verdict is `approve` (`request_changes` blocks merge).
6. **Developer docs exist**: the repo has a `README.md` and `docs/project/dev-env.md` with working local-run instructions.
7. **QA has run E2E tests** against the running environment for this Story; all S1/S2 bugs are `closed` with regression tests before the Story moves to `done`.
8. **Docker is the default** for reproducible dev environments. If the project setup does not use Docker, an explicit ADR must justify the exception.

---

## 8. The single LLM

Every agent uses `litellm/anthropic--claude-opus-4-6` via the host LiteLLM at `host.docker.internal:6655`. Do not assume capabilities not in that model.

---

## 9. The "no project yet" state

On a fresh template, `docs/` and `project/` do not exist. Each agent's session-start routine checks for them; if absent, the agent enters **STANDBY** and replies only with:

> "STANDBY: no project onboarded yet. Waiting for project-lead to run `onboard-project`."

`project-lead` runs `onboard-project` once the user provides project intent + remote URLs.

---

## 10. Updating this file

Only `project-lead` may propose changes to `CONVENTIONS.md`. Other agents file an `escalation` with `requested_decision: "amend conventions §N"`.

---

## 11. Git authentication (all agents)

Every agent that uses git/gh MUST configure auth at the start of every session using `GIT_HOST_TOKEN`. Run:

```bash
# Authenticate gh CLI
echo "$GIT_HOST_TOKEN" | gh auth login --with-token 2>/dev/null || true

# Configure git credentials for HTTPS remotes
git config --global credential.helper store
# Set credentials for the actual host (adapt URL to the real git host):
printf "https://x-token:%s@github.com\n" "$GIT_HOST_TOKEN" >> ~/.git-credentials 2>/dev/null || true

# Verify
gh auth status 2>&1 | head -3
```

**If `GIT_HOST_TOKEN` is empty or auth fails:** do NOT attempt git/gh operations. If you are `project-lead`, escalate to the user. If you are any other agent, file an `escalation` to `project-lead` with `severity: blocker` and `summary: "GIT_HOST_TOKEN missing or invalid — git operations blocked"`.

This must be done **before** any `git clone`, `git push`, `gh pr create`, or similar command.

---

## 12. Agent-to-agent message delivery

Messages are NOT delivered by writing a file to `outbox/` alone. Writing to `outbox/` is the **audit log** — it does not deliver the message.

**To actually deliver a message**, use the OpenClaw `sessions_send` tool (or equivalent gateway call) **after** writing the outbox file. Example sequence:

1. Write `outbox/<ISO>-<to>-<type>.json` (audit record).
2. Call `sessions_send` (or `send_message` / equivalent) with `to: "<agent-id>"` and the JSON payload.

If `sessions_send` is unavailable, log a warning to `memory/YYYY-MM-DD.md` and escalate to `project-lead`. Do not assume a message was delivered just because the outbox file was written.

---

## 13. Self-merge prohibition (single PAT context)

When the team runs with a single shared `GIT_HOST_TOKEN`, that token represents one identity on the git host. **A PR opened under that identity cannot be approved or merged by the same identity.**

The process is fixed:
- **Developer** (backend or frontend) opens the PR → requests review from `reviewer` (Mira).
- **Reviewer** (Mira) posts the review, posts verdict, and **merges** the PR after approval.
- Developer never calls `gh pr merge` or equivalent on their own PRs.
- Reviewer never merges a PR that lacks her own `APPROVE` verdict.

This rule survives session resets. It is never overridden, even if a new session "forgets" the prior state.

---

## 14. Frontend–backend contract compatibility

1. **Architect commits generated API contracts first.** Before any feature work starts, `project/.architecture/contracts/` must contain the generated client matching the current `openapi.yaml`. Developers consume the client — they do not hand-roll HTTP calls.
2. **Architect runs a compatibility audit** on every PR that touches `openapi.yaml` or `data-model.md`. The audit handoff goes to both backend and frontend.
3. **QA verifies contract compatibility** during INTAKE: calls the running API with the generated client's types and confirms the response shapes match.
4. **Architect owns the generated contracts** — no developer edits `project/.architecture/contracts/**` directly. If a contract is wrong, file a `question` to the architect.
5. Frontend and backend are considered **incompatible** if the generated API client cannot compile cleanly against the current backend codebase. This blocks QA from marking the Story testable.

---

## 15. Developer documentation requirements

Every developer agent (backend, frontend) MUST maintain:

- **`README.md`** at the root of their owned subtree: what it does, tech stack, how to install, how to run locally, how to run tests.
- **`docs/project/dev-env.md`** (owned by backend, reviewed by architect): step-by-step instructions to boot the full stack (database, API server, frontend dev server) from a clean checkout.
- **Inline code docs**: non-obvious logic gets a comment (why, not what). Public functions/endpoints get a one-line doc comment.
- **Architecture rationale**: every non-trivial design choice that is not already in an ADR gets a `NOTE:` or `DECISION:` comment referencing the ADR if one exists.
- **Docker setup** (`docker-compose.yml` + `Dockerfile`) is the canonical way to run the project. Any developer who writes `docs/project/dev-env.md` MUST include Docker-based instructions as the primary path.

Failing to maintain docs is a quality-gate failure. Reviewer blocks PRs that add code without updating affected docs.

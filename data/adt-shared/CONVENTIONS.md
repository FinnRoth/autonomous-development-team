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
├── docs/               ← git clone of <project>-docs (if applicable)
├── project/            ← git clone of <project> (if applicable)
└── skills/<name>/SKILL.md
```

**Session startup order** (every wake):
1. Read `ROLE.md` — what you do
2. Read `WORKFLOWS.md` — how you do it
3. Read `CONVENTIONS.md` (this file) — team rules
4. Scan `inbox/` — anything new
5. Pull `docs/` if you clone it
6. Look at `docs/board.md` for the current state

---

## 6. Forbidden actions (every agent)

1. Never write into another agent's `workspace-*` directory.
2. Never `git push --force` on `main`, `develop`, or release branches.
3. Never delete branches you do not own.
4. Never modify another agent's `ROLE.md`, `WORKFLOWS.md`, `PROTOCOLS.md`, `SOUL.md`, `IDENTITY.md`.
5. Never store secrets in committed files. Use `LITELLM_API_KEY` / `FIGMA_TOKEN` / etc. — env-var injection only.
6. Never bypass the reviewer for shared-branch merges.
7. Never silently absorb scope creep — escalate.
8. Never invent acceptance criteria; copy them from the ticket.
9. Never claim a ticket whose `depends_on` are not all `done`.
10. Never address the user directly unless you are `project-lead`.

---

## 7. Quality gates that apply to all code work

1. Lint + format passes.
2. Type-check passes.
3. Unit tests for touched files exist and pass.
4. PR description contains the verbatim Acceptance checklist from the ticket.
5. Reviewer's verdict is `approve` (`request_changes` blocks merge).

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

# ADT Shared Conventions (read before acting)

This file is identical in every agent's workspace at `~/CONVENTIONS.md` (symlink).
It is the **single source of truth** for cross-agent rules. If your role file disagrees with this, this file wins — file an `escalation` to project-lead about the conflict.

---

## 1. The team

| ID | Role | Responsibility |
|---|---|---|
| `project-lead` 🧭 Atlas | Orchestration, requirements, tickets, prioritization | Sole writer of tickets, board, vision, risk register, decision log |
| `architect` 🏛️ Cassius | Stack, contracts, structure, ADRs | Sole writer of `architecture/` in the docs repo; sole writer of generated contracts in code repos |
| `backend` 🔧 Forge | API, DB, server logic | Writes backend source and tests in the designated code repo(s); paths defined by `folder-structure.md` |
| `uiux` 🎨 Iris | UI spec, flows, Figma, tokens | Sole writer of `ui/` in the docs repo |
| `frontend` 💠 Vela | Client app, components, state | Writes frontend source and tests in the designated code repo(s); paths defined by `folder-structure.md` |
| `reviewer` 🔍 Mira | PR review, gating | Sole writer of `reviews/` in the docs repo; the only agent that merges PRs |
| `qa` 🐛 Krell | E2E tests, bugs, regression | Sole writer of `qa/` in the docs repo; writes QA test files in code repos at the path defined by `folder-structure.md` |

The **user** is the final stakeholder. They talk to `project-lead` only. `project-lead` is the only agent allowed to address the user directly without a chain of trust.

There is **no `main` agent in the team** — `project-lead` is the default agent and the user's front door.

---

## 2. Repositories (template mode)

This OpenClaw setup is a **reusable template**. On startup there is no project yet.

### 2.1 Repository model

Every project has:

- **One `docs` repo** — the single central documentation repository. Contains all planning, tickets, ADRs, UI specs, QA artefacts, and project-level overviews. Always present. Additional docs repos may be added later if the user or `project-lead` decides they are needed, but the default is one.
- **One or more `code` repos** — source code that gets built, tested, and deployed. The number and names are determined by the project architecture. The `architect` proposes the code repo list during `EPIC-01` (before any code exists); the user confirms before repos are created.

Every repo entry in `docs/<docs-repo-name>/project/repos.md` has:

| Field | Meaning |
|---|---|
| `name` | The repo name exactly as it appears on the git host (e.g. `my-project-backend`). This is also the local clone directory name. |
| `type` | `code` or `docs` |
| `url` | HTTPS or SSH clone URL |

Common layouts (examples only):

| Project type | Repos |
|---|---|
| Monolith | one `code` repo + one `docs` repo |
| Split frontend/backend | two `code` repos + one `docs` repo |
| Microservices | N `code` repos + one `docs` repo |

### 2.2 Per-agent workspace cloning

Each agent clones only the repos it needs into its own workspace:

```
~/.openclaw/workspace-<agent>/
├── docs/
│   └── <docs-repo-name>/   ← git clone of the docs repo
├── code/
│   ├── <code-repo-name>/   ← git clone of a code repo
│   └── <code-repo-name>/   ← git clone of another code repo (if needed)
└── misc/                   ← scratch files, not committed anywhere
```

`docs/` and `code/` are **containers** — the actual clone sits one level inside, named after the repo. `misc/` is for temporary work only.

> **Docs repo structure** is fixed and canonical. See `DOCS-REPO-STRUCTURE.md` (in `adt-shared/agent-files/`, symlinked into every workspace) for the full directory tree, per-directory ownership, and LLM retrieval rules. Every docs repo must follow that structure exactly.

Cloning rules by role:

| Agent | Clones |
|---|---|
| `project-lead` | `docs` repo (r/w) |
| `architect` | `docs` repo (r/w); all `code` repos (read + own branches r/w) |
| `backend` | `docs` repo (read); the `code` repo(s) containing backend subtrees (r/w on own subtrees) |
| `uiux` | `docs` repo (r/w on `ui/` subtree); no `code` repos |
| `frontend` | `docs` repo (read); the `code` repo(s) containing frontend subtrees (r/w on own subtrees) |
| `reviewer` | `docs` repo (r/w on `reviews/`); all `code` repos (read-only; r/w only for merge commits) |
| `qa` | `docs` repo (r/w on `qa/`); the `code` repo(s) containing `qa-tests/` subtrees (r/w on that subtree) |

Paths within a repo are defined by `architecture/folder-structure.md` in the docs repo (owned by architect). No agent invents paths — all paths come from that file.

Git remote can be **GitHub.com, Gitea, Forgejo, or GitLab** — the CLI is host-agnostic.

### 2.3 GitLab Flow — branching strategy

ADT uses **GitLab Flow**. The rules:

**Permanent branches:**

| Branch | Purpose |
|---|---|
| `main` | Always deployable. No direct commits. Merged into only via reviewed PRs. |
| `staging` | Optional. Tracks what is deployed to staging. Merge `main` → `staging`. |
| `production` | Optional. Tracks what is deployed to production. Merge `staging` → `production` (or `main` → `production` if no staging). |

**Feature branches** (the day-to-day):

- Branch off `main`.
- Name: `<agent>/<TICKET-ID>-<slug>` (e.g. `backend/TASK-12-jwt-refresh`).
- PR targets `main`.
- Deleted after merge.

**Hotfix branches:**

- Branch off `main`.
- Name: `hotfix/<TICKET-ID>-<slug>` (e.g. `hotfix/BUG-09-double-charge`).
- PR targets `main`; after merge, cherry-pick to `production` (and `staging` if it exists) via separate PRs.

**Rules:**

- No commits directly to `main`, `staging`, or `production`.
- No `git push --force` on any permanent branch.
- `staging`/`production` branches are advanced by merge from upstream — never force-updated to a SHA.
- Environment branches (`staging`, `production`) are created only if the project requires them; `main`-only is valid for projects without a separate deployment pipeline.

**PR naming:**

- Title: `[<TICKET-ID>] <imperative one-line>`
- Commit subject: `[<TICKET-ID>] <imperative>`
- Reviewer gate: no permanent-branch push, no self-merge.

### 2.4 Board API coordination model

ADT uses a central **board-api** service (FastAPI + SQLite, at `http://board-api:3000` on the `adt-internal` Docker network) as the **sole authoritative store** for all tickets. board-api IS the ticket store. Agents read from and write to board-api only. There are no markdown ticket files. There is no `board.md`. There is no dual-write, no mirroring, no sync.

**Self-assignment protocol:**

Instead of waiting for a `handoff` from `project-lead`, agents in roles `backend`, `frontend`, `uiux`, and `architect` poll board-api via their heartbeat using the `board_get_ready_tickets(owner=<role>)` MCP tool. If a ready ticket is returned, the agent calls `board_claim_ticket(id, agent)`. This is an **atomic operation** — SQLite `BEGIN IMMEDIATE` prevents two agents from claiming the same ticket simultaneously.

**Rules:**
- Only `project-lead` creates and edits ticket metadata (id, title, type, parent, acceptance, depends_on). Workers read, claim, and transition status only.
- The claim endpoint enforces: `status == ready`, `claimed_by IS NULL`, and all `depends_on` have `status == done`.
- A `409` response from `board_claim_ticket` means another agent won the race or deps are unmet; re-poll.
- On every status transition, agents call `board_transition_ticket` to update board-api. board-api is the only record — no markdown file is updated.

**Coordination and messaging both flow through board-api.** Task assignment happens by self-claim (above). All agent-to-agent messages — `handoff`, `question`, `escalation` — are **ticket comments** (§4), posted with `board_add_comment` and read with `board_get_unread`.

**Role of comments in this model:**
Comments (`handoff`, `question`, `escalation`) are the protocol for:
- Contextual dispatches where the ticket body is insufficient (e.g., uiux design kickoffs, architect feasibility reports).
- Reviewer PR notifications (backend/frontend → reviewer, as a `handoff` on the ticket).
- QA bug reports (qa → project-lead, backend/frontend, reviewer, via `notify`).
- Priority overrides and re-assignments from project-lead.
- All escalations at every level.

Comments are **not** used for routine task assignment to backend, frontend, uiux, or architect — these roles self-claim from board-api.

**SYSTEM-00 — the non-ticket channel.** board-api seeds a permanent `SYSTEM-00` ticket at startup. Escalations and questions that do not belong to any project ticket — boot-time problems (missing `GIT_HOST_TOKEN`), "no project onboarded yet", or cross-cutting decisions with no parent Epic — are posted as comments on `SYSTEM-00`. It never transitions to `done`.

---

## 3. Ticket schema (frozen)

The ticket schema is stored in board-api only. Fields: `id`, `type`, `title`, `parent`, `owner`, `status`, `priority`, `estimate`, `created`, `acceptance` (JSON array), `depends_on` (JSON array of ticket IDs), `blocks` (JSON array), `claimed_by` (set atomically by `board_claim_ticket`; null until claimed), `claimed_at` (ISO-8601 timestamp of the atomic claim), `body` (narrative context), `updated_at`.

State machine: `backlog → ready → in_progress → in_review → qa → done`. `blocked` is a side state.

Use `board_get_ticket(id)` to read any ticket. Use `board_create_ticket` to create (project-lead only). Use `board_transition_ticket` to change status. Never read ticket data from any markdown file.

---

## 4. Agent-to-agent messages (board-api comments)

**All agent-to-agent communication happens as comments on board-api tickets.** A comment is delivered the instant board-api stores it; the recipient sees it on their next heartbeat via `board_get_unread`. This is the single messaging channel (see §12).

A comment is posted with `board_add_comment` and has these fields:

| Field | Meaning |
|---|---|
| `ticket_id` | The ticket the comment is posted on. For a handoff, this is the **destination** ticket (the one the recipient will act on). |
| `author` | Your agent id (the sender). |
| `type` | One of `handoff`, `question`, `escalation` (actionable — **require `to`**), or `info`/`comment` (non-actionable notes). |
| `body` | The message text. Put the structured content (summary, acceptance, options, etc.) here as readable prose or a small labelled block. |
| `to` | The recipient agent id. **Required** for `handoff`, `question`, `escalation`. This is who gets it in `board_get_unread`. |
| `notify` | Optional array of additional agent ids who should also see it (e.g. loop in `frontend` on a backend↔architect contract answer). |
| `from_ticket` | Optional. On a handoff, the **source** ticket id, so "TASK-12 done → TASK-13 is yours" is explicit. |

The recipient calls `board_get_unread(<self>)` each heartbeat, handles each comment per `WORKFLOWS.md`, then calls `board_ack_comment(comment_id, <self>)` to clear it.

The three actionable types:

### 4.1 `handoff` — "this ticket (and its context) is now yours"

Posted on the **destination** ticket. Routine task assignment to `backend`/`frontend`/`uiux`/`architect` does NOT use a handoff — those roles self-claim ready tickets from board-api (§2.4). Handoffs are for context-carrying dispatches: PR-ready notifications to `reviewer`, merged→test notifications to `qa`, feasibility kickoffs, priority overrides.

```
board_add_comment(
  ticket_id="EPIC-02",          # destination ticket
  author="project-lead",
  to="architect",
  type="handoff",
  from_ticket=null,
  body="Billing epic — ready for feasibility review. Artifacts: "
       "requirements/Q&A-billing.md. Acceptance: architect produces "
       "feasibility/feasibility-report-EPIC-02.md within 1 cycle."
)
```

### 4.2 `question` — "I need an answer before I can proceed"

Posted on the ticket the question is about. If the question is not about any one ticket, post it on the parent Epic, or on `SYSTEM-00` if there is none.

```
board_add_comment(
  ticket_id="TASK-12",
  author="backend",
  to="architect",
  type="question",
  body="api/billing/openapi.yaml says 'string' for amount but data-model says 'decimal'. "
       "Which is canonical? Blocking: cannot scaffold the endpoint until resolved. "
       "Options considered: (a) use string + parse, (b) request schema fix."
)
```

### 4.3 `escalation` — "this needs a decision above my authority"

Posted on the affected ticket, or on `SYSTEM-00` for boot-time / non-ticket problems (§2.4). Only `project-lead` may then relay to the user.

```
board_add_comment(
  ticket_id="TASK-31",
  author="architect",
  to="project-lead",
  type="escalation",
  body="severity: high. Requirement R-4 incompatible with chosen stack. "
       "Requested decision: drop R-4 or change stack. "
       "Options: (a) scope cut, (b) stack migration ADR-008. "
       "Recommendation: scope cut for v1; revisit in v2."
)
```

`severity ∈ {low, med, high, blocker}` is stated in the `body` of an escalation. A recipient of `to: "user"` is only ever valid when `author` is `project-lead` — and `project-lead` relays to the user via chat, not via a comment.

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
├── memory/YYYY-MM-DD.md  ← private daily journal (not a comms channel)
├── skills/<name>/SKILL.md
├── docs/
│   └── <docs-repo-name>/   ← git clone of the docs repo (runtime, not in git)
├── code/
│   └── <code-repo-name>/   ← git clone of a code repo (runtime, not in git; one subdir per repo)
└── misc/                   ← scratch files, temporary artefacts (runtime, not in git)
```

**Workspace layout rules (mandatory):**
- `docs/`, `code/`, and `misc/` are the only permitted locations for runtime-generated content.
- Agent-to-agent messages are **board-api comments** (§4).
- `docs/<name>/` — git clone of the docs repo, named after the repo as it appears on the git host.
- `code/<name>/` — git clone of a code repo, named after the repo. One subdirectory per repo; clone only those your role requires (see §2.2).
- `misc/` — scratch files, temporary artefacts, anything that does not belong in a repo.
- **Never create files or directories at workspace root** other than the known template files listed above.
- **Never invent paths inside a repo.** All internal paths come from `architecture/folder-structure.md` in the docs repo (owned by architect). If that file does not exist yet, enter STANDBY.

**Session startup order** (every wake):
1. **Authenticate git** — run the git-auth block from §11 before any git/gh command.
2. Read `ROLE.md` — what you do
3. Read `WORKFLOWS.md` — how you do it
4. Read `CONVENTIONS.md` (this file) — team rules
5. Call `board_get_unread(<my-agent-id>)` — anything addressed to me since last wake
6. Read `docs/<docs-repo-name>/project/repos.md` if it exists — know the current repo list
7. Pull all repos you have cloned that have remote changes
8. Call `board_list_tickets()` to check the current board state.
9. For agents that self-assign (`backend`, `frontend`, `uiux`, `architect`): also call `board_get_ready_tickets(owner=<my-agent-id>)` to check for immediately claimable work.

---

## 6. Forbidden actions (every agent)

1. Never write into another agent's `workspace-*` directory.
2. Never `git push --force` on `main`, `staging`, `production`, or any other permanent branch.
3. Never delete branches you do not own.
4. Never modify another agent's `ROLE.md`, `WORKFLOWS.md`, `PROTOCOLS.md`, `SOUL.md`, `IDENTITY.md`.
5. Never store secrets in committed files. Use `LITELLM_API_KEY` / `FIGMA_TOKEN` / etc. — env-var injection only.
6. Never bypass the reviewer for shared-branch merges. **Developer agents never self-merge their own PRs, ever.**
7. Never silently absorb scope creep — escalate.
8. Never invent acceptance criteria; copy them from the ticket.
9. Never call `board_claim_ticket` on a ticket not returned by `board_get_ready_tickets`. The ready endpoint enforces dependency resolution server-side. Never bypass it by calling claim directly on a ticket that was not in the ready list.
10. Never address the user directly unless you are `project-lead`.
11. Never let a blocked task stop all other work. A blocked task means that specific task is paused; every other unblocked task must continue in parallel.
12. Never create files or directories at workspace root. All runtime output goes into `docs/`, `code/`, or `misc/` (see §5).
13. Never invent file paths inside a repo. All paths come from `architecture/folder-structure.md` in the docs repo (owned by architect). If it is absent, enter STANDBY and escalate.
14. Never commit directly to `main`, `staging`, or `production` — all changes arrive via reviewed PRs only.
15. Never use files or `sessions_send` payloads to send agent-to-agent messages. The ONLY messaging channel is board-api comments (§4). Post with `board_add_comment`, read with `board_get_unread`.

---

## 7. Quality gates that apply to all code work

1. Lint + format passes.
2. Type-check passes.
3. Unit tests for touched files exist and pass.
4. PR description contains the verbatim Acceptance checklist from the ticket.
5. Reviewer's verdict is `approve` (`request_changes` blocks merge).
6. **Developer docs exist**: every `code`-type repo has a `README.md` and the shared `docs` repo has `project/dev-env.md` with working local-run instructions.
7. **QA has run E2E tests** against the running environment for this Story; all S1/S2 bugs are `closed` with regression tests before the Story moves to `done`.
8. **Docker is the default** for reproducible dev environments. If the project setup does not use Docker, an explicit ADR must justify the exception.
9. **pnpm is the default package manager** for all JavaScript/TypeScript projects. Use `npm` only if a dependency is strictly incompatible with pnpm and an ADR documents the exception. Never mix lockfiles in the same repo.

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

**If `GIT_HOST_TOKEN` is empty or auth fails:** do NOT attempt git/gh operations. If you are `project-lead`, escalate to the user. If you are any other agent, post an `escalation` comment on `SYSTEM-00` (there is no project ticket yet at boot) with `to: "project-lead"`, `severity: blocker`, and body `"GIT_HOST_TOKEN missing or invalid — git operations blocked"`.

This must be done **before** any `git clone`, `git push`, `gh pr create`, or similar command.

---

## 12. Message delivery = writing the comment

A message is delivered the instant `board_add_comment` stores it — that call is the entire send.

1. Post the message: `board_add_comment(ticket_id=..., author=<self>, to=<recipient>, type=<handoff|question|escalation>, body=...)`.
2. The recipient sees it on their next heartbeat via `board_get_unread(<recipient>)`, handles it, and calls `board_ack_comment(comment_id, <recipient>)`.

If `board_add_comment` returns an error, retry once; if it still fails, log to `memory/YYYY-MM-DD.md` — the board is the system of record and cannot be bypassed with a file.

**Wake-nudge (optional latency optimization only):** OpenClaw agent-to-agent messaging (`sessions_send`) is retained solely so `project-lead` can *nudge* a sleeping agent to run its heartbeat sooner. A nudge carries **no message content** — the content is always the board comment. An agent that receives a nudge simply runs `board_get_unread`. Never put a handoff/question/escalation payload in a `sessions_send` call.

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

1. **Architect commits generated API contracts first.** Before any feature work starts, the `.architecture/contracts/` directory (inside the relevant `code`-type repo, at the path declared in `folder-structure.md`) must contain the generated client matching the current `architecture/api/<service>/openapi.yaml`. Developers consume the client — they do not hand-roll HTTP calls.
2. **Architect runs a compatibility audit** on every PR that touches any `api/<service>/openapi.yaml` or `data-model.md`. The audit is posted as a `handoff` comment (with `notify`) to both backend and frontend.
3. **QA verifies contract compatibility** during INTAKE: calls the running API with the generated client's types and confirms the response shapes match.
4. **Architect owns the generated contracts** — no developer edits `.architecture/contracts/**` directly. If a contract is wrong, post a `question` comment to the architect.
5. Frontend and backend are considered **incompatible** if the generated API client cannot compile cleanly against the current backend codebase. This blocks QA from marking the Story testable.

---

## 15. Developer documentation requirements

Every developer agent (backend, frontend) MUST maintain:

- **`README.md`** at the root of their owned subtree within the relevant `code`-type repo: what it does, tech stack, how to install, how to run locally, how to run tests.
- **`project/dev-env.md`** in the `docs`-type repo (owned by backend, reviewed by architect): step-by-step instructions to boot the full stack (database, API server, frontend dev server) from a clean checkout.
- **Inline code docs**: non-obvious logic gets a comment (why, not what). Public functions/endpoints get a one-line doc comment.
- **Architecture rationale**: every non-trivial design choice that is not already in an ADR gets a `NOTE:` or `DECISION:` comment referencing the ADR if one exists.
- **Docker setup** (`docker-compose.yml` + `Dockerfile`) is the canonical way to run the project. Any developer who writes `project/dev-env.md` MUST include Docker-based instructions as the primary path.
- **pnpm** is used for all JS/TS install, run, and build commands. `npm` is only used if an ADR documents the exception (see §7.9).

Failing to maintain docs is a quality-gate failure. Reviewer blocks PRs that add code without updating affected docs.

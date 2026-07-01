---
name: bootstrap-stack
description: ONE-TIME first-project skill. Reads project-lead's onboarding Q&A and produces the foundational ADRs and skeleton architecture docs.
trigger: project-lead sends a `handoff` with ticket_id starting `BOOTSTRAP-` and artifact_paths including docs/project/onboarding-qna.md. Runs exactly once per project.
inputs:
  - docs/project/onboarding-qna.md (user's answers to PL's intake)
  - docs/project/vision.md (PL's distillation of project intent)
outputs:
  - docs/architecture/overview.md (initial)
  - docs/architecture/folder-structure.md (initial, with text canonical block)
  - docs/architecture/data-model.md (skeleton with required sections + empty Mermaid)
  - docs/architecture/api/openapi.yaml (skeleton: info, servers, security schemes, Error schema, /health probe)
  - docs/architecture/protocols.md (initial)
  - docs/architecture/adr/ADR-001-stack-choice.md (status: proposed)
  - docs/architecture/adr/ADR-002-folder-layout.md (status: proposed)
  - docs/architecture/adr/ADR-003-cross-cutting-protocols.md (status: proposed)
  - .gitkeep skeleton files in project/ matching folder-structure.md
---

# Procedure

1. Refuse to run if `docs/architecture/adr/ADR-001-*.md` already exists. This skill is one-time. If it exists, reply with `question` to project-lead asking whether they want a re-bootstrap (which requires explicit ADR supersession).
2. Read `docs/project/onboarding-qna.md` and `docs/project/vision.md` fully. Identify:
   - Domain (e.g., billing, social, marketplace)
   - Required runtimes (backend lang, frontend lang)
   - Datastore preferences (or "no preference")
   - Deploy target (containerized, serverless, VM, on-prem)
   - Non-functional requirements (latency, scale, compliance)
   - Team size and seniority signals (favors boring defaults)
3. Use `context7` to verify current stable versions of the candidate stacks before committing to them in ADR-001.
4. Use `sequential-thinking` to enumerate at least 2 stack alternatives, then pick.
5. Draft `ADR-001-stack-choice.md` via the `write-adr` skill. Default opinionated choices (overridable by Q&A):
   - Backend: Python 3.12 + FastAPI + SQLAlchemy + Pydantic v2, or Node 20 + NestJS + Prisma — pick by Q&A signal.
   - Datastore: PostgreSQL 16 + Alembic migrations.
   - Frontend: TypeScript + React 19 + Vite + TanStack Query, or Next.js 15 — pick by Q&A signal.
   - Auth: OIDC via a managed provider unless self-host requested.
   - Deploy: Docker Compose for dev; target chosen from Q&A.
6. Draft `ADR-002-folder-layout.md` (depends on ADR-001). Decision must reference the canonical tree.
7. Draft `ADR-003-cross-cutting-protocols.md`. Decisions to include:
   - Error envelope: `{ "error": { "code": "<UPPER_SNAKE>", "message": "<human>", "details": <object|null>, "request_id": "<uuid>" } }`.
   - Pagination: cursor-based, `limit` + `cursor`, response `next_cursor`.
   - Idempotency: `Idempotency-Key` header on every state-creating POST; 24h dedup window.
   - Versioning: URL-versioned (`/v1/...`); OpenAPI `info.version` follows semver; major bump → new URL prefix.
   - Auth: Bearer JWT; refresh via dedicated endpoint; scopes named `<resource>:<action>`.
   - Casing: snake_case in JSON bodies; camelCase in path params.
   - Time: all timestamps RFC-3339 UTC with `Z`.
   - Money: string-encoded decimal, minor units in metadata.
8. Write `docs/architecture/overview.md` containing:
   - One Mermaid `flowchart` block showing user → frontend → backend → datastore + external services.
   - A short prose paragraph naming each component and the ADR that pinned it.
9. Write `docs/architecture/folder-structure.md` with the `text canonical` block expected by `audit-folder-structure`. Include `backend/src`, `backend/tests`, `frontend/src`, `frontend/tests`, `qa-tests/`, `.architecture/contracts/`.
10. Write `docs/architecture/data-model.md` skeleton:
    - `## Entities` (empty placeholder note)
    - `## Relations` (empty)
    - `## Invariants` (empty)
    - `## ER Diagram` with ` ```mermaid erDiagram ` block containing a comment-only stub.
    - `## Changelog` with initial entry.
11. Write `docs/architecture/api/openapi.yaml` skeleton:
    - `openapi: 3.1.0`
    - `info.title` from project name; `info.version: 0.1.0`
    - `servers: [{url: http://localhost:8000/v1}]`
    - `components.securitySchemes.bearerAuth` (JWT)
    - `components.schemas.Error` matching protocols.md envelope
    - `paths: /health: get` returning 200 with a tiny schema
12. Write `docs/architecture/protocols.md` mirroring ADR-003's decisions in human-readable form, with a TOC.
13. Create `.gitkeep` files in `project/` for every directory in `folder-structure.md` `text canonical` block. Commit on `architect/BOOTSTRAP-skeleton` branch in the `<project>` repo.
14. Run `validate-openapi` against the skeleton openapi.yaml. Must PASS.
15. Run `audit-folder-structure`. Must report `zero-drift`.
16. Run `generate-contracts`. The skeleton will produce minimal types for `Error` and `/health` only.
17. Open PRs: one against `<project>-docs` (all docs), one against `<project>` (skeleton + contracts).
18. Send `handoff` to `reviewer` with all three ADRs and the skeleton docs.
19. Send `handoff` to `project-lead` summarizing what was bootstrapped; recommend acceptance of all three ADRs before any feature work begins.
20. After PRs are merged and ADRs accepted (per FREEZE state), update each ADR to `status: accepted`.
21. Append `memory/YYYY-MM-DD.md`: `bootstrap-stack complete → ADR-001/002/003 proposed`.
22. Refuse to run this skill again on this project from this point forward.

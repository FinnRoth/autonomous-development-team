# TOOLS — MCP servers Krell uses

This file declares which MCP servers Krell uses, and what scopes/paths each is authorised over. The actual wiring happens in a later step; this is the contract.

## Required MCP servers

### 1. `filesystem` — workspace-qa
- **Scope:** read/write within `~/.openclaw/workspace-qa/`
- **Used for:** reading inbox, writing outbox, updating local docs/qa scratchpads before commit, managing memory and skill files.
- **Forbidden:** anything outside `workspace-qa/`.

### 2. `git` — split scopes
- **`project/` (the code repo):**
  - **Read:** all paths.
  - **Write:** ONLY `project/qa-tests/**`. Never edit `project/backend/`, `project/frontend/`, or other agent-owned subtrees.
  - **Branching:** `qa/<TICKET-ID>-<slug>`.
- **`docs/` (the docs repo):**
  - **Read:** all paths.
  - **Write:** `docs/qa/**` (full ownership). May read but never write `docs/tickets/`, `docs/architecture/`, `docs/ui/`, `docs/reviews/`, `docs/project/`, `docs/board.md`.

### 3. `gh` CLI (or `glab`/`tea` per `GIT_HOST_CLI` env, default `gh`) — NOT an MCP server
- `gh` CLI (or `glab`/`tea` per `GIT_HOST_CLI` env, default `gh`): host-agnostic git-host commands (PRs, issues, reviews, comments). Token: `GIT_HOST_TOKEN` env var. Invoked via shell-exec, not via MCP.
- **Scope:** the same `<project>` and `<project>-docs` repos.
- **Used for:** opening PRs that add Playwright suites under `project/qa-tests/`; opening doc PRs that add cases, bug reports, coverage matrix; commenting on bug-report PR threads.
- **Forbidden:** PRs touching non-qa subtrees; self-approving PRs.

### 4. `openclaw-messaging`
- **Scope:** inbox/outbox in `workspace-qa/`.
- **Used for:** receiving handoffs from PL/reviewer/backend/frontend; sending bug-report handoffs and escalations.

### 5. `playwright` — THE KILLER TOOL (required, not optional)
- **Scope:** drive a real browser against the running app under test.
- **Used for:** every E2E test, every chaos-explore session, every bug repro, every regression check.
- **Capabilities I rely on:** navigate, click, fill, snapshot, screenshot, evaluate, network_requests (HAR), console_messages, network throttling via `browser_run_code`, resize (mobile viewport), tabs, file_upload.
- **HAR + console capture:** mandatory on every chaos-explore run; bug evidence is incomplete without them.

### 6. `context7` — Playwright docs
- **Scope:** docs lookup for Playwright API, selectors, assertions, and version-specific syntax.
- **Used for:** verifying exact API shape before writing a spec; resolving "is this still the recommended pattern" questions without guessing.
- **Use before writing any non-trivial Playwright code** — see CONVENTIONS.md §8, the single LLM may not reflect the latest Playwright release.

## Optional MCP servers

### 7. `curl` / generic HTTP MCP — API contract tests (flagged optional)
- **Scope:** issue raw HTTP requests against the running backend.
- **Used for:** API-level negative tests (forbidden payloads, malformed JSON, missing auth, wrong content-type) that are awkward to express through a browser.
- **Status:** request this server be wired if `openapi.yaml` exists and the project exposes an HTTP surface. If absent, Playwright's `request` context is the fallback.

## Local environment notes

### App-under-test endpoints
- `BACKEND_URL` — base URL of the running backend (set by project bootstrap, e.g. `http://localhost:8080`).
- `FRONTEND_URL` — base URL of the running frontend (e.g. `http://localhost:5173`).
- These are read from `docs/project/dev-env.md` once the project is onboarded.

### Test user accounts
- Seeded by project bootstrap; recorded in `docs/qa/test-accounts.md` after onboarding. Never store passwords in committed files — env vars only (CONVENTIONS.md §6, rule 5).

### Evidence capture conventions
- Screenshots: `docs/qa/bug-reports/evidence/BUG-NN/screenshot-<step>.png`
- HAR: `docs/qa/bug-reports/evidence/BUG-NN/network.har`
- Console: `docs/qa/bug-reports/evidence/BUG-NN/console.log`
- Video (when available): `docs/qa/bug-reports/evidence/BUG-NN/repro.webm`

### Browsers I test
Default matrix (overridable per project): Chromium, Firefox, WebKit. Mobile viewports: iPhone 13, Pixel 5.

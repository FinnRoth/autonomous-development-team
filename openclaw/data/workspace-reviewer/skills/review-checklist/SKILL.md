---
name: review-checklist
description: Run the full reviewer checklist against an in-flight PR and produce a structured verdict-input.
trigger: WORKFLOWS.md State 3 (CHECKLIST) — invoked once per PR after INTAKE has loaded all artifacts.
inputs: pr_number, ticket_id, head_sha, expected_paths (set), pr_diff (text), ticket file (parsed), openapi.yaml (parsed), ui-spec.md (parsed), data-model.md (parsed), ADRs (set), CI status (per check)
outputs: a verdict-input JSON object written to memory/<YYYY-MM-DD>.md under the current PR header, containing 14 (status, evidence, citation) tuples and aggregated counts.
---

## Procedure

This skill is deterministic. Run every step in order. Do not skip. Each step writes one tuple into `verdict-input.checks[<n>]`.

### Step 1 — Ticket linkage

1. Read the PR body via `gh pr view <pr_number> --json body --jq .body`.
2. Search for either `Closes #<ticket-num>`, `Fixes #<ticket-num>`, or a verbatim string `docs/tickets/<TICKET-ID>.md`.
3. If found → `status: pass, evidence: "<match>", citation: "rules.md §R-001"`.
4. If not found → `status: fail, evidence: "no ticket link", citation: "rules.md §R-001"`.

### Step 2 — Verbatim acceptance in PR body

1. Parse `acceptance` from the ticket frontmatter.
2. For each criterion, search the PR body for the exact string.
3. All present → `pass`. Any missing → `fail` with the missing strings as evidence; citation: `CONVENTIONS.md §7.4`.

### Step 3 — Each acceptance criterion is visibly addressed

1. For each acceptance criterion, search the diff (filenames + added lines) for at least one of:
   - a test file added/modified whose body mentions a keyword from the criterion (heuristic: nouns + verbs from the criterion);
   - a code-file diff hunk that adds/modifies a function whose name or docstring includes a keyword;
   - a comment in the PR description mapping the criterion to a file/line (`AC1 → src/auth/refresh.py:42`).
2. If every criterion has at least one mapping → `pass`. Otherwise `fail`, list the unmapped criteria.
3. Citation: `rules.md §R-002` (acceptance traceability).

### Step 4 — Lint/format passing on CI

1. `gh pr checks <pr_number> --json name,conclusion`.
2. Find checks whose names match the project's lint/format jobs (read from `docs/architecture/ci.md` or, fallback, search for `lint` or `format` substring).
3. All `success` → `pass`. Any `failure`/`cancelled` → `fail`. Missing job → `fail` with citation `CONVENTIONS.md §7.1`.

### Step 5 — Type-check passing on CI

1. Same as Step 4 but match the type-check job name (substring `typecheck`, `mypy`, `tsc`, etc.).
2. Citation: `CONVENTIONS.md §7.2`.

### Step 6 — Unit tests for touched files exist + pass

1. Compute touched code files from the diff (excluding tests/docs/config).
2. For each touched code file, locate a sibling test file (e.g. `foo.py` → `tests/test_foo.py`; `Foo.tsx` → `Foo.test.tsx`).
3. If a touched file has no matching test file in the diff (added or pre-existing) → `fail` for that file; citation: `CONVENTIONS.md §7.3`.
4. Verify the test CI job is `success`.

### Step 7 — Files outside expected paths

1. Compute the set of changed paths from the diff.
2. Compare against `expected_paths` (from INTAKE).
3. Any path outside → `fail`, list the offending paths; citation: `rules.md §R-003` (scope adherence).
4. If there is doubt, queue an `escalation` to `project-lead` (logged for State 4 to decide).

### Step 8 — OpenAPI contract adherence

1. If the diff touches any API handler/route, diff the PR's `openapi.yaml` (if modified) against `docs/architecture/openapi.yaml`.
2. For each modified handler, check method+path+request/response schema match the corresponding `openapi.yaml` entry.
3. Any mismatch → `fail`, list the mismatches; citation: `openapi.yaml#<endpoint>`.
4. If `openapi.yaml` was edited without an architect-tagged commit, downgrade severity but still `fail`; citation: `rules.md §R-004`.

### Step 9 — UI spec adherence

1. If the diff touches `project/frontend/`, check each modified component against the corresponding `docs/ui/ui-spec.md` section.
2. Verify: token names (spacing, color, type), copy strings, flow transitions.
3. Any mismatch → `fail`; citation: `ui-spec.md#<section-anchor>`.

### Step 10 — Data model adherence

1. If the diff touches DB models/migrations, compare entity/field names/types against `docs/architecture/data-model.md`.
2. Any drift → `fail`; citation: `data-model.md#<entity>`.

### Step 11 — Security smells

For each, scan the diff. Any positive hit → `fail`:
- Hard-coded credentials (regex: `(api[_-]?key|secret|password|token)\s*=\s*["'][^"']+["']`).
- Auth checks removed (regex on removed lines: `@auth_required|requires_auth|isAuthenticated`).
- SQL string interpolation (regex: `f["'].*SELECT.*\{|".*"\s*\+\s*\w+\s*\+\s*".*"`).
- `eval(`, `exec(`, `child_process.exec` with user input.
- CORS wildcard (`*`) on credentialed routes.

Citations: `rules.md §R-005` (no hard-coded secrets), `§R-006` (no auth removal without ADR), `§R-007` (no string-built SQL), `§R-008` (no eval), `§R-009` (no wildcard CORS).

### Step 12 — Performance smells

For each, scan the diff. Any positive hit → `fail` (downgrade to Suggested only if the author's PR body explicitly acknowledges):
- N+1: a loop containing an ORM `.get()` / `await fetch(` with a primary-key lookup.
- Unbounded loop: `while True:` without a clear exit.
- Sync I/O in async path (e.g. `open(` / `requests.get` inside an `async def`).
- Missing pagination on list endpoints / unbounded `SELECT *`.

Citations: `rules.md §R-010` … `§R-013`.

### Step 13 — Naming / dead code / comment style

1. Spot-check 5 random diff hunks for:
   - identifier style consistent with file surroundings (snake_case vs camelCase);
   - no obvious dead code (commented-out blocks > 3 lines);
   - no `TODO` without a ticket reference.
2. Any violation → record as `fail` but typically routes to **Suggested** unless `rules.md §R-014` applies.

### Step 14 — Non-happy-path test coverage

1. For each touched module, find at least one test that asserts an error case (raises, status≥400, returns an Err, etc.).
2. None found for a module → `fail` for that module; citation: `rules.md §R-015`.

---

## Output shape

Write into `memory/<YYYY-MM-DD>.md` under the current PR header:

```json
{
  "pr": <pr_number>,
  "ticket": "<TICKET-ID>",
  "head_sha": "<short>",
  "checks": [
    {"id": 1, "name": "ticket-linkage", "status": "pass|fail|n/a", "evidence": "...", "citation": "..."},
    ...
    {"id": 14, "name": "non-happy-path-tests", ...}
  ],
  "totals": {"pass": N, "fail": N, "n/a": N},
  "ci_status": "green|red|pending"
}
```

This object is the input to State 4 (COMMENT). Do not skip writing it — State 4 reads it back.

---
name: validate-openapi
description: Run swagger-cli validate on every service's OpenAPI single source of truth, plus enforce naming, version-bump, and breaking-change rules.
trigger: After any edit to a docs/architecture/api/<service>/openapi.yaml; also nightly via AUDIT; also before any `generate-contracts` run.
inputs:
  - docs/architecture/api/<service>/openapi.yaml (one per API-exposing service; <service> = repo name in project/repos.md)
  - previous version of the same file (git HEAD)
outputs:
  - stdout pass/fail with structured findings (per service)
  - on fail: a working-notes file at memory/YYYY-MM-DD-openapi-validate.md
---

# Procedure

> Run steps 1–9 **once per service** — loop over every `docs/architecture/api/<service>/openapi.yaml`. A monolith has one; a microservice project has one per service. FAIL if any service's spec fails.

1. Run `swagger-cli validate docs/architecture/api/<service>/openapi.yaml`. If exit != 0, capture full stderr and FAIL.
2. Confirm OpenAPI version is `3.1.x`. If not, FAIL with message "ADR-003 mandates OpenAPI 3.1; current is <X>".
3. Confirm top-level `info.version` is bumped relative to HEAD:
   - If the diff against HEAD contains any removed path, removed method, removed required field, or changed response status: require **major** bump.
   - If the diff adds new paths/methods/fields only: require **minor** bump.
   - If the diff is doc/example only: require **patch** bump.
   - Missing bump or wrong magnitude → FAIL.
4. Naming rules (FAIL on any violation):
   - Path segments: kebab-case, lowercase, plural nouns. `/customers/{customerId}/invoices` — yes; `/Customer/{id}` — no.
   - Path parameters: camelCase: `{customerId}`.
   - Request/response schema field names: snake_case (per ADR-protocols casing rule).
   - Operation ids: `lowerCamelCase`, verb-first: `createInvoice`, `listInvoices`.
   - Tags: PascalCase.
5. Error envelope check: every 4xx/5xx response references the shared `Error` schema (per protocols.md). FAIL if any error response inlines its body.
6. Pagination check: every endpoint returning a collection has parameters `limit` (int, default in spec) and `cursor` (string, optional). FAIL otherwise.
7. Idempotency check: every `POST` that creates a resource declares an `Idempotency-Key` header parameter.
8. Auth check: every operation has a `security` block, or the global `security` covers it.
9. If all checks pass, write the result line to stdout: `OK: openapi version <X.Y.Z>, <N> paths, <M> operations`. PASS.
10. If FAIL, write `memory/YYYY-MM-DD-openapi-validate.md` with the structured findings list and exit non-zero. The caller (workflow) handles the failure.

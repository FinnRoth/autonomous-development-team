---
name: generate-contracts
description: Emit TypeScript + Python types from openapi.yaml into project/.architecture/contracts/. Must be idempotent — a re-run on unchanged input produces an empty git diff.
trigger: After openapi.yaml passes validate-openapi and is merged on docs main; also at AUDIT to detect drift.
inputs:
  - docs/architecture/api/openapi.yaml
  - generator config (pinned versions; see ADR on contract generation)
outputs:
  - project/.architecture/contracts/typescript/*.ts
  - project/.architecture/contracts/python/*.py
  - project/.architecture/contracts/CHECKSUM (sha256 of openapi.yaml + generator versions)
---

# Procedure

1. Confirm `docs/architecture/api/openapi.yaml` exists and `validate-openapi` last result was PASS. If not, abort with FAIL.
2. Read pinned generator versions from `docs/architecture/adr/`. The relevant ADR (e.g., ADR on contract generation) MUST pin:
   - TS generator (e.g., `openapi-typescript@<X.Y.Z>`)
   - Python generator (e.g., `datamodel-code-generator@<X.Y.Z>`)
   If no such ADR exists, file an `escalation` (severity `med`) requesting permission to draft one and STOP.
3. Compute `sha256(openapi.yaml || generator_versions_string)`. Read existing `project/.architecture/contracts/CHECKSUM` if present.
4. If checksums match, exit 0 with `OK: contracts already current`. (Idempotency fast-path.)
5. Otherwise, run the TypeScript generator: emit to `project/.architecture/contracts/typescript/`. One file per OpenAPI tag, plus a top-level `index.ts` that re-exports.
6. Run the Python generator: emit to `project/.architecture/contracts/python/`. One module per OpenAPI tag; types are Pydantic v2 BaseModels. Add `__init__.py` that re-exports.
7. Header injection: prepend every generated file with:
   ```
   // GENERATED — DO NOT EDIT. Source: docs/architecture/api/openapi.yaml v<X.Y.Z>. Skill: generate-contracts.
   ```
   (Use `#` for Python.)
8. Write the new CHECKSUM file.
9. Run a second pass of the same generator commands in a temp directory; diff against the live output. The diff MUST be empty (idempotency). If non-empty, FAIL with `escalation` (severity `med`) — non-deterministic generator config.
10. Run language linters in check mode (`prettier --check` for TS, `ruff format --check` for Python). If they would reformat, run the formatters once and commit. Subsequent runs must produce zero changes.
11. Stage on branch `architect/<TICKET-ID>-contracts`. Commit subject `[<TICKET-ID>] contracts: regenerate from openapi v<X.Y.Z>`.
12. Push and open PR against `<project>` main. Title `[<TICKET-ID>] contracts: regenerate from openapi v<X.Y.Z>`. Body: list of changed paths, source ADR id.
13. Append `memory/YYYY-MM-DD.md`: `generate-contracts → <PASS|FAIL>, openapi v<X.Y.Z>`.

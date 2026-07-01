---
name: write-migration
description: Scaffold a reversible up/down migration from a data-model delta announced by the architect.
trigger: IMPLEMENT state — data-model.md introduces or modifies entities the current ticket touches.
inputs: TICKET_ID, list of schema deltas (new tables, altered columns, new indices, new constraints).
outputs: paired up/down migration files under project/migrations/**; dry-run log.
---

# write-migration

Deterministic procedure. I treat migrations as scary. I read twice, write once, dry-run three times.

1. **Read the source of truth twice**
   - First pass: open `docs/architecture/data-model.md`. List every entity, field, type, constraint, index that this ticket changes.
   - Second pass: re-read; compare against my list; fix discrepancies.
   - Cross-check with `docs/architecture/ADR-*.md` for the persistence ADR (DB engine, naming conventions, FK strategy, soft-delete policy).

2. **Resolve the migration tool**
   - Read the project's persistence ADR for the migration tool (e.g., `flyway`, `alembic`, `knex`, `prisma migrate`, `goose`, framework-native).
   - Read `project/migrations/README.md` if present; otherwise infer from existing migrations in `project/migrations/`.
   - Use `context7` for current syntax of the chosen tool's version.

3. **Generate the filenames** per the project convention. Standard pattern (override if ADR differs):
   - `project/migrations/<YYYY_MM_DD_HHMMSS>_<snake_case_description>_up.<ext>`
   - `project/migrations/<YYYY_MM_DD_HHMMSS>_<snake_case_description>_down.<ext>`
   - For tools that use a single file with both blocks (alembic, knex), still write both blocks fully — never leave `down` as a placeholder.

4. **Write the `up` migration**
   - One change per migration when feasible; if multiple, group only when atomic.
   - For new tables: explicit column types, NOT NULL where appropriate, FKs with `ON DELETE` policy from the ADR, indexes for declared lookup paths in data-model.md.
   - For altered columns: write the safe sequence (add column → backfill → drop old, in separate migrations if data exists).
   - For destructive changes (DROP, type narrow, NOT NULL on existing column): STOP. File a `handoff` to architect: "destructive migration requested for <table>.<col>; confirm or propose safe alternative." Do not proceed without architect ACK.

5. **Write the `down` migration**
   - It must reverse the `up` to the pre-migration schema state.
   - If the `up` drops data, the `down` recreates the schema but cannot recover data — call this out explicitly in a SQL comment AND in the PR `Risks` section.

6. **Dry-run cycle on a scratch DB** (local SQLite/Postgres container per ADR):
   - `migrate up` from latest pre-this-PR state → assert success.
   - `migrate down` → assert schema returns to pre-this-PR state (compare via the tool's introspection).
   - `migrate up` again → assert idempotency.
   - Any failure → fix and restart the cycle from step 4.

7. **Write a test** under `project/backend/tests/migrations/` if the project supports migration tests:
   - One test per new migration verifying up then down then up.
   - For ORMs without migration tests, add a smoke test that exercises a CRUD on the new schema.

8. **Update `Risks` section drafts**
   - Append to my memory note for this ticket: every risk this migration introduces (lock duration, backfill cost, data loss on down, FK cascade impact). This will land verbatim in the PR `Risks` section.

9. **Commit**
   ```sh
   git add project/migrations/<...>_up.* project/migrations/<...>_down.* project/backend/tests/migrations/<...>
   git commit -m "[<TICKET-ID>] migration: <short description>"
   ```

10. **Never run a migration against any DB other than the scratch dev DB.** Staging/prod migrations are not my concern — they are project-lead's during release.

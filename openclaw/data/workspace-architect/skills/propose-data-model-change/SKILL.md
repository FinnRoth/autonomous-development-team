---
name: propose-data-model-change
description: Produce a diff against docs/architecture/data-model.md, regenerate the Mermaid ER diagram, and prepare the change for ADR review.
trigger: ASSESS or PROPAGATE state determined the data model must change (new entity, new relation, field type change, invariant change).
inputs:
  - current docs/architecture/data-model.md
  - the change request (free-form: new entity, new field, modified relation, removed field, etc.)
  - associated ticket_id
outputs:
  - docs/architecture/data-model.md (modified, on a branch)
  - updated Mermaid ER block within the same file
  - inline change summary in the file's `## Changelog` section
---

# Procedure

1. Read `docs/architecture/data-model.md`. Confirm it has these sections: `## Entities`, `## Relations`, `## Invariants`, `## ER Diagram`, `## Changelog`. If any are missing, FAIL and post an `escalation` comment (severity `med`) — data-model.md is malformed.
2. Snapshot the current Mermaid ER block (between ` ```mermaid erDiagram ` and the closing fence) to a temp variable.
3. Apply the change request:
   - **Add entity** → append a subsection `### <EntityName>` under `## Entities` with fields table (`name | type | nullable | notes`), and add the entity node to the Mermaid block.
   - **Add field** → edit the entity's fields table.
   - **Modify field type** → change the type, AND add a `## Migration Notes` bullet under `## Changelog` describing the SQL-level migration.
   - **Remove field** → mark it as `DEPRECATED` first (do not delete the row); deletion requires a separate ADR.
   - **Add/modify relation** → edit `## Relations` and update Mermaid arrows.
4. Regenerate the ER diagram block (in-place between fences). Every entity must appear; every relation in `## Relations` must have a matching arrow.
5. Validate the Mermaid block: it must start with `erDiagram`, contain `||--o{` or `}o--||` style cardinalities, and have no orphan entities (every entity participates in at least one relation OR is explicitly marked `standalone: true` in its subsection).
6. Append a `## Changelog` entry:
   ```
   - YYYY-MM-DD — <TICKET-ID> — <one-line change>
   ```
7. Compute the unified diff between original and modified `data-model.md`. Print it to stdout. The diff is what the ADR's `## Decision` section will reference.
8. If the change is non-trivial (any of: new entity, breaking field type change, removed field), require an ADR. Hand control back to the workflow which will invoke `write-adr`.
9. Commit on branch `architect/<TICKET-ID>-data-model`. Commit subject `[<TICKET-ID>] data-model: <one-line summary>`.
10. Do NOT push or open a PR here — that happens in SOLICIT_REVIEW after the corresponding ADR is drafted.
11. Append `memory/YYYY-MM-DD.md`: `data-model change <TICKET-ID>: <summary>`.

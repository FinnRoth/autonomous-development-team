---
name: scaffold-endpoint
description: From an openapi.yaml operationId, generate route + handler + test stub in the correct folder per docs/architecture/folder-structure.md.
trigger: IMPLEMENT state: a new operationId from the assigned ticket needs a handler that does not yet exist.
inputs: OPERATION_ID (string matching an operationId in openapi.yaml), TICKET_ID
outputs: route file, handler file, test stub — all under project/backend/**.
---

# scaffold-endpoint

Deterministic procedure.

1. **Locate the operation** in `docs/contracts/openapi.yaml`.
   - Find the unique path+method whose `operationId == OPERATION_ID`.
   - Extract: HTTP method, path, parameters (path/query/header), request body schema ref, response schemas per status code, security requirements.
   - On not found: STOP, file `question` to architect.

2. **Resolve schemas** referenced by `$ref` in the operation. For each `$ref`, open the target schema and record field names, types, required flags, formats, and nested refs (recursively).

3. **Read folder structure** at `docs/architecture/folder-structure.md`. Extract:
   - Routes folder (e.g. `project/backend/src/routes/`).
   - Handlers/services folder.
   - Tests folder mirror.
   - Naming convention (e.g. `kebab-case.ts` vs `camelCase.ts`).

4. **Cross-check ADRs**:
   - Web framework ADR — which framework primitives to use (e.g., Express Router vs Fastify route vs Spring `@RestController`).
   - Validation ADR — which validator (zod, pydantic, etc.).
   - Error envelope ADR — error response shape; never invent one.

5. **Use context7** to pull current syntax for the chosen framework and validator versions (read `package.json` / `pyproject.toml` / `pom.xml` for the version pin first).

6. **Create the route file**
   - Path per step 3.
   - Bind `<method> <path>` to a named handler exported from the handler file (step 7).
   - Wire validators from the resolved schemas.
   - Wire auth middleware per the operation's security block.

7. **Create the handler file**
   - One exported function, named after `OPERATION_ID` in the project's case convention.
   - Signature: receives validated input + a context object containing services (no globals).
   - Body: TODO stub with `throw new Error("not implemented")` and a comment listing the acceptance criteria the handler must satisfy.
   - Return type matches the success response schema.

8. **Create the test stub** at the mirrored path under `project/backend/tests/`.
   - One `describe` per operation.
   - One `it` for each documented response status code in openapi.yaml.
   - One `it` per acceptance criterion from the ticket.
   - Each `it` body starts with `// arrange / act / assert` comments and an explicit `expect.fail("not implemented")` (or framework equivalent) so a run will list every unwritten test.

9. **Wire the route** into the application's route registrar per `folder-structure.md` (usually a central `routes/index.*`).

10. **Run lint + type-check** on the new files. They must pass with stubs present.

11. **Commit**
    ```sh
    git add <new files> <registrar>
    git commit -m "[<TICKET-ID>] scaffold <OPERATION_ID>"
    ```

12. **Append to memory**: the operationId, files created, and the acceptance-to-test mapping. The IMPLEMENT step will fill in handler bodies.

---
name: axe-check
description: Drive the running FE in headless Playwright and run axe-core on each touched route; report violations.
trigger: State 4 — TEST (mandatory before SELF_REVIEW); also called by self-review and open-pr.
inputs: A running FE dev server (locally launched if needed); list of routes touched by the current branch (derived from changed files or from the ticket's P-NN list); axe-core via @axe-core/playwright.
outputs: A report per route with violations grouped by impact (critical/serious/moderate/minor); exit 0 if no violations of impact ≥ serious on touched routes; embedded in PR body by open-pr.
---

# axe-check

1. **Determine routes.** Build the list of routes to check from:
   - Each new/modified page file's route (parsed from routing config or top-of-file `Spec: P-NN` → cross-reference `docs/ui/pages/P-NN.md` → `route:` field).
   - Plus any route in the ticket body listed as touched.

2. **Boot the dev server.** Use the project's dev-server command (recorded in `TOOLS.md` Local notes — e.g., `pnpm dev`, `npm run dev`, `vite`, etc.). Wait for the health URL to return 200, up to 60s. If it doesn't boot, STOP and log "dev server failed".

3. **Launch Playwright headless** via the `playwright` MCP. Use a fresh context per route to avoid cross-state pollution.

4. **For each route, for each of the 5 states (Loading, Empty, Error, Success, Disabled):**
   - Navigate to the route with a mock-state query param OR with a network mock that forces the state per the project's test-harness convention.
   - Inject and run `@axe-core/playwright` against the rendered document.
   - Capture violations.

5. **Filter results.**
   - Critical and Serious violations on touched routes → block (count against the 0-violations gate).
   - Moderate and Minor violations → report but do not block (still surface in PR body).

6. **Honor ADR-backed disables.** If a violation is suppressed by an inline `// axe-disable rule=<rule-id> ADR-<NN>` comment in the source, validate the ADR exists in `docs/architecture/adr/ADR-NN-*.md`. If valid → suppression honored. If ADR missing → violation stands.

7. **Output format.** Per route:

```
ROUTE /onboard/start
  state=loading  violations: 0 critical, 0 serious, 0 moderate, 0 minor
  state=empty    violations: 0 critical, 0 serious, 1 moderate (color-contrast — token-ok per ADR-007), 0 minor
  ...
ROUTE /onboard/done
  ...
SUMMARY: 0 critical, 0 serious — PASS (gate)
```

For any non-zero serious/critical violation, append:

```
  - rule: <axe-rule-id>
    impact: serious|critical
    nodes: <selectors>
    help: <axe help URL>
    suggested-fix: <one-line>
```

8. **Exit codes.** `0` if zero violations at serious/critical impact on touched routes. `1` otherwise.

9. **Disable-rule policy.** I do NOT disable axe rules without an ADR reference. If an axe rule legitimately must be tolerated, I file an `escalation` to project-lead severity=`med` requesting an ADR; I do not push the offending code until the ADR is merged.

10. **Caching/idempotency.** Re-running this skill must be deterministic given the same dev-server state. If results jitter, fail loud and log "non-deterministic axe result on <route>:<state>".

## On error

- Dev server won't boot → STOP, log; do NOT fake a pass.
- Playwright crashes on a route → fail that route as `1 critical`.
- Mock-state harness missing for a state → STOP, file `question` to uiux/architect (depending on whether the gap is spec or contract).

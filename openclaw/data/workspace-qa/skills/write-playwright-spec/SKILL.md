---
name: write-playwright-spec
description: Emit a Playwright spec scaffold from a case file, then implement and run it.
trigger: Case file is populated; entering AUTOMATE per WORKFLOWS.md §4.
inputs:
  - docs/qa/cases/<story-id>.md (populated)
  - project/qa-tests/ (existing Playwright project structure)
outputs:
  - project/qa-tests/<story-id>.spec.ts
  - updated case file (automated field, linked_test field)
  - PR on <project> repo
---

# write-playwright-spec

Deterministic spec-writing from a case file.

## Steps

1. **Read** the case file. List every case with `automated: yes` or `automated: partial` (these need test code). Cases marked `manual` are skipped here.

2. **Verify Playwright project exists** at `project/qa-tests/`. If not (first project bootstrap), create it:
   - Run `npm init playwright@latest -- --quiet --browser=chromium --gha=false qa-tests` from `project/`, then immediately `git status -- ':!project/qa-tests'` and ABORT if any file outside `project/qa-tests/` is dirty. If aborted, the generated stray files must be moved into `project/qa-tests/` or restored, then re-run.
   - Add `playwright.config.ts` with: projects for desktop chromium/firefox/webkit + mobile iPhone-13 + mobile Pixel-5; `use.baseURL` from `FRONTEND_URL` env; `use.trace: 'on-first-retry'`, `use.video: 'retain-on-failure'`, `use.screenshot: 'only-on-failure'`.
   - Commit baseline. PR title `[<STORY-ID>] qa: bootstrap qa-tests`.

3. **Check Playwright API** with `context7` if any case uses a non-trivial API (network interception, fixtures, parallel mode, `request` context, slow-mo). Never guess API shape from memory — see CONVENTIONS.md §8.

4. **Create branch** `qa/<STORY-ID>-tests` in `project/`.

5. **Author the spec** at `project/qa-tests/<story-id>.spec.ts` with this structure:

```ts
import { test, expect, devices } from '@playwright/test';

test.describe('<STORY-ID> — <story title>', () => {

  test.describe('Happy path', () => {
    test('HP-01 — <scenario>', async ({ page }) => {
      // steps from case <STORY-ID>-HP-01
      await page.goto('/');
      // ...
      await expect(page.getByRole('...')).toBeVisible();
    });
    // ...
  });

  test.describe('Edge cases', () => {
    test('EDGE-01 — unicode in name field', async ({ page }) => {
      // ...
    });
    // ...
  });

  test.describe('Negative cases', () => {
    test('NEG-01 — forbidden input rejected', async ({ page, request }) => {
      // API-level assertion
      const res = await request.post('/api/...', { data: { /* malformed */ } });
      expect(res.status()).toBe(400);
    });
    // ...
  });

  test.describe('Cross-cutting', () => {
    test('CC-A11Y — keyboard-only happy path', async ({ page }) => {
      // Tab through, no mouse.
    });

    test.use({ ...devices['iPhone 13'] });
    test('CC-MOBILE-iphone — happy path on iPhone 13', async ({ page }) => {
      // ...
    });
    // ...
  });

});
```

6. **Implement every test body**. Rules:
   - Use role-based locators (`getByRole`, `getByLabel`) over CSS selectors. Test-ids are last resort.
   - Use `expect(...).toBeVisible()` not arbitrary `waitForTimeout`. No sleeps.
   - For slow-network probes, use `await page.route(...)` to add latency, not `slowMo`.
   - For double-submit probes, fire two clicks without await: `await Promise.all([page.click(submit), page.click(submit)])` then assert only one network call (`page.on('request', ...)` count).
   - For "refresh mid-action", use `await page.reload()` between steps.
   - For "browser back during async", trigger the async then immediately `await page.goBack()`.
   - For HAR-recording on the test run (useful for later bugs), set `recordHar` in `test.use({ contextOptions: { recordHar: { path: ... } } })` — but only in tests that probe network.

7. **Run locally**: `cd project && npx playwright test qa-tests/<STORY-ID>.spec.ts --project=chromium`. Capture results.

8. **If a test fails on what should be happy path**: do NOT debug your own test first; assume the app is wrong. Run the failing scenario manually via `playwright` MCP, capture screenshot/HAR/console. If reproducible twice → exit this skill and enter REPORT state (file the bug). If not reproducible → your test is flaky; fix it.

9. **Update case file**: for each automated case, set `automated: yes` and `linked_test: project/qa-tests/<STORY-ID>.spec.ts::HP-01` (etc.). Update `Automation Status` block. The case file lives in the **docs repo**, so this update needs its own branch/commit/PR:
   - Switch to docs repo.
   - `git checkout -b qa/<STORY-ID>-automation`
   - Commit the case-file update with message `[<STORY-ID>] qa: link automated cases to specs`.
   - Push and open PR via `gh`; request reviewer (Mira). Do NOT self-merge.

   **AUTOMATE-state exit condition:** both PRs are open — the project-repo PR (qa-tests spec) AND the docs-repo PR (case-file update).

10. **Commit & PR**:
    - `git add project/qa-tests/<STORY-ID>.spec.ts`
    - `git commit -m "[<STORY-ID>] qa: E2E tests"`
    - `git push origin qa/<STORY-ID>-tests`
    - Open PR via `github` MCP: title `[<STORY-ID>] qa: E2E tests for <story title>`, base = default branch, body = link to case file + summary "Adds N cases (X happy, Y edge, Z negative, W cross-cutting). All passing on chromium."
    - Request review from `mira` (reviewer).

11. **Wait for review.** While waiting, transition to EXPLORE (WORKFLOWS.md §5).

## Failure modes
- Playwright API I'm using has changed → re-check via `context7`, fix, re-run.
- Test stable on chromium but flaky on webkit → file it as a known-flaky and add to `docs/qa/test-plan.md` flaky list; do NOT skip the test. Investigate next cycle.
- Cannot get the test under 30s — investigate; long tests are usually wrong tests.

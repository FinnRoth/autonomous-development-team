---
name: chaos-explore
description: Run a 30-minute adversarial chaos session against a Story's flow using the playwright MCP.
trigger: Entering EXPLORE per WORKFLOWS.md §5 — after automated cases are in place.
inputs:
  - docs/qa/cases/<story-id>.md
  - The running app (FRONTEND_URL, BACKEND_URL)
outputs:
  - Exploratory Log section of the case file, fully populated
  - Per-session artifacts under docs/qa/exploratory/<story-id>/<ISO-date>/ (network.har, console dumps, screenshots)
  - If a bug is found: evidence under docs/qa/bug-reports/evidence/BUG-NN/ (skill handoff to file-bug)
---

# chaos-explore

A 30-minute structured adversarial exploration. Stop early only if a bug is reproduced twice.

## Setup

1. Set a hard timer for 30 minutes.
2. Open the running app via `playwright` MCP: `mcp__playwright__browser_navigate` to `FRONTEND_URL`.
3. If `docs/qa/test-accounts.md` is missing, STOP and run `seed-test-accounts` first (or post a `question` comment to project-lead if account credentials are not yet seeded into env). Otherwise, log in as a test user from that table.
4. Open `docs/qa/cases/<story-id>.md` in another buffer so I can annotate the `Exploratory Log`.
5. At the START of every chaos-explore session, open a fresh Playwright context with options `{ recordHar: { path: 'docs/qa/exploratory/<story-id>/<ISO-date>/network.har', mode: 'minimal' } }` and only THEN navigate. Per-probe network capture stays as `browser_network_requests`.
6. Open the DevTools console capture: `mcp__playwright__browser_console_messages` will be polled after each probe.

## The probe checklist (work through these in order)

For each probe: execute, observe, log. Capture a screenshot via `browser_take_screenshot` if anything is suspicious.

1. **Refresh mid-action.** Start the flow, get to step 2 of N, hit `browser_navigate` to same URL or use `page.reload()`. Expected: state recoverable or graceful restart message. Suspicious: white screen, stale data, JS error.

2. **Slow network.** Use `browser_run_code` to add latency: `await page.route('**', async route => { await new Promise(r => setTimeout(r, 1500)); route.continue(); });`. Re-run happy path. Expected: loading indicators, no double-submits, no race-induced state corruption. Suspicious: button enabled before response, duplicate API calls, optimistic UI that doesn't roll back on error.

3. **Double-submit.** Click the primary submit twice within 100ms via `browser_run_code`: `await Promise.all([btn.click(), btn.click()])`. Then check network for duplicate requests. Expected: one request OR idempotent server response. Suspicious: two charges, two records, two emails.

4. **Triple-submit.** Same as above with three clicks. Same expectation.

5. **Concurrent clicks on different actions.** Click "save" and "cancel" simultaneously. Expected: deterministic outcome (one wins, the other is no-op). Suspicious: half-saved state.

6. **Unicode bomb.** Fill every text field with `🐛🚀אבגالعربية中文𝕬𝖇𝖈🇺🇳‍👨‍👩‍👧‍👦`. Submit. Expected: accepted or rejected with clear message. Suspicious: silent truncation, server 500, render breakage.

7. **Very long input.** Fill text fields with 10,000 characters. Expected: validation error if limit exists. Suspicious: server 500, frontend hang.

8. **Empty submit.** Submit forms with all fields blank. Expected: per-field validation errors. Suspicious: server 500, silent success.

9. **Whitespace-only submit.** Fill required text fields with `   ` (spaces only). Expected: rejected as empty. Suspicious: accepted as valid.

10. **Browser back during async.** Click an action that fires a request taking ≥1s. While in-flight, click browser back. Expected: cancelled gracefully OR completes silently with consistent state. Suspicious: orphaned record, error toast on the previous page, console error.

11. **Browser forward.** After back, go forward. Expected: previous page state restored (BFCache) or reloaded cleanly. Suspicious: stale data shown.

12. **Deep-link reload mid-flow.** Mid-flow, copy the URL, paste into a fresh tab. Expected: resumable state if step is shareable, or redirect-to-login/start if auth-required. Suspicious: blank page, infinite loader, "undefined" rendered.

13. **Malformed cookie.** Edit the auth cookie via `browser_run_code` (`document.cookie = "auth=garbage"`). Reload. Expected: redirect to login or 401. Suspicious: half-broken page, JS crash.

14. **Expired token.** Wait for token TTL (or fast-forward by editing cookie's exp). Make a privileged request. Expected: 401 + refresh OR 401 + redirect-to-login. Suspicious: stale UI shows authed but requests fail.

15. **Privilege escalation probe.** Log in as low-privilege user. Try to access an admin-only URL directly. Expected: 403 or redirect. Suspicious: page loads partial UI.

16. **Different role same time.** Open two windows: admin in one, regular user in other. Have admin delete a record the user is currently viewing. Have user click edit. Expected: graceful "no longer exists" message. Suspicious: 500, stack trace, app crash.

17. **CSV/upload edge.** If the Story has file upload: try .exe, 0-byte file, 100MB file, .pdf renamed to .png, file with `..` in name. Expected: rejected appropriately. Suspicious: 500, server-side path traversal, no progress for huge file.

18. **Date/timezone weirdness.** If the flow has dates: pick Feb 29 in non-leap year, pick year 9999, pick before 1970, change OS timezone mid-flow. Expected: validated. Suspicious: NaN dates, "Invalid Date" rendered, off-by-one days.

## Logging

For every probe, append a bullet to `Exploratory Log` in the case file:

```
- [<HH:MM>] probe: <name> — <observation>. <one of: ok | suspicious | bug-candidate>. <evidence link if captured>.
```

## When a probe yields a bug candidate

1. **Reset browser state** (close context, open fresh, log in again).
2. **Attempt repro a second time** with the same steps.
3. **If repro succeeds twice**:
   - Allocate next BUG-NN.
   - Capture full evidence right now into `docs/qa/bug-reports/evidence/BUG-NN/`:
     - `screenshot-step<N>.png` for each meaningful step.
     - `network.har` (export from current Playwright context).
     - `console.log` (dump from `browser_console_messages`).
     - `repro.webm` if Playwright video is enabled.
   - Exit chaos-explore (timer be damned) and enter REPORT state (skill `file-bug`).
4. **If repro fails** on the second attempt: log as `- suspicious-only — could not reproduce`. Do NOT file. Note it as a regression candidate for the next cycle.

## When the timer hits 30:00

1. Stop. Even if you "feel like one more probe."
2. Save the HAR and console log to `docs/qa/exploratory/<story-id>/<ISO-date>/` (HAR was already being written there by the recordHar context option; flush + close to ensure it's persisted, and dump console buffer to `console.log` in the same directory).
3. Commit case-file updates.
4. Transition: if no bugs filed → back to AUTOMATE (re-run full suite) and then to "Story qa-complete" handoff. If bugs filed → REPORT first, then back here for any leftover time on next Story.

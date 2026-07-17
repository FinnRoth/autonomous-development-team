---
name: design-cases
description: Expand acceptance criteria into a full case set — happy / edge / negative / cross-cutting.
trigger: Case-file skeleton exists; transitioning DESIGN_CASES per WORKFLOWS.md §3.
inputs:
  - docs/qa/cases/<story-id>.md (skeleton with acceptance criteria filled)
  - docs/ui/ui-spec.md and the relevant flow
  - docs/architecture/api/<service>/openapi.yaml (for input/contract constraints; per API code repo)
outputs:
  - docs/qa/cases/<story-id>.md fully populated with case rows
---

# design-cases

Deterministic case design from acceptance criteria.

## Steps

1. **Read** the case-file skeleton. Note the acceptance criteria.

2. **For each acceptance criterion** (`AC-N`), write exactly one Happy Path case:
   - id: `<STORY-ID>-HP-NN` (NN matches the criterion number).
   - scenario: "User does X, sees Y" (one sentence).
   - steps: numbered, concrete. Each step is a Playwright-actionable verb (`navigate`, `click`, `fill`, `wait for`, `expect`).
   - expected: a single observable outcome, matching the criterion verbatim where possible.
   - automated: `pending`.
   - linked_test: blank for now.

3. **Edge cases** — apply each applicable probe from the list. Skip with explicit `N/A — <reason>` if a probe truly doesn't apply.

   | Probe | Apply when |
   |---|---|
   | boundary values | numeric or length-bounded input |
   | empty input | every text field |
   | max-length input | every text field that has a max |
   | min-length input | every text field that has a min |
   | unicode (CJK, emoji, RTL, ZWJ, combining marks) | every text field |
   | slow network (3G profile) | any flow with ≥1 network call |
   | simultaneous actions (double-submit, race) | any submit/save action |
   | refresh mid-action | any multi-step form or async-in-progress |
   | browser back during async | any flow with pending fetches |
   | browser forward / restore from BFCache | any flow with router state |
   | deep-link reload | any URL with state (params, hash) |
   | session expiry mid-flow | any authenticated flow |

   Format each as id `<STORY-ID>-EDGE-NN`.

4. **Negative cases** — apply each applicable probe:

   | Probe | Apply when |
   |---|---|
   | forbidden input per `api/<service>/openapi.yaml` (regex/format violations) | every API-backed field |
   | wrong content-type | every POST/PUT |
   | malformed JSON body | every JSON endpoint |
   | missing auth header | every authenticated endpoint |
   | expired token | every authenticated endpoint |
   | wrong role / insufficient permission | every role-gated action |
   | duplicate submission | any action with an idempotency expectation |
   | injection probes (SQL-shaped, NoSQL-shaped, script tags in text) | every user-supplied field |
   | path traversal | any file-handling input |

   Format each as id `<STORY-ID>-NEG-NN`.

5. **Cross-cutting cases**, mandatory:
   - **a11y keyboard nav**: complete the happy path using only keyboard (Tab, Shift+Tab, Enter, Space, Esc, arrow keys). No mouse.
   - **mobile viewport**: complete happy path on iPhone 13 (390×844) and Pixel 5 (393×851) viewports.
   - **browser back/forward**: traverse the flow then use back, then forward — final state must match expected.
   - **deep-link reload**: at each step of the flow, copy URL, reload in fresh tab, expect resumable state OR redirect-to-login if auth-gated.

   IDs: `<STORY-ID>-CC-A11Y`, `<STORY-ID>-CC-MOBILE`, `<STORY-ID>-CC-NAV`, `<STORY-ID>-CC-DEEPLINK`.

6. **Tag automation feasibility** per case:
   - `pending` — not yet tried.
   - `yes` — will automate in AUTOMATE state.
   - `partial` — automatable but with manual oracle (rare).
   - `manual` — only manual verification possible (rare; needs justification).

7. **If a case is blocked** by spec ambiguity → mark it `blocked:question-<recipient>-<ISO-date>` and post the `question` comment per `PROTOCOLS.md §2.1`. Other cases continue.

8. **Sanity check** before exiting:
   - Every acceptance criterion has ≥1 happy-path case. (If not, fail loudly — you missed one.)
   - Total cases ≥ (criteria_count + 3). Below that, you under-designed.
   - No case has empty steps or empty expected.

9. **Update `Automation Status` block** at the bottom of the case file:
   ```
   - total_cases: <N>
   - automated: 0
   - blocked: <N_blocked>
   - last_run: never
   ```

10. **Commit** on the existing intake branch: `git commit -am "[<STORY-ID>] qa: case design"`. Push.

11. **Transition to AUTOMATE** (WORKFLOWS.md §4).

## Failure modes
- A criterion truly defies testing → `question` to project-lead (see PROTOCOLS.md §2.1 example for "untestable acceptance"). Mark the case blocked; do not invent an oracle.

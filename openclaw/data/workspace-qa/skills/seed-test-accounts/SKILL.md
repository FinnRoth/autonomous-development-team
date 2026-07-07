---
name: seed-test-accounts
description: Produce the first-cut docs/qa/test-accounts.md — a table of role → slug → env-var-name. NEVER writes passwords; only env-var REFERENCES per CONVENTIONS.md §6.5.
trigger: Run once on first onboarding, triggered by a handoff whose artifact_paths include docs/architecture/protocols.md AND that file mentions auth (roles, scopes, login flow). Skip (no-op) if docs/qa/test-accounts.md already exists.
inputs:
  - docs/architecture/protocols.md (auth scopes, roles, login flow)
outputs:
  - docs/qa/test-accounts.md (new file with role → slug → env-var-name table)
  - question to project-lead requesting env-var population on the running app
  - PR via gh on docs repo branch qa/seed-test-accounts
---

# seed-test-accounts

Deterministic first-time creation of the QA test-account registry. Run ONCE per project. Idempotent: if `docs/qa/test-accounts.md` already exists, exit early.

## Steps

1. **Pre-check.** If `docs/qa/test-accounts.md` already exists, log `seed-test-accounts: skipped, file already present` to `memory/YYYY-MM-DD.md` and EXIT.

2. **Read `docs/architecture/protocols.md`.** Enumerate every distinct auth scope/role mentioned (e.g. `admin`, `user`, `viewer`, `billing-admin`, `auditor`). If the file is missing or has no auth section, file a `question` to architect asking for the auth model and STOP (do not write the table yet).

3. **For each role, define a test-user slug** of the form `qa+<role>@example.com`. Slugs use `+` subaddressing so a single inbox can receive all roles' mail if the auth flow does email verification. Lowercase the role. Example: `admin` → `qa+admin@example.com`.

4. **For each role, define an env-var name** for the password reference of the form `QA_USER_<ROLE_UPPER>_PW` (e.g. `QA_USER_ADMIN_PW`, `QA_USER_BILLING_ADMIN_PW`). Never write the password itself — only the env-var NAME. This is enforced by CONVENTIONS.md §6.5.

5. **Write `docs/qa/test-accounts.md`** with this structure:

```markdown
# QA Test Accounts

Source of truth for which test users this role uses against the running app. Passwords are NEVER committed — only env-var references. Project bootstrap is responsible for seeding the actual users + populating the env vars.

| Role | Slug | Password env var |
|------|------|------------------|
| admin | qa+admin@example.com | QA_USER_ADMIN_PW |
| user  | qa+user@example.com  | QA_USER_USER_PW  |
| ...   | ...                  | ...              |

## How tests consume these

```ts
const adminPw = process.env.QA_USER_ADMIN_PW;
if (!adminPw) throw new Error('QA_USER_ADMIN_PW not set');
```

## Onboarding gap

If `docs/qa/test-accounts.md` exists but the env vars are not yet populated on the running app, chaos-explore and Playwright suites will fail at login. That is expected until project-lead confirms the users + env vars are seeded.
```

6. **File `question` to project-lead** requesting the env vars be populated on the running app. Include the full list of env-var names and the slug → role mapping. `why_blocking`: "chaos-explore and Playwright suites cannot log in until these are set on the dev environment." `options_considered`: ["project-lead seeds via project bootstrap", "PL delegates to backend to seed", "skip auth tests until next sprint"].

7. **Commit & PR on docs repo.**
   - `cd docs && git checkout -b qa/seed-test-accounts`
   - `git add docs/qa/test-accounts.md`
   - `git commit -m "[QA] seed test-accounts registry"`
   - `git push origin qa/seed-test-accounts`
   - Open PR via `gh`: title `[QA] seed test-accounts registry`, body explains the env-var-only convention and links the `question` to project-lead. Request reviewer (Mira). Do NOT self-merge.

8. **Log** in `memory/YYYY-MM-DD.md`: `seed-test-accounts: PR opened on docs repo, question filed to project-lead for env-var seeding`.

## Failure modes
- `docs/architecture/protocols.md` does not mention auth → exit, file `question` to architect asking whether auth is in scope at all.
- A password leaks into the file during authoring → STOP, do NOT push the branch; rotate the credential (via project-lead) and restart from a clean working copy.
- Two roles map to the same env-var name (collision in the slugifier) → disambiguate by appending the discriminator from protocols.md (e.g. `QA_USER_ADMIN_PRIMARY_PW`).

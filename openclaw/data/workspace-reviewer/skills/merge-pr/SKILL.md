---
name: merge-pr
description: Squash-merge an approved PR per ADR convention and hand off the merged SHA to QA.
trigger: WORKFLOWS.md State 5 (VERDICT) when the verdict is APPROVE.
inputs: pr_number, ticket_id, head_sha (at approval), summary_url (from post-review)
outputs: merge commit on default branch; appended row in docs/reviews/review-log.md; handoff comment to qa via board_add_comment.
---

## Procedure

This skill is the single chokepoint between approval and trunk. Every step is mandatory. If any pre-flight fails, abort and re-enter the FSM at State 4 (COMMENT) to file the failure as Required.

### Step 1 — Pre-flight: I just approved this

1. `gh pr view <pr_number> --json reviews --jq '.reviews[-1]'`.
2. Verify: `state == "APPROVED"` AND `author.login` matches my configured reviewer identity (env `REVIEWER_GH_LOGIN`).
3. If not, ABORT and post an `escalation` comment (severity `high`) to project-lead: "merge-pr called without my approval on PR <num>".

### Step 2 — Pre-flight: CI is green on the head SHA

1. `gh pr checks <pr_number> --json name,conclusion,status`.
2. Verify every check has `conclusion == "success"` (treat `neutral` / `skipped` as pass; `pending` and `failure` as fail).
3. If any non-success → ABORT, post a new Required inline comment "CI regressed since approval", flip verdict to REQUEST_CHANGES via Step 5 in the FSM.

### Step 3 — Pre-flight: head SHA unchanged since approval

1. `gh pr view <pr_number> --json headRefOid --jq .headRefOid`.
2. Compare against `head_sha` from inputs.
3. If different → ABORT, write to scratch memory "head moved from <head_sha> to <new>; re-running CHECKLIST", and re-enter State 3.

### Step 4 — Read the merge-strategy ADR

1. Read `docs/architecture/adr-merge-strategy.md` (or the equivalent ADR — listed in `docs/architecture/INDEX.md`).
2. Default: `--squash --delete-branch`.
3. If ADR specifies a different strategy (e.g. `--rebase`), honor it.
4. Confirm commit message template from ADR. Default: `[<TICKET-ID>] <PR title sans "[TICKET-ID]" prefix>`.

### Step 5 — Execute merge

1. `gh pr merge <pr_number> --squash --delete-branch --subject "[<TICKET-ID>] <title>" --body "Closes #<ticket-num>. Reviewed-by: Mira 🔍 (reviewer). Summary: <summary_url>."`.
2. Capture the merge commit SHA from the response.
3. If merge fails with conflicts → ABORT, flip verdict to REQUEST_CHANGES with Required: "Resolve conflicts against default branch and re-push" and exit.
4. If merge fails with branch-protection error → post an `escalation` comment (severity `high`) to project-lead: "branch protection rejected the merge of PR <num>; configuration mismatch with role permissions".

### Step 6 — Append to review-log.md

1. Append exactly one row to `docs/reviews/review-log.md` (table is pipe-delimited):
   ```
   | <ISO-8601> | #<pr_number> | <TICKET-ID> | APPROVE+MERGED | <merge-sha-short> | 0 required |
   ```
2. Do not edit any prior rows. Append-only.
3. `git -C docs add docs/reviews/review-log.md`
4. `git -C docs commit -m "[reviewer] log PR #<pr_number> merged at <merge-sha-short>"`
5. `git -C docs push origin <default-branch>`.

### Step 7 — Post handoff comment to QA

1. Post a `handoff` comment to `qa` via `board_add_comment` (schema per PROTOCOLS.md §1):

```
board_add_comment(
  ticket_id="<TICKET-ID>",
  author="reviewer",
  to="qa",
  type="handoff",
  body="<TICKET-ID> merged at <merge-sha-short> (<commit-url-or-sha>). Acceptance fully covered; "
       "review summary at <summary_url> and docs/reviews/review-log.md. QA: regress + E2E. "
       "Expected: qa adds <TICKET-ID> to the regression suite within 1 cycle and moves the ticket "
       "from qa → done after E2E pass."
)
```

2. The comment is delivered the instant board-api stores it; qa sees it on its next `board_get_unread(agent="qa")`. If `board_add_comment` returns an error, retry once, then log to `memory/<YYYY-MM-DD>.md` (CONVENTIONS.md §12).

### Step 8 — Schedule post-merge audit

1. Append a marker row to `memory/<YYYY-MM-DD>.md`:
   ```
   AUDIT-PENDING pr=<pr_number> ticket=<TICKET-ID> approval-sha=<head_sha> merge-sha=<merge-sha> due=<ISO+24h>
   ```
2. State 1 (IDLE) will read this on a future wake and trigger `audit-post-merge`.

### Step 9 — Exit

Return control to WORKFLOWS.md State 5 with `merged: true, merge_sha: <sha>`.

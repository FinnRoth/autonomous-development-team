---
name: audit-post-merge
description: Audit a merged PR for fixup commits inserted between approval and merge; flag any divergence.
trigger: WORKFLOWS.md State 6 (POST_MERGE_AUDIT) — invoked by IDLE when a prior approval is ≥24h old (or on-demand by project-lead).
inputs: pr_number, ticket_id, approval_sha (head SHA at the moment of my APPROVE), merge_sha (the squash-merge commit SHA on default branch)
outputs: a marker appended to docs/reviews/review-log.md (`| audited-clean` | `| audited-flagged: <comment-id>` | `| audited-unavailable`); possibly an escalation comment.
---

## Procedure

### Step 1 — Locate the merge commit

1. `git -C project fetch origin <default-branch>`.
2. `git -C project show --no-patch --format='%H %P %s' <merge_sha>`.
3. Verify the commit exists on the default branch. If not → record `audited-unavailable` and post an `escalation` comment (severity `low`) to project-lead.

### Step 2 — Identify the branch tip at approval vs at merge

1. The squash-merge produces a single commit; the original branch is deleted. Two ways to recover the in-between commits:
   - **Preferred:** `gh pr view <pr_number> --json commits --jq '.commits[].oid'` — returns all commits that were on the branch at merge time.
   - **Fallback:** git host's branch-restore API (`gh api repos/{owner}/{repo}/git/refs --method POST` to recreate from reflog) — only if the commit list is incomplete.
2. The full ordered list of branch-tip SHAs is `branch_commits`.

### Step 3 — Compare against the approval SHA

1. Locate `approval_sha` in `branch_commits`.
2. `extra_commits = branch_commits[branch_commits.index(approval_sha)+1:]` — i.e. commits added AFTER my approval.
3. If `extra_commits` is empty → record `audited-clean`, exit.

### Step 4 — Classify each extra commit

For each commit in `extra_commits`:

1. `git -C project show --stat <commit-sha>`.
2. If diff is **only**:
   - whitespace / formatting / lint-fix (no logic change);
   - comment-only changes;
   - dependency-lockfile noise (`package-lock.json`, `pnpm-lock.yaml`, `poetry.lock`) with no `package.json`/`pyproject.toml` change;
   → classify `trivial`.
3. Else → classify `substantive`.

### Step 5 — Decide outcome

1. If all `extra_commits` are `trivial`:
   - Append to the PR's row in `review-log.md`: ` | audited-clean (N trivial fixups)`.
   - Exit.
2. If any `extra_commits` is `substantive`:
   - Post an `escalation` comment to `project-lead` (see template below).
   - Capture the returned comment id.
   - Append to the PR's row: ` | audited-flagged: <comment-id>`.

### Step 6 — Escalation template (Step 5 substantive case)

```
board_add_comment(
  ticket_id="<TICKET-ID>",
  author="reviewer",
  to="project-lead",
  type="escalation",
  body="severity: high. Post-merge audit of PR #<num> found <N> substantive commits between my "
       "approval (<approval-sha-short>) and the squash-merge (<merge-sha-short>) that I did not "
       "review. Substantive commit SHAs + one-line summaries: <list here>. "
       "Requested decision: decide remediation (revert / patch-and-re-review / accept). Options: "
       "(a) revert merge <merge-sha> and reopen PR for re-review; "
       "(b) leave merged; open a follow-up ticket to re-validate the un-reviewed diff; "
       "(c) accept and document the exception in docs/reviews/rules.md. "
       "Recommendation: (a) — preserves the invariant that nothing un-reviewed reaches the default branch."
)
```

Capture the returned `comment_id` — that is the `<comment-id>` used in the `audited-flagged` marker.

### Step 7 — Commit + push the log

1. `git -C docs add docs/reviews/review-log.md`.
2. `git -C docs commit -m "[reviewer] audit PR #<num>: <audited-clean|audited-flagged:<comment-id>>"`.
3. `git -C docs push origin <default-branch>`.

### Step 8 — Clear the pending marker

1. Remove the `AUDIT-PENDING pr=<num> …` line from `memory/<YYYY-MM-DD>.md` (or strikethrough it; `memory/` may be append-only by convention — prefer strikethrough).
2. Exit to IDLE.

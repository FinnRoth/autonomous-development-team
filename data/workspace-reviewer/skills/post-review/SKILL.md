---
name: post-review
description: Format the review summary and inline comments and post them to the PR via the git host CLI.
trigger: WORKFLOWS.md State 4 (COMMENT) — invoked once per PR after the checklist tuples are ready.
inputs: pr_number, verdict-input JSON (from review-checklist), repository host (github | gitea | forgejo | gitlab)
outputs: posted inline comments, posted summary comment, summary comment URL stored in scratch memory.
---

## Procedure

### Step 1 — Bucket the failures

1. Load the `verdict-input.checks` array.
2. For every `status: fail`:
   - If `citation` references `rules.md §R-...` or an ADR id or a spec anchor → bucket **Required**.
   - Else if it represents a security or performance smell (checks 11 & 12) → bucket **Required** regardless (those have built-in citations).
   - Else if it is naming / dead-code / style → bucket **Suggested**.
   - Else → bucket **Suggested**.
3. Items not in any bucket but worth a one-liner cosmetic note → bucket **Nit** manually.

### Step 2 — Build inline comments

For each Required/Suggested/Nit item:

1. Compute `file` and `line` from the offending diff hunk (when applicable).
2. Build the comment body using the frozen template:

```
**[<TAG>]** <one-line problem statement>
- Source: <citation>
- Expected: <one-line>
- Found: <one-line>
```

Where `<TAG>` is one of `Required`, `Suggested`, `Nit`.

3. Post via host CLI:
   - GitHub: `gh api repos/{owner}/{repo}/pulls/{pr}/comments -F body=... -F path=... -F line=... -F side=RIGHT -F commit_id=<head_sha>`.
   - Gitea/Forgejo: `tea pulls review create --comment` (or REST equivalent).
   - GitLab: `glab mr note --message ... --path ... --line ...`.

### Step 3 — Build the summary comment (frozen template)

```
## Review Verdict — <REQUEST_CHANGES | APPROVE>
Ticket: <TICKET-ID> — <title>
PR: #<num> @ <head-sha-short>

### Acceptance coverage
- [x] criterion 1 → <evidence>
- [ ] criterion 2 → MISSING
…

### Required (block merge)
1. <item> — source: <citation>
…
(If none: "_None._")

### Suggested
1. <item>
…
(If none: "_None._")

### Nits
1. <item>
…
(If none: "_None._")

### Notes
- Tests: <one-line>
- Contracts: <one-line>
- Scope: <one-line>

— Mira 🔍 (reviewer)
```

Do not deviate from this template. Section headers and order are fixed.

### Step 4 — Post the summary

1. `gh pr comment <pr_number> --body-file <path-to-summary.md>` (or host equivalent).
2. Capture the returned URL.
3. Write the URL into `memory/<YYYY-MM-DD>.md` under the PR header as `summary_url: <url>`.

### Step 5 — Sanity check before exit

1. Verify `gh pr view <pr_number> --json comments --jq '.comments[-1].body'` ends with `— Mira 🔍 (reviewer)`.
2. If not, retry once. If still not, escalate `med` to project-lead: "summary failed to post on PR <num>".

### Step 6 — Do NOT post the verdict yet

This skill stops here. Verdict posting is the job of WORKFLOWS.md State 5 (which calls either `merge-pr` for approve, or just emits `--request-changes` directly).

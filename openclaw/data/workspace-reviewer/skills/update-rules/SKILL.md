---
name: update-rules
description: Amend docs/reviews/rules.md after project-lead has approved a rule change via escalation.
trigger: WORKFLOWS.md side-state RULES_AMENDMENT — invoked when an `escalation` comment reply from project-lead (surfaced by board_get_unread) approves a rules.md change.
inputs: approving_comment_id (the project-lead comment that approves my prior proposal), proposed_rule_text, rule_action ("add" | "edit" | "retire"), target_rule_id (for edit/retire) or null (for add)
outputs: updated docs/reviews/rules.md committed and pushed; confirmation comment posted to project-lead via board_add_comment.
---

## Procedure

### Step 1 — Verify the authorization

1. Open the `escalation` comment (fetched via `board_get_unread(agent="reviewer")`) that triggered this skill; note its `comment_id` as `<approving_comment_id>`.
2. Verify `author: "project-lead"`, `type: "escalation"`, and that its body directly references my prior rule proposal (the `requested_decision: "amend rules.md ..."` text).
3. Verify the approving comment's requested change matches the rule change I am about to make.
4. If anything mismatches → ABORT and post a `question` comment back to project-lead: "Please confirm rule change for comment <approving_comment_id> — wording mismatch."
5. After handling, `board_ack_comment(comment_id=<approving_comment_id>, agent="reviewer")`.

### Step 2 — Open rules.md

1. `git -C docs pull --ff-only`.
2. Read `docs/reviews/rules.md`.
3. The file has a fixed structure (see Appendix below). If structure has drifted, repair it as a separate commit before continuing.

### Step 3 — Apply the change

#### If `rule_action == "add"`:

1. Find the next available rule id: scan `^### R-(\d{3})` headings, take max + 1.
2. Format the new rule id as `R-NNN` (zero-padded).
3. Insert a new section at the end of the appropriate category:

```
### R-NNN — <one-line title>

**Severity:** Required | Suggested
**Source:** introduced via project-lead approval comment <approving_comment_id> on <ISO date>.
**Rule:** <full rule text>
**Rationale:** <one paragraph>
**Examples:**
- Bad: <code or scenario>
- Good: <code or scenario>
**Citation form:** `rules.md §R-NNN`
```

#### If `rule_action == "edit"`:

1. Locate `### R-<target_rule_id>`.
2. Edit the `**Rule:**` and/or `**Rationale:**` block.
3. Append a `**Revised:**` line: `**Revised:** <ISO date> via project-lead approval comment <approving_comment_id>`.
4. Do NOT change the rule id. Do NOT delete any history.

#### If `rule_action == "retire"`:

1. Locate `### R-<target_rule_id>`.
2. Prepend `~~RETIRED~~ ` to the heading.
3. Append a `**Retired:**` line: `**Retired:** <ISO date> via project-lead approval comment <approving_comment_id>. Reason: <one line>.`.
4. Never delete the section; retired rules remain visible for citation history.

### Step 4 — Update the index

1. The top of `rules.md` has a table-of-contents listing live rule ids. Update it:
   - On add: append `R-NNN — <title>`.
   - On retire: strike through (`~~R-NNN — <title>~~`).
   - On edit: no change to TOC.

### Step 5 — Commit + push

1. `git -C docs add docs/reviews/rules.md`.
2. `git -C docs commit -m "[reviewer] rules.md: <add|edit|retire> R-NNN (approval comment <approving_comment_id>)"`.
3. `git -C docs push origin <default-branch>`.

### Step 6 — Post confirmation comment to project-lead

Post an `escalation` comment (informational) to project-lead via `board_add_comment`, replying on the same ticket the approval comment was on (`SYSTEM-00` if the amendment had no project ticket):

```
board_add_comment(
  ticket_id="<same-ticket-as-approval-comment>",
  author="reviewer",
  to="project-lead",
  type="escalation",
  body="severity: low. Informational. Confirmed: rules.md updated per your approval comment "
       "<approving_comment_id>. Rule R-NNN <added|edited|retired>. requested_decision: none. "
       "Recommendation: broadcast the change to backend and frontend (via project-lead) so they "
       "know about it before their next PR."
)
```

### Step 7 — Exit

Return to State 1 (IDLE).

---

## Appendix — rules.md structure (target)

```
# Reviewer Rules — Mira's Checklist

> This file is the authoritative source of "Required" citations. Every Required comment I post on a PR cites a section here OR a spec/ADR. Project-lead approves changes via escalation; reviewer applies them via skill `update-rules`.

## Table of contents
- R-001 — Ticket linked in PR body
- R-002 — Acceptance traceability
- R-003 — Scope adherence (expected paths)
- R-004 — OpenAPI authoring discipline
- R-005 — No hard-coded secrets
- R-006 — No silent auth removal
- R-007 — No string-built SQL
- R-008 — No `eval` / `exec` with user input
- R-009 — No wildcard CORS on credentialed routes
- R-010 — No N+1 in request paths
- R-011 — No unbounded loops
- R-012 — No sync I/O in async paths
- R-013 — Pagination on list endpoints
- R-014 — Identifier style consistent with surroundings
- R-015 — Non-happy-path test coverage required

## Rules
### R-001 — Ticket linked in PR body
...
```

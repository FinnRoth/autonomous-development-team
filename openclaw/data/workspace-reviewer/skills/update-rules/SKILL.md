---
name: update-rules
description: Amend docs/reviews/rules.md after project-lead has approved a rule change via escalation.
trigger: WORKFLOWS.md side-state RULES_AMENDMENT — invoked when an inbox escalation reply from project-lead approves a rules.md change.
inputs: escalation_id (the prior escalation I sent that is now approved), proposed_rule_text, rule_action ("add" | "edit" | "retire"), target_rule_id (for edit/retire) or null (for add)
outputs: updated docs/reviews/rules.md committed and pushed; reply message to project-lead confirming the change.
---

## Procedure

### Step 1 — Verify the authorization

1. Open the inbox message that triggered this skill.
2. Verify `from: "project-lead"`, `type: "escalation"`, and that it directly references `<escalation_id>` (in `summary` or `requested_decision`).
3. Verify the reply's `requested_decision` text matches the rule change I am about to make.
4. If anything mismatches → ABORT and `question` back to project-lead: "Please confirm rule change for escalation <id> — wording mismatch."

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
**Source:** introduced by escalation <escalation_id> on <ISO date>; approved by project-lead.
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
3. Append a `**Revised:**` line: `**Revised:** <ISO date> via escalation <escalation_id>`.
4. Do NOT change the rule id. Do NOT delete any history.

#### If `rule_action == "retire"`:

1. Locate `### R-<target_rule_id>`.
2. Prepend `~~RETIRED~~ ` to the heading.
3. Append a `**Retired:**` line: `**Retired:** <ISO date> via escalation <escalation_id>. Reason: <one line>.`.
4. Never delete the section; retired rules remain visible for citation history.

### Step 4 — Update the index

1. The top of `rules.md` has a table-of-contents listing live rule ids. Update it:
   - On add: append `R-NNN — <title>`.
   - On retire: strike through (`~~R-NNN — <title>~~`).
   - On edit: no change to TOC.

### Step 5 — Commit + push

1. `git -C docs add docs/reviews/rules.md`.
2. `git -C docs commit -m "[reviewer] rules.md: <add|edit|retire> R-NNN (escalation <escalation_id>)"`.
3. `git -C docs push origin <default-branch>`.

### Step 6 — Reply to project-lead

Compose `outbox/<ISO>-project-lead-escalation.json` as a confirmation:

```json
{
  "type": "escalation",
  "from": "reviewer",
  "to": "project-lead",
  "severity": "low",
  "summary": "Confirmed: rules.md updated per escalation <escalation_id>. Rule R-NNN <added|edited|retired>.",
  "requested_decision": "none — informational",
  "options": [],
  "recommendation": "broadcast change to backend, frontend (via project-lead) so they know about it before next PR."
}
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

---
name: interrogate-user
description: Structured requirements interview for a feature, change, or topic; produces a Q&A document with no vague answers.
trigger: User expresses a new feature request, change request, or open-ended "can we …" question, after onboarding is complete.
inputs: A topic identifier (slug, lowercase, hyphenated). User chat.
outputs: docs/requirements/Q&A-<topic>.md committed to docs repo.
---

# interrogate-user — deterministic procedure

The goal is a Q&A document where every answer is **specific, measurable, or explicitly declined**. No "fast", no "good", no "users will love it" without a metric.

## Step 1 — Confirm topic and scope

Send to user:

> "I want to make sure I capture this cleanly. Topic working title: '<topic>'. I'll ask 10-12 questions; please answer one at a time. If a question doesn't apply, say 'N/A' — I'll record it."

Create `docs/requirements/Q&A-<topic>.md` with frontmatter:

```yaml
---
topic: <topic>
status: in_progress
started: <ISO>
asker: project-lead
---
# Q&A — <topic>

```

## Step 2 — Run the checklist

Ask EXACTLY these twelve questions, in this order, one per turn. After each answer, write the entry to the Q&A file and re-read the prior entries for contradictions before asking the next question.

For each: if the answer is vague, ask up to **two** follow-ups; if still vague, record `Answer: <verbatim>; Vagueness flagged.` and continue.

### Question template

```
### Q<N>: <question>
**Asked:** <ISO>
**Answer:** <verbatim user words>
**My read:** <one-line paraphrase>
**Status:** clear | vague | declined
```

### The twelve questions

1. **Purpose.** "In one sentence — why does this need to exist?"
2. **Target users.** "Who specifically benefits? Name a persona or job title. Reject 'everyone'."
3. **Success criteria.** "How will we know it worked? Give a measurable signal (e.g., 'invoices ship in <2s', '90% of users complete checkout in one session')." If they cannot give a metric, ask for a qualitative one and tag `Vagueness flagged`.
4. **Non-goals.** "What is this explicitly NOT trying to do? Name at least two."
5. **Constraints.** "Any hard constraints — regulatory, performance, integration, branding?"
6. **Deadline.** "Is there a date this must ship by? If yes, why that date?"
7. **Budget.** "Any cost ceiling on services or infra for this feature?"
8. **Existing-system context.** "What part of the current product does this touch, change, or replace?"
9. **Integrations.** "Does this depend on or talk to external systems? Name each (auth provider, payment gateway, third-party API)."
10. **Known risks.** "What could go wrong? Anything that scares you about this?"
11. **Deal-breakers.** "What would make us abandon or roll this back?"
12. **Priorities relative to existing work.** "Does this push out any in-flight Epic, or is it additive?"

## Step 3 — Contradiction sweep

After Q12, scan the file:

1. Re-read every "Answer" line.
2. List any pair of answers that contradict (e.g., Q3 says "<2s" but Q9 names a slow 3rd-party API). For each contradiction, add a line under the offending Q:
   ```
   **Contradiction:** Q<N> vs Q<M> — <one-line description>
   ```
3. Bring the contradictions to the user as a numbered list: "Before I write tickets, I see these tensions. Please resolve each." Accept the user's resolution; update both Q entries and re-tag.

## Step 4 — Quality-floor check

Before marking complete, confirm:

- All 12 questions answered (including "N/A" or "declined").
- No more than 3 questions tagged `Vagueness flagged`. If more, surface to user: "I have <N> vague answers; this will produce mushy tickets. Can we sharpen at least <N-3> of them?"
- At least one answer in Q3 is measurable.
- At least two non-goals named in Q4.

If any floor fails, loop back to the offending question.

## Step 5 — Mark complete and commit

Update frontmatter:

```yaml
status: complete
completed: <ISO>
```

Add a footer:

```
## Summary for ticketing

- Purpose: <Q1 paraphrase>
- Users: <Q2>
- Success: <Q3>
- Non-goals: <Q4 bullets>
- Constraints: <Q5>
- Deadline: <Q6>
- Risks captured to risk-register.md: <list R-IDs created>
```

Commit:

```
git add docs/requirements/Q&A-<topic>.md
git commit -m "Q&A-<topic>: complete (interrogation by project-lead)"
git push
```

Append any new risks to `docs/project/risk-register.md` in the same commit.

## Step 6 — Hand off to DRAFT state

Skill returns control to the workflow. Next state per `WORKFLOWS.md`: DRAFT (run `draft-epic`).

## On-error

- User goes silent mid-interrogation → save with `status: paused`, send one polite ping after 1 cycle, then drop to IDLE.
- User says "you decide" on a content question (purpose, users, success) → push back: "I can decide structure, but not what the product is. Take a guess and I'll work with that." If they still refuse, escalate.
- User answers a different question than asked → record their answer under the question they answered (creating it if needed), and re-ask the original.

---
name: onboard-project
description: One-time project intake; gathers vision, users, jobs, deadline, repo URLs, stack preference; scaffolds docs/ and dispatches first handoff to architect.
trigger: User initiates the very first project on a fresh template (docs/ does not exist) OR explicitly asks to "start a new project".
inputs: User chat. Workspace with no docs/ directory.
outputs: docs/ skeleton (vision.md, glossary.md, risk-register.md, decision-log.md, board.md, handoff-log.md), docs/tickets/EPIC-01.md, docs/requirements/Q&A-onboarding.md, outbound handoff to architect, two remote git repositories (<project> and <project>-docs).
---

# onboard-project — deterministic procedure

This skill runs **once per workspace lifetime**. After it succeeds, the template is no longer a template; it is a project. Never run it twice without explicit user instruction.

## Preconditions check

1. Confirm `~/.openclaw/workspace-project-lead/docs/` does not exist. If it does, ABORT with: "Project already onboarded. Use `interrogate-user` + `draft-epic` for new features."
2. Confirm I am `project-lead` per `IDENTITY.md`. If not, ABORT.
3. Confirm `CONVENTIONS.md` is readable (symlink target resolves).

## Step 1 — Greet and frame

Send to user (channel: direct):

> "Hi — I'm Atlas, your Project Lead. Before the team starts, I need ten minutes of your time to lock the basics. I'll ask one question at a time. Plain answers are fine; I'll ask follow-ups where needed. Ready?"

Wait for user `yes`/`go`/equivalent affirmative. If they say no or "later", park in STANDBY.

## Step 2 — Interrogation checklist (asked in this order)

Ask one question per turn. After each answer, write it into `docs/requirements/Q&A-onboarding.md` (creating the file on the first answer). Format each entry as:

```
### Q<N>: <question>
**Asked:** <ISO timestamp>
**Answer:** <user's literal words>
**My read:** <one-line paraphrase to confirm understanding>
```

Required questions, in order:

1. **Project slug** (lowercase, hyphenated, no spaces; will become both repo names). Validate: regex `^[a-z][a-z0-9-]{2,40}$`. If invalid, ask again.
2. **One-sentence vision.** "Finish this sentence: 'This project exists so that <who> can <do what> better than today.'" If they give two sentences, ask them to pick one. If they refuse to be concise, accept the longer answer but flag it for me to compress in the vision doc.
3. **Target users.** "Who specifically — name a real persona or job title, not 'everyone'." Reject "everyone", "anyone", "users". Ask up to twice for specificity; on third attempt, accept and add a risk to the register.
4. **Top 3 jobs to be done** (numbered list). "What are the three concrete things a user will do with this in week 1?" Require exactly three. Fewer → ask for more. More → ask which three are P0.
5. **Deadline horizon.** "Is this 2 weeks, 2 months, or 2 quarters?" Accept any specific date instead. Record as ISO date; if vague, record as a range.
6. **Budget signal.** "Any hard cost ceiling on infra/SaaS/services per month, or budget for engineering hours?" Accept "none yet".
7. **Code repo URL.** Full clone URL of an empty (or to-be-created) remote for `<project>`. Validate: starts with `https://` or `git@`. If user says "you create it", ABORT with: "I cannot create remote repos. Please create an empty repo on your git host (GitHub/Gitea/Forgejo/GitLab) and paste the clone URL."
8. **Docs repo URL.** Full clone URL for `<project>-docs`. Same rules.
9. **Stack preferences.** "Any non-negotiable stack choices (language, framework, DB, host), or is it the architect's call?" Accept "architect's call" — that's the recommended path. Record any constraints.
10. **Non-goals.** "Name two or three things this project is explicitly NOT trying to do. This shortens the project by weeks." Require at least two. If user struggles, ask leading examples: "Not multi-tenant? Not mobile? Not real-time?"
11. **Deal-breakers / known risks.** "Anything that would kill the project if it went wrong?" Record verbatim in `risk-register.md`.
12. **User profile for me.** "What should I call you? Timezone? Preferred response style — brief, detailed, casual, formal?" Record into `USER.md`.

After Q12, re-read the entire Q&A back to the user as a numbered list. Ask: "Anything wrong, missing, or to change?" Accept corrections; commit the final Q&A.

## Step 3 — Scaffold docs/

Create the local docs directory by cloning the user-provided docs repo URL:

```
git clone <docs-repo-url> ~/.openclaw/workspace-project-lead/docs
cd ~/.openclaw/workspace-project-lead/docs
```

If clone fails (empty remote, auth issue), initialize locally and add the remote:

```
mkdir -p ~/.openclaw/workspace-project-lead/docs && cd $_
git init
git remote add origin <docs-repo-url>
git checkout -b main
```

Create directories:

```
docs/
├── project/
├── tickets/
├── requirements/
├── architecture/    (architect will own, but I create empty)
├── ui/              (uiux owns, empty)
├── reviews/         (reviewer owns, empty)
├── qa/              (qa owns, empty)
└── handoff-log.md
```

## Step 4 — Write project files

Create `docs/project/vision.md`:

```yaml
---
slug: <project-slug>
created: <ISO>
deadline: <ISO or range>
status: onboarding
---
# Vision

<one-sentence vision from Q2>

## Target users

<from Q3>

## Top jobs to be done

1. <from Q4 item 1>
2. <from Q4 item 2>
3. <from Q4 item 3>

## Non-goals

- <from Q10 item 1>
- <from Q10 item 2>
- <from Q10 item 3 if any>

## Constraints

- Deadline: <Q5>
- Budget: <Q6>
- Stack: <Q9 verbatim, or "architect's call (ADR-001)">
```

Validate: vision.md is ≤500 words. If over, compress before saving (preserve user phrasing for vision sentence verbatim).

Create `docs/project/glossary.md`:

```markdown
# Glossary

_Domain terms used in this project. Append-only with dated edits._

```

Create `docs/project/risk-register.md`:

```markdown
# Risk register

| ID | Risk | Severity | Owner | Status | Created | Review by |
|---|---|---|---|---|---|---|
| R-1 | <from Q11> | high | project-lead | open | <ISO> | <ISO+7d> |
```

Add a row for each Q11 risk. If user gave none, add R-1 as "No known deal-breakers stated; verify after week 1".

Create `docs/project/decision-log.md`:

```markdown
# Decision log

_Append-only. Each entry: ISO timestamp, decision id, decider, summary, link to ticket if any._

- <ISO> | D-001 | user | Project onboarded; slug=<slug>; stack=<Q9>; deadline=<Q5>. | Q&A-onboarding.md
```

Create `docs/board.md`:

```markdown
# Board — <project-slug>

_Updated: <ISO>_

## Epics

| ID | Title | Status | Stories | Priority |
|---|---|---|---|---|
| EPIC-01 | Onboarding & stack selection | ready | — | P0 |

## Stories

_(empty until first Epic decomposes)_

## Tasks

_(empty)_

## Bugs

_(empty)_
```

Create `docs/handoff-log.md` with header only.

## Step 5 — Create EPIC-01

Write `docs/tickets/EPIC-01.md`:

```yaml
---
id: EPIC-01
type: epic
title: Onboarding & stack selection
parent: null
owner: architect
status: ready
priority: P0
estimate: M
created: <ISO>
acceptance:
  - "ADR-001 exists and is approved, selecting the stack per Q9"
  - "docs/architecture/overview.md exists with a one-page system sketch"
  - "Code repo <project> contains an empty README and a /docs link to the docs repo"
depends_on: []
blocks: []
---

## Context

This is the bootstrap Epic. The team cannot proceed until the architect has selected a stack (ADR-001) and produced an overview. Vision, Q&A, and non-goals are attached.

## Scope

- Choose stack consistent with Q9 (deferred to architect if user said "architect's call").
- Sketch a one-page system overview.
- Initialize the code repo skeleton (README, license placeholder, .gitignore).

## Non-goals

- No feature work this Epic.
- No DB schema yet — that belongs to the first feature Epic.

## Open questions

- (filled as architect discovers them via `question` messages)
```

## Step 6 — Commit and push docs

```
cd ~/.openclaw/workspace-project-lead/docs
git add .
git commit -m "[EPIC-01] Onboard project <slug>: vision, Q&A, risk register, EPIC-01"
git push -u origin main
```

If push fails, escalate to user via `escalate-to-user` with the git error message; do NOT proceed to step 7 until push succeeds.

## Step 7 — Dispatch first handoff to architect

Write `outbox/<ISO>-architect-handoff.json`:

```json
{
  "type": "handoff",
  "from": "project-lead",
  "to": "architect",
  "ticket_id": "EPIC-01",
  "artifact_paths": [
    "docs/project/vision.md",
    "docs/requirements/Q&A-onboarding.md",
    "docs/tickets/EPIC-01.md"
  ],
  "summary": "Project onboarded. Please author ADR-001 (stack) and docs/architecture/overview.md per EPIC-01 acceptance.",
  "acceptance": [
    "ADR-001 exists and is approved",
    "docs/architecture/overview.md exists",
    "Code repo <project> contains README + .gitignore"
  ],
  "blocking_questions": []
}
```

Append to `docs/handoff-log.md`. Commit and push the log update.

## Step 8 — Confirm with user

Send to user:

> "Project `<slug>` is onboarded. Vision, Q&A, and the first risk register are committed to `<docs-repo-url>`. I've dispatched EPIC-01 to the architect (Cassius) to choose the stack via ADR-001. I'll ping you when ADR-001 is ready for your sign-off. — Atlas 🧭"

## Step 9 — Transition

Move to MONITOR state. The session is no longer in STANDBY.

## On-error summary

- User abandons mid-interrogation → save partial Q&A, mark `status: paused`, return to STANDBY.
- Git operations fail → escalate to user with raw error; do not partially commit.
- Any validation fails (slug regex, vision word count) → re-prompt the offending question; never silently fix.

---
name: onboard-project
description: One-time project intake; gathers vision, users, jobs, deadline, repo list (N repos typed as code/docs), stack preference; scaffolds the docs repo and dispatches first handoff to architect.
trigger: User initiates the very first project on a fresh template (repos/ does not exist) OR explicitly asks to "start a new project".
inputs: User chat. Workspace with no repos/ directory.
outputs: docs/<docs-repo-name>/ scaffold (vision.md, repos.md, glossary.md, risk-register.md, decision-log.md, board.md, handoff-log.md), tickets/EPIC-01.md, requirements/Q&A-onboarding.md, outbound handoff to architect.
---

# onboard-project — deterministic procedure

This skill runs **once per workspace lifetime**. After it succeeds, the template is no longer a template; it is a project. Never run it twice without explicit user instruction.

## Preconditions check

1. Confirm `~/.openclaw/workspace-project-lead/repos/` does not exist. If it does, ABORT with: "Project already onboarded. Use `interrogate-user` + `draft-epic` for new features."
2. Confirm I am `project-lead` per `IDENTITY.md`. If not, ABORT.
3. Confirm `CONVENTIONS.md` is readable (symlink target resolves).

## Step 1 — Greet and frame

Send to user (channel: direct):

> "Hi — I'm Atlas, your Project Lead. Before the team starts, I need ten minutes of your time to lock the basics. I'll ask one question at a time. Plain answers are fine; I'll ask follow-ups where needed. Ready?"

Wait for user `yes`/`go`/equivalent affirmative. If they say no or "later", park in STANDBY.

## Step 2 — Interrogation checklist (asked in this order)

Ask one question per turn. After each answer, write it into `misc/Q&A-onboarding-draft.md` (creating the file on the first answer). Format each entry as:

```
### Q<N>: <question>
**Asked:** <ISO timestamp>
**Answer:** <user's literal words>
**My read:** <one-line paraphrase to confirm understanding>
```

Required questions, in order:

1. **Project slug** (lowercase, hyphenated, no spaces; used to name resources). Validate: regex `^[a-z][a-z0-9-]{2,40}$`. If invalid, ask again.
2. **One-sentence vision.** "Finish this sentence: 'This project exists so that <who> can <do what> better than today.'" If they give two sentences, ask them to pick one. If they refuse to be concise, accept the longer answer but flag it for compression in the vision doc.
3. **Target users.** "Who specifically — name a real persona or job title, not 'everyone'." Reject "everyone", "anyone", "users". Ask up to twice for specificity; on third attempt, accept and add a risk to the register.
4. **Top 3 jobs to be done** (numbered list). "What are the three concrete things a user will do with this in week 1?" Require exactly three. Fewer → ask for more. More → ask which three are P0.
5. **Deadline horizon.** "Is this 2 weeks, 2 months, or 2 quarters?" Accept any specific date instead. Record as ISO date; if vague, record as a range.
6. **Budget signal.** "Any hard cost ceiling on infra/SaaS/services per month, or budget for engineering hours?" Accept "none yet".
7. **Docs repo URL.** "Where is your documentation repository? Give me the clone URL (https:// or git@). The repo name from the URL will be used as-is — e.g. `https://github.com/acme/my-project-docs` → repo name `my-project-docs`."

   Validate: URL starts with `https://` or `git@`. If the user says "you create it" or "it doesn't exist yet", respond: "I cannot create remote repos. Please create an empty repo on your git host (GitHub/Gitea/Forgejo/GitLab) and paste the clone URL here."

   Extract the repo name from the URL (last path segment, strip `.git` if present). This is the `<docs-repo-name>` used throughout.

   **Code repos are NOT asked at onboarding.** The architect will propose the code repo structure as part of EPIC-01, based on the stack decision and system design. The user will confirm before any code repos are created.

8. **Stack preferences.** "Any non-negotiable stack choices (language, framework, DB, host), or is it the architect's call?" Accept "architect's call" — that's the recommended path. Record any constraints.
9. **Non-goals.** "Name two or three things this project is explicitly NOT trying to do. This shortens the project by weeks." Require at least two. If user struggles, ask leading examples: "Not multi-tenant? Not mobile? Not real-time?"
10. **Deal-breakers / known risks.** "Anything that would kill the project if it went wrong?" Record verbatim in `risk-register.md`.
11. **User profile for me.** "What should I call you? Timezone? Preferred response style — brief, detailed, casual, formal?" Record into `USER.md`.

After Q11, re-read the entire Q&A back to the user as a numbered list. Ask: "Anything wrong, missing, or to change?" Accept corrections; save the final Q&A.

The docs repo name extracted from Q7 is referenced throughout this skill as `<docs-repo-name>`.

## Step 3 — Clone the docs repo and scaffold

Clone the docs repo:

```
git clone <docs-repo-url> ~/.openclaw/workspace-project-lead/docs/<docs-repo-name>
cd ~/.openclaw/workspace-project-lead/docs/<docs-repo-name>
```

If clone fails (empty remote, auth issue), initialize locally and add the remote:

```
mkdir -p ~/.openclaw/workspace-project-lead/docs/<docs-repo-name> && cd $_
git init
git remote add origin <docs-repo-url>
git checkout -b main
```

Create the directory skeleton inside the cloned docs repo:

```
project/           ← project-level docs (owned by project-lead)
tickets/           ← all ticket files (owned by project-lead)
requirements/      ← Q&A transcripts (owned by project-lead)
architecture/      ← architect will own; create empty
ui/                ← uiux owns; create empty
reviews/           ← reviewer owns; create empty
qa/                ← qa owns; create empty
handoff-log.md
```

Move `misc/Q&A-onboarding-draft.md` into the cloned repo at `requirements/Q&A-onboarding.md` and delete the draft.

## Step 4 — Write project files

Create `project/repos.md` inside `docs/<docs-repo-name>/`:

```markdown
# Repository list — <project-slug>

_Maintained by project-lead. Code repos are added by architect after EPIC-01 stack decision, once the user confirms._

| Name | Type | URL | Notes |
|---|---|---|---|
| <docs-repo-name> | docs | <docs-repo-url> | central documentation repo |
```

Code repo entries are added here by the architect handoff response (after EPIC-01).

Create `project/vision.md`:

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

- <from Q9 item 1>
- <from Q9 item 2>
- <from Q9 item 3 if any>

## Constraints

- Deadline: <Q5>
- Budget: <Q6>
- Stack: <Q8 verbatim, or "architect's call (ADR-001)">
- Repos: <count> repos — <list slugs and types>
```

Validate: vision.md is ≤500 words. If over, compress before saving (preserve user phrasing for vision sentence verbatim).

Create `project/glossary.md`:

```markdown
# Glossary

_Domain terms used in this project. Append-only with dated edits._
```

Create `project/risk-register.md`:

```markdown
# Risk register

| ID | Risk | Severity | Owner | Status | Created | Review by |
|---|---|---|---|---|---|---|
| R-1 | <from Q10> | high | project-lead | open | <ISO> | <ISO+7d> |
```

Add a row for each Q10 risk. If user gave none, add R-1 as "No known deal-breakers stated; verify after week 1".

Create `project/decision-log.md`:

```markdown
# Decision log

_Append-only. Each entry: ISO timestamp, decision id, decider, summary, link to ticket if any._

- <ISO> | D-001 | user | Project onboarded; slug=<slug>; stack=<Q8>; deadline=<Q5>; repos=<slugs>. | requirements/Q&A-onboarding.md
```

Create `board.md`:

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

Create `handoff-log.md` with header only.

## Step 5 — Create EPIC-01

Write `tickets/EPIC-01.md`:

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
  - "ADR-001 exists and is approved, selecting the stack per Q8"
  - "architecture/overview.md exists with a one-page system sketch"
  - "architecture/folder-structure.md exists, declaring the canonical layout for every proposed code repo"
  - "Code repos proposed in architecture/folder-structure.md are confirmed by the user and created on the git host"
  - "project/repos.md is updated with all confirmed code repo entries"
  - "Every confirmed code repo contains a README and .gitignore skeleton"
depends_on: []
blocks: []
---

## Context

This is the bootstrap Epic. The team cannot proceed until the architect has selected a stack (ADR-001), proposed the code repository structure, got user confirmation, and initialized the repos. Vision, Q&A, and non-goals are attached.

## Scope

- Choose stack consistent with Q8 (deferred to architect if user said "architect's call").
- Sketch a one-page system overview.
- Propose code repo names, purposes, and ownership; escalate to project-lead for user confirmation.
- Create confirmed code repos on the git host (architect creates them if `GIT_HOST_TOKEN` allows; otherwise escalate to user).
- Initialize each code repo skeleton (README, .gitignore, folder skeleton per folder-structure.md).
- Write architecture/folder-structure.md — canonical path layout for every code repo.
- Update project/repos.md with all confirmed repos.

## Non-goals

- No feature work this Epic.
- No DB schema yet — that belongs to the first feature Epic.

## Open questions

- (filled as architect discovers them via `question` messages)
```

## Step 6 — Commit and push docs repo

```
cd ~/.openclaw/workspace-project-lead/docs/<docs-repo-name>
git add .
git commit -m "[EPIC-01] Onboard project <slug>: vision, repos, Q&A, risk register, EPIC-01"
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
    "docs/<docs-repo-name>/project/vision.md",
    "docs/<docs-repo-name>/project/repos.md",
    "docs/<docs-repo-name>/requirements/Q&A-onboarding.md",
    "docs/<docs-repo-name>/tickets/EPIC-01.md"
  ],
  "summary": "Project onboarded. Docs repo is `<docs-repo-name>`. Please author ADR-001 (stack), architecture/overview.md, and architecture/folder-structure.md. Propose code repos, then escalate to project-lead for user confirmation before creating them.",
  "acceptance": [
    "ADR-001 exists and is approved",
    "architecture/overview.md exists",
    "architecture/folder-structure.md exists with proposed code repo layout",
    "User has confirmed code repos via project-lead escalation",
    "All confirmed code repos created and contain README + .gitignore",
    "project/repos.md updated with all confirmed repos"
  ],
  "blocking_questions": []
}
```

Call `sessions_send` with `to: "architect"` and the JSON payload (see CONVENTIONS.md §12).
Append to `docs/<docs-repo-name>/handoff-log.md`. Commit and push the log update.

## Step 8 — Confirm with user

Send to user:

> "Project `<slug>` is onboarded. Vision and Q&A are committed to `<docs-repo-url>`. I've dispatched EPIC-01 to the architect (Cassius) to choose the stack, propose the code repository structure, and get your confirmation before creating anything. I'll ping you when the architect is ready for sign-off. — Atlas 🧭"

## Step 9 — Transition

Move to MONITOR state. The session is no longer in STANDBY.

## On-error summary

- User abandons mid-interrogation → save partial Q&A to `misc/`, mark `status: paused`, return to STANDBY.
- Git operations fail → escalate to user with raw error; do not partially commit.
- Any validation fails (slug regex, vision word count, repo type) → re-prompt the offending question; never silently fix.
- Fewer than one `code` repo or zero `docs` repos → re-ask Q7 stating the requirement explicitly.

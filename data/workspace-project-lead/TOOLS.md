# TOOLS.md — MCP servers I use

I do not write code, so my toolchain is intentionally minimal. Scopes are tight on purpose.

## 1. `filesystem` (scoped)

- **Scope:** `~/.openclaw/workspace-project-lead/` (recursive, read+write).
- **Use:** read/write tickets, vision, risk register, decision log, board, Q&A docs, memory files.
- **Forbidden:** reaching outside this workspace. Never read or write `workspace-architect/`, `workspace-backend/`, etc.

## 2. `git` (scoped)

- **Scope:** `~/.openclaw/workspace-project-lead/docs/` only (the `<project>-docs` repo).
- **Operations I run:** `git pull`, `git add`, `git commit`, `git push`, `git status`, `git log`.
- **Branch policy:** I commit directly to `main` of the docs repo — docs do not go through PR review. The reviewer agent gates only the code repo.
- **Forbidden:** anything in `project/` (the code repo). I do not clone the code repo.

## 3. `openclaw-messaging` (built-in)

- **Use:** send `handoff`, `question`, `escalation` to other agents and to the user.
- **Outbox:** every message written to `outbox/<ISO>-<to>-<type>.json` for audit; the gateway mirrors it into the recipient's `inbox/`.
- **User addressing:** I am the only agent allowed `to: "user"`.

## 4. `sequential-thinking`

- **Use:** Help me decompose vague user intent into Epic/Story candidates. I call it during INTERROGATE and DRAFT states. Output stays in my context — I do not commit raw think-traces to docs.

## Tools I do NOT have

- No code execution (no `bash` outside the docs git flow).
- No package managers, build tools, test runners.
- No Figma/design tools (that's `uiux`).
- No PR review tools (that's `reviewer`).

If I ever need something not in this list, I add a TODO in `MEMORY.md` and surface it during the next user check-in.

## Local notes

- **User name / pronouns / timezone:** filled in `USER.md` during onboarding.
- **Project slug:** stored in `docs/project/vision.md` frontmatter once onboarded.
- **Docs remote URL:** stored in `docs/.git/config` (set by `onboard-project`).

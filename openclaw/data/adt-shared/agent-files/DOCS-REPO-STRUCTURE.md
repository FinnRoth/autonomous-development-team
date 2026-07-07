# Docs Repo Structure

This file defines the **canonical layout of every docs-type repository** in an ADT project. Every docs repo must follow this structure exactly. Deviations require an explicit decision recorded in `project/decision-log.md`.

The structure is designed for LLM retrieval: predictable paths, one concern per file, flat where possible, named so the path alone communicates the content type and owner.

---

## Root

```
<docs-repo-name>/
├── board.md                  ← current ticket board (project-lead writes, all agents read)
├── handoff-log.md            ← append-only log of every agent-to-agent handoff (project-lead writes)
├── project/                  ← project-level metadata (project-lead owns)
├── tickets/                  ← all tickets (project-lead owns)
├── requirements/             ← Q&A transcripts from user interrogation (project-lead owns)
├── architecture/             ← system design artefacts (architect owns)
├── ui/                       ← UI/UX specifications (uiux owns)
├── reviews/                  ← PR review records (reviewer owns)
└── qa/                       ← test plans, cases, bug reports (qa owns)
```

`board.md` and `handoff-log.md` are at root because every agent reads them on wake. They must never be nested.

---

## `project/`

Project-level metadata. Written by `project-lead`. Other agents read-only.

```
project/
├── vision.md          ← one-page project vision (≤500 words); slug, deadline, users, jobs, non-goals, constraints
├── repos.md           ← registry of all repos (docs + code); name, type, URL; updated by project-lead after architect confirms
├── glossary.md        ← domain terms and definitions; append-only with dated entries
├── risk-register.md   ← live risk table: id, risk, severity, owner, status, created, review-by
├── decision-log.md    ← append-only log of every user-confirmed decision; ISO timestamp, id, decider, summary
└── dev-env.md         ← step-by-step instructions to boot the full stack from a clean checkout (backend writes, architect reviews)
```

`dev-env.md` lives here (not in a code repo) because it describes the *full stack* — it references multiple code repos and is the single authoritative boot guide for the whole project.

---

## `tickets/`

All tickets. Written and owned by `project-lead`. Ticket schema defined in `CONVENTIONS.md §3`.

```
tickets/
├── EPIC-01.md
├── EPIC-02.md
├── STORY-01.md
├── STORY-02.md
├── TASK-01.md
└── BUG-01.md
```

Rules:
- One file per ticket, named exactly `<ID>.md` (uppercase ID, no spaces).
- No subdirectories — all tickets at the same level so agents can `ls tickets/` and see the full backlog without traversal.
- Only the `status` field in frontmatter is written by agents other than `project-lead` (developer agents flip it as they claim/complete work).

---

## `requirements/`

Q&A transcripts from user interrogation sessions. Written by `project-lead`.

```
requirements/
├── Q&A-onboarding.md       ← from the onboard-project skill
└── Q&A-<topic>.md          ← one per interrogation session (feature, change request, etc.)
```

Each file is append-only once written. New information about the same topic goes in a new dated section, not a new file.

---

## `architecture/`

All system design artefacts. Owned by `architect`. Other agents read-only.

```
architecture/
├── overview.md                         ← one-page system diagram (Mermaid C4 or flow); always current
├── folder-structure.md                 ← canonical internal layout of every code repo; the path authority for all agents
├── data-model.md                       ← entities, relations, types, invariants; Mermaid ER diagram required
├── protocols.md                        ← auth, error envelope, pagination, idempotency, versioning
├── api/
│   ├── openapi.yaml                    ← OpenAPI 3.1 single source of truth for REST/HTTP APIs
│   └── events.md                       ← async/event contracts (queues, topics, webhooks); omit if not used
├── adr/
│   └── ADR-NNN-<slug>.md               ← one ADR per decision; NNN zero-padded to 3 digits
└── feasibility/
    └── feasibility-report-EPIC-NN.md   ← one per Epic; status: feasible | feasible-with-changes | infeasible
```

Rules:
- `overview.md` is a single Mermaid diagram plus one paragraph of prose. It must fit on one screen.
- `folder-structure.md` uses an annotated tree format. Every directory gets a one-line comment explaining what lives there and who owns it. This is the file all other agents read to learn internal code repo paths — it must be kept current with every structural change.
- `data-model.md` always contains a Mermaid ER block. Prose describes invariants that diagrams cannot express.
- ADR numbering is strictly sequential, never reused. Status is one of: `proposed`, `accepted`, `superseded`.
- Feasibility reports are never edited after `status` is set to `approved` or `rejected`. Amendments are new reports.

---

## `ui/`

UI/UX specifications. Owned by `uiux`. `frontend` reads; other agents read-only.

```
ui/
├── ui-spec.md              ← canonical text spec; sections §0–§8 frozen (never rename or reorder)
├── components.md           ← catalog of all UI components; one row per component with description and status
├── design-tokens.json      ← single source of truth for all visual tokens (colors, spacing, typography, radii, shadows, motion)
├── states.md               ← five-state matrix definitions (Loading, Empty, Error, Success, Disabled) per surface type
├── pages/
│   └── P-NN.md             ← one file per page; frontmatter: id, title, route, owner, status
├── flows/
│   └── F-NN.md             ← one file per user flow; frontmatter: id, title, entry, exit, steps
└── wireframes/
    └── P-NN.<png|svg>      ← one wireframe asset per page id
```

Rules:
- `design-tokens.json` is the only legitimate source of visual values. No agent writes literal colors, spacing, or typography values anywhere else.
- `components.md` is updated by `uiux` before `frontend` introduces any component. `frontend` must not introduce a component not listed here.
- Page files (`P-NN.md`) and flow files (`F-NN.md`) are numbered sequentially and never renumbered.
- Wireframes are named by page id (`P-NN`) so the relationship to the spec is unambiguous.

---

## `reviews/`

PR review records. Owned by `reviewer`.

```
reviews/
├── review-log.md   ← append-only table: ISO | PR-num | ticket-id | verdict | merge-sha | summary
└── rules.md        ← project-specific review rules that extend CONVENTIONS.md §7 (e.g. team conventions, ADR-driven rules)
```

Rules:
- `review-log.md` is append-only. Rows are never edited or deleted.
- `rules.md` is written by `reviewer` when a recurring pattern warrants a standing rule. Each rule cites the ADR or incident that motivated it.

---

## `qa/`

Test plans, case files, bug reports. Owned by `qa`.

```
qa/
├── test-plan.md              ← top-level test strategy: scope, environments, tools, entry/exit criteria
├── coverage-matrix.md        ← Stories × test status table; updated after each Story completes QA
├── test-accounts.md          ← role | slug | env-var-name table; never contains passwords
├── cases/
│   └── <STORY-ID>.md         ← one case file per Story; all test cases for that Story
├── exploratory/
│   └── <STORY-ID>/<ISO-date>/  ← per-session exploratory artifacts (HAR, console dumps, screenshots)
└── bug-reports/
    ├── BUG-NN.md             ← one bug report per bug; frontmatter matches ticket schema
    └── evidence/
        └── BUG-NN/           ← screenshots, HAR, console logs, video for that bug
```

Rules:
- `test-plan.md` is written once per project (by `bootstrap-test-plan` skill) and updated when the stack changes.
- `coverage-matrix.md` has one row per Story and columns for: story id, acceptance criteria count, automated cases, last run status, bugs filed, bugs closed.
- Case files (`cases/<STORY-ID>.md`) are the single source of truth for what is tested. Each case has a unique id, links to the acceptance criterion it covers, and an `automated: yes/no` flag.
- Bug report files use the same ticket frontmatter schema as `tickets/BUG-NN.md` (CONVENTIONS.md §3) plus additional QA fields: `severity`, `reproduced_by`, `repro_steps`, `suspected_owner`.
- Evidence directories are named by bug id so evidence is never orphaned from its bug.

---

## LLM retrieval principles

This structure is optimised for agents that navigate by path inference:

1. **Path = meaning.** An agent reading `architecture/adr/ADR-007-stripe.md` knows exactly what it contains without opening it.
2. **Flat within directories.** Tickets, ADRs, case files are all one level deep in their directories. No `tickets/epics/` vs `tickets/stories/` split — the ID prefix (`EPIC-`, `STORY-`, etc.) is the discriminator.
3. **One file, one concern.** `board.md` is only the board. `handoff-log.md` is only the handoff log. Files that mix concerns (e.g. a "status + notes" file) are forbidden.
4. **Append-only where possible.** `handoff-log.md`, `review-log.md`, `decision-log.md`, `glossary.md` are append-only. This means an agent can always read the tail to get current state without re-reading the full file.
5. **Owner is encoded in the directory.** Every agent knows which directories it may write to by reading the owner annotations above. No agent writes outside its owned directories (CONVENTIONS.md §6.1).

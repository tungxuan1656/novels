---
name: using-skills
description: Guide to using and combining skills in the Novels repo. Use when you need to pick the right skill, chain multiple skills for a task, or onboard a new contributor. Covers 21 skills, selection rules, sample workflows and real-world examples per ARCHITECTURE.md and Harness Slim.
---
# Using Skills — Using and Combining Skills in Novels
> Goal: pick the right skill, combine in the right order, no more and no less. One skill per job — chained into a workflow.
## 1. How to Invoke
```js
skill({ name: "brainstorming" }) // + writing-plans, swiftui-expert-skill, ...
```
One session can call multiple skills in sequence. Do not call a skill for light, clear, low-risk work (No feature / 1 file, <200 lines per AGENTS.md Plans).
## 2. Quick Map — 21 Skills

<!-- drift: 21 skills excluding this router; verify via init.sh -->

### Group A: Thinking & Planning

| Skill | When to Use | When NOT to Use |
|---|---|---|
| `brainstorming` | Before any creative work (new feature/component, behavior change) — required for this group (not for pure bug/gardening/docs) | Typos, quick lookups, work with a clear spec |
| `agent-docs-architect` | Need to decide which docs, where, who owns, when to read, how to keep fresh | Writing a single doc with known location/owner |
| `writing-plans` | Have spec/requirements and need a multi-step plan before touching code | Single-step work, small fix, plan already exists |
| `harness-task` | Evaluate every request: choose No feature / Inline / Separate | Repo not using Harness Slim |

### Group B: Build & Execution

| Skill | When to Use | When NOT to Use |
|---|---|---|
| `executing-plans` | Have an approved plan, execute sequentially with checkpoints | No plan yet, or tasks need parallelism |
| `subagent-driven-development` | Plan has independent tasks, want parallel execution in same session + review | Tightly dependent tasks, no plan yet |
| `codebase-design` | Design/narrow interfaces, find seams, deep modules, easy to test | Only naming/format needed (use coding-standards) |

### Group C: Code Quality & SwiftUI

| Skill | When to Use | When NOT to Use |
|---|---|---|
| `swiftui-expert-skill` | Write/review/fix SwiftUI: @Observable, composition, identity, animation, Liquid Glass | Pure logic with no UI |
| `swiftui-pro` | Review SwiftUI on 9 axes: API, views, data flow, nav, design, a11y, perf, Swift, hygiene | Quick prototype not yet needing polish |
| `frontend-design` | Need taste: palette, type, layout, signature, motion | Backend/logic with no UI |
| `coding-standards` | Naming, readability, KISS/DRY/YAGNI, smells | Already covered by a specialized skill |

### Group D: Project Operations

| Skill | When to Use | When NOT to Use |
|---|---|---|
| `harness-slim` | Create/trim harness: AGENTS.md, feature_index.json, features/, progress.md, init.sh | Only assessing whether a feature is needed (use harness-task) |
| `harness-slim-review` | Audit harness: gaps HIGH/MEDIUM/LOW, no fixes | Want to create/edit harness |
| `agent-docs-writer` | Write/edit a single doc with known owner & location (smallest scope) | Do not yet know if the doc should exist (use architect) |
| `repo-gardening` | Clean drift: duplicate helpers, dead code, small batches with verify | Only prose edits, ownership unclear |
| `simple-english` | Write/edit ASD-STE100 prose: sentences <=20/25 words, one word one meaning | Code, identifiers, commands |
| `find-skills` | Find new skills from https://skills.sh when no fit exists | Already know which skill to use |

### Group E: Debugging & Closing

| Skill | When to Use | When NOT to Use |
|---|---|---|
| `systematic-debugging` | Any bug/test failure. 4 phases: Root Cause -> Pattern -> Hypothesis -> Fix | Have not read error/stack trace yet |
| `verification-before-completion` | Before claiming "done", before commit/PR. No fresh evidence -> no claim | Nothing to verify yet |
| `git-commit` | Create Conventional Commits, analyze diff | Not yet verified |
| `handoff` | Short handoff when user requests it | progress.md complete + linked docs -> no handoff needed (only when unfinished) |

## 3. Decision Tree

```
0. Assess scale first -> harness-task (No feature / Inline / Separate) -> then pick skill

New work?
├─ Unclear / need idea exploration?          -> brainstorming
├─ Clear, needs multi-step plan?             -> writing-plans
├─ Plan already exists?                      -> executing-plans / subagent-driven-development
│                                             (independent tasks + same session -> subagent)
└─ Bug / test failure?                       -> systematic-debugging

Docs work? -> don't know what/where -> agent-docs-architect | know doc & location -> agent-docs-writer (+ simple-english)
UI work?   -> taste/look -> frontend-design | SwiftUI code -> swiftui-expert-skill + swiftui-pro | general standards -> coding-standards
Repo/harness? -> assess feature/plan -> harness-task | create/edit -> harness-slim | audit -> harness-slim-review | clean drift -> repo-gardening

Before finishing -> verification-before-completion -> git-commit -> handoff (if needed)
No matching skill? -> find-skills (https://skills.sh)
Note: Write/edit technical prose -> simple-english; design deep modules -> codebase-design
```

## 4. Combined Workflows for Novels

### Pattern 1: Complete New Feature (main path)

`harness-task -> brainstorming -> agent-docs-architect (if touching product/contracts/design) -> agent-docs-writer (+ simple-english) -> writing-plans -> subagent-driven-development / executing-plans (swiftui-expert-skill / coding-standards, + frontend-design if UI) -> swiftui-pro -> verification-before-completion (./init.sh) -> git-commit -> handoff`

*Ex feat-006 AI Reading — brainstorming chunk ~1300, retry 3x, cache processed_chapters.sqlite; architect maps docs/contracts/ai-service.md + functional-specs/ai-reading.md; writing-plans -> docs/plans/feat-006.md; subagents split cache actor, chunker, network client, UI switch.*

### Pattern 2: Bug Fix / Build Failure

`systematic-debugging Phase 1 read error/reproduce/git diff/trace -> Phase 2 compare with working code -> Phase 3 hypothesis + small test -> Phase 4 failing test -> single-point fix -> verify -> verification-before-completion -> git-commit`

Do not fix before Phase 1 is done; after 3 failures -> stop and ask about architecture.

### Pattern 3: UI/UX for a Novels Screen

`brainstorming (iPhone offline, Vietnamese, minimal) -> frontend-design (tokens + 2-pass plan->critique->build) -> swiftui-expert-skill (@Observable, extraction, ForEach identity) -> swiftui-pro (deprecated API, a11y VoiceOver/Dynamic Type) -> verification-before-completion`

*iOS 26+, Swift 5.0, no WebKit/CoreData/Keychain, SwiftUI.Text renders spans, respect Reduce Motion.*

### Pattern 4: Docs & Decisions

`agent-docs-architect (inventory->pressure->gap->artifact map->blueprint) -> user approval -> agent-docs-writer (canonical first, index after) -> simple-english -> harness-slim-review (if touching harness)`

*Ex adding docs/decisions/local-persistence.md: architect finds gap, writer 500 words, simple-english trims sentences, review ARCHITECTURE.md 1 vs local-data.md.*

### Pattern 5: Cleanup & Standardization

`repo-gardening (orient->1 small themed batch->clean Confirmed->verify) -> coding-standards or swiftui-pro -> verification-before-completion -> git-commit (refactor/style/chore)`

Do not mix gardening with features; do not create abstractions without >=2 consumers.

### Pattern 6: Harness Lifecycle

`harness-task -> harness-slim (create/edit artifacts) -> harness-slim-review (audit) -> verification-before-completion`

`AGENTS.md` is the short router, `feature_index.json` keeps 0-1 active, `progress.md` only records material result/blocker/next action.

## 5. Role Guidance

Pick skills by task (see 3 & 4), not by fixed role. Example: creative work -> `brainstorming`, bug -> `systematic-debugging`, UI -> `frontend-design` + `swiftui-expert-skill`.

## 6. Real-World Cases in Novels (4 Cases)

**Case A: "Add Next-Chapter Prefetch" (feat-007)** — `harness-task` Separate plan (>=4 files, DB+network+UI) -> `brainstorming` N=PREFETCH_COUNT 1..10 default 3 -> `writing-plans` batch-check SQLite->sequential AI fetch->Task cancel -> `subagent-driven-development` 3 lanes cache/network/UI -> `swiftui-expert-skill` cancellation/de-dup -> `verification-before-completion` ./init.sh -> `git-commit` feat(prefetch): add chapter prefetch with cancel

**Case B: "Reader loses offset on typography change"** — `systematic-debugging` Phase 1 reproduce font change->offset reset trace UserDefaults->@Observable->Reader; Phase 2 compare with feat-004 offset per slug; Phase 3 hypothesis "Typography store triggers re-init"; Phase 4 failing test->one-line isolate state->verify->`swiftui-pro` check @State private, ForEach identity

**Case C: "Polish Library + Empty state"** — `frontend-design` warm paper palette + serif display + sans body, signature horizontal bookshelf -> `swiftui-expert-skill` List perf, downsampling -> `simple-english` trim copy: "No books yet. Add a book from the catalog."

**Case D: "AI Service docs outdated after header change"** — `agent-docs-architect` gap ai-service.md missing AI_CUSTOM_HEADERS + AI_EXTRA_BODY -> `agent-docs-writer` fix canonical + link ARCHITECTURE.md 1 -> `simple-english` <=25 words/sentence description, <=20 words/instruction -> `harness-slim-review` check AGENTS.md routes

## 7. Anti-Patterns — Do Not Do

| Wrong | Right |
|---|---|
| Call `writing-plans` before clarifying ideas for creative work | `brainstorming` before planning for creative work |
| Guess-fix bugs, skip Phase 1 | `systematic-debugging` full 4 phases with evidence |
| Claim "done" without running `./init.sh` | Always run fresh `verification-before-completion` |
| Mix gardening + feature in one commit | Split batches, one theme per commit |
| Create `docs/plans/feat-xxx.md` for 1 file <200 lines | Use inline plan in `features/feat-xxx.md` |
| Use `frontend-design` for pure logic | Use `coding-standards` / `swiftui-expert-skill` |
| Call `agent-docs-writer` when doc home is unclear | Call `agent-docs-architect` first |
| Pick old SwiftUI APIs by habit | Check `references/latest-apis.md` in `swiftui-expert-skill` |
| Write long manual commit messages | Use `git-commit` to analyze diff |

## 8. Checklist Before Handoff

- [ ] Picked the right skill group (A/B/C/D/E)?
- [ ] Ordered workflow correctly (no skipped steps)?
- [ ] Each skill only did work in its scope?
- [ ] Ran `verification-before-completion` before claiming done?
- [ ] Committed via `git-commit` with Conventional Commits?
- [ ] If handing off, included concise `handoff` without duplicating spec/plan?

---

*This skill is a router for other skills. It does not replace any skill — it helps you pick and chain them correctly for Novels (iPhone, iOS 26+, offline-first, SwiftUI, ZIP book package).*

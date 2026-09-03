# AGENTS.md

Novels is an offline-first reader for iPhone. It downloads one ZIP book package and reads offline.

Product scope is iPhone only, iOS 26+, Vietnamese UI. Intended scope is iPhone-only. Observed project still lists family `1,2`. See `docs/decisions/ios-scope.md`.

## Start here

- Topology, stack, boundaries, flows → `ARCHITECTURE.md`
- Product behavior, rules, flows → `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md`, `docs/product/flows.md`
- Product terms → `docs/product/glossary.md`, `docs/product/integrations.md`, `docs/product/functional-specs/`
- Design → `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md`
- Contracts → `docs/contracts/index.md` → `catalog-api.md`, `ai-service.md`, `book-package.md`, `settings-schema.md`, `local-data.md`
- Decisions → `docs/decisions/index.md` (tech) + `docs/product/decisions.md` (business) + `SECURITY.md`
- Persistence, identity, settings → `docs/decisions/local-persistence.md`, `docs/decisions/book-identity.md`, `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md`
- Work state → `feature_index.json`, `features/`, `progress.md`
- Verification → `init.sh`

## Repository map

```
apps/novels.xcodeproj  → Xcode project (scheme novels, iOS 26.5 — see ARCHITECTURE.md §1)
apps/novels/           → SwiftUI module (single, stub)
docs/                  → product, contracts, design, decisions
init.sh                → verification source of truth
```

Stack and toolchain live in `ARCHITECTURE.md` §1. Verification steps live in `init.sh`.

## Assess the task

Assess scale, complexity, and impact before you create or update a feature. Use no feature for lightweight work. Use an inline plan for bounded tracked work. Use a separate linked plan for substantial work.

If the work does not need a feature, read only the relevant sources. Then run proportional verification without updating feature or progress state.

## Start feature work

1. Run `./init.sh`.
2. Read `feature_index.json`.
3. Read the selected feature file in `features/`.
4. Read the latest block in `progress.md`.
5. Load only the documents linked by the selected feature.

If baseline verification fails, record the failure. Fix the failure only when the current scope includes it.

## Working rules

- Keep at most one feature `active`. Zero active features means the repository is idle.
- Use only `todo`, `active`, `blocked`, or `done` for feature status.
- Start `todo` work only after the user selects or approves it.
- Keep feature work inside the active scope and acceptance criteria.
- Complete every dependency before you activate its dependent feature.
- Record scope, acceptance, evidence, and handoff in the feature file.
- Record a result in `progress.md` only when the result, blocker, handoff, or next action materially changes. Do not copy feature scope there.
- Update `init.sh` when verification commands or workspace modules change.

## Plans

- Keep the plan inside `features/feat-<id>.md` for bounded work (1-3 files, 1 workspace, <200 lines).
- Create `docs/plans/feat-<id>.md` only for substantial work (>=4 files or >=2 workspaces, DB migration, breaking API, or needs phases/rollback — requires >=2 signals). Default to inline.
- Link the external plan from the feature file.
- Define agent and file ownership before parallel work starts.

## Escalation

- Read the relevant project document before you make an architecture or product decision.
- Ask the user when requirements, scope, ownership, or repeated verification failure remain unclear.

## Feature done

A feature is done only when:

- [ ] Every acceptance criterion passes.
- [ ] `./init.sh` passes (full, not `--quick`).
- [ ] The feature file records verification evidence.
- [ ] `progress.md` records the result and next action.

## End session

1. Update the feature status and handoff.
2. When state materially changes, add a new block below the final template note in `progress.md`. Do not edit older blocks.
3. Record blockers and one next action when they exist.

## Verification

- Full: `./init.sh` — format + lint + build + test + drift (source of truth, use for CI / pre-push / feature done)
- Quick: `./init.sh --quick` (alias `-q`) — only format + lint + drift, skip build/test (for fast local loops)
- Help: `./init.sh --help`

`init.sh` is the source of truth. Full runs format, lint, build, test, drift. Quick skips build/test to save time. For feature done and before commit/push always run **full** `./init.sh`. See `ARCHITECTURE.md` §5 for evidence.

<!-- harness-slim 1.4.0 · generated 2026-08-24 · managed sections above; check drift with skill CHANGELOG.md -->

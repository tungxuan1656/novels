# AGENTS.md

Novels — iOS app (offline-first reader). One reader downloads ZIP book packages from a remote catalog once and reads offline. AI translate (natural Vietnamese, keep honorifics) and summary (50–60%, keep plot/dialogue) via configurable OpenAI-compatible service with single ProcessedChapter cache (`bookId+chapterNumber+mode`, BR-07). Prefetch next N=3 sequentially, cancellable. Per-book scroll offset, typography persists, settings sanitize on launch.

Product: iPhone only, iOS 26+, Vietnamese UI (project still family 1,2 — see `docs/decisions/ios-scope.md`).

Routes — topology: `ARCHITECTURE.md`; product: `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/flows.md`, `docs/product/business-rules.md`, `docs/product/glossary.md`, `docs/product/integrations.md`, `docs/product/functional-specs/`; design: `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md`; contracts: `docs/contracts/index.md` → `catalog-api.md`, `ai-service.md`, `book-package.md`, `settings-schema.md`, `local-data.md`; decisions: `docs/decisions/index.md` (tech incl. `local-persistence.md`, `book-identity.md`) + `docs/product/decisions.md` (business) + `SECURITY.md`; persistence/identity/settings → `docs/decisions/local-persistence.md`, `docs/decisions/book-identity.md`, `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md`; work state: `feature_index.json`, `features/`, `progress.md`; verify: `init.sh`.

Stack: `SwiftUI / Xcode — apps/novels.xcodeproj` (scheme `novels`, iOS 26.5, Swift 5.0, `DEVELOPMENT_TEAM M5U4E4H84J`). Single module `apps/novels`. SwiftLint 0.65.1 + SwiftFormat 0.62.1 via `.swiftlint.yml`/`.swiftformat` + `.githooks/pre-commit` (setup `scripts/setup.sh`). No SwiftPM/Node, no test target yet (first feature will add tests).

## Assess the task

Before creating or updating feature, plan, or progress artifacts, assess the task's project scale, complexity, and impact. Use no feature for lightweight work, an inline feature plan for bounded tracked work, and a separate linked plan only for substantial work.

For work that does not need a feature, read only the relevant sources and run proportional verification without updating feature or progress state.

## Start feature work

1. Run `./init.sh`.
2. Read `feature_index.json`.
3. Read the selected feature file in `features/`.
4. Read the latest relevant block in `progress.md`.
5. Load only the documents linked by the selected feature.

If baseline verification fails, record the failure. Fix it only when the current scope includes it.

## Working rules

- Keep at most one feature `active`. Zero active features means the repository is idle.
- Use only `todo`, `active`, `blocked`, or `done` as feature status.
- Start `todo` work only after the user selects or approves it.
- Keep feature work inside the active feature's scope and acceptance criteria.
- Complete every dependency before activating its dependent feature.
- Record scope, acceptance, evidence, and handoff in the feature file.
- Record a feature result in `progress.md` only when the result, blocker, handoff, or next action materially changes. Do not copy feature scope there.
- Update `init.sh` when verification commands or workspace modules change.

## Plans

- Keep the plan inside `features/feat-<id>.md` for bounded tracked work (1-3 files, 1 workspace, <200 lines).
- Create `docs/plans/feat-<id>.md` only for substantial work (>=4 files or >=2 workspaces, DB migration/breaking API, or needs phases/rollback — requires >=2 signals). Default to inline.
- Link the external plan from the feature file.
- Define agent and file ownership before parallel work starts.

## Escalation

- Read the relevant project document before making an architecture or product decision.
- Ask the user when requirements, scope, ownership, or a repeated verification failure remain unclear.

## Feature done

A feature is done only when:

- [ ] Every acceptance criterion passes.
- [ ] `./init.sh` passes.
- [ ] The feature file records verification evidence.
- [ ] `progress.md` records the result and next action.

## End feature session

1. Update the feature status and handoff.
2. When state materially changed, add a new block below the final template note in `progress.md`; do not edit older blocks.
3. Record blockers and one next action when they exist.

## Verification

- Full: `./init.sh` → format (`swiftformat --lint apps --verbose`) → lint (`swiftlint lint --strict`) → build (xcodebuild simulator) → test (SKIP). Evidence: `apps/novels.xcodeproj/project.pbxproj` (scheme novels, iOS 26.5), `xcodebuild -list` shows single target, `xcrun simctl list` shows iPhone 17 Pro (iOS 26.5). No test target/dir — explicit SKIP in `init.sh`. Lint/format active via `.swiftlint.yml`/`.swiftformat`/`.githooks/pre-commit`, setup via `scripts/setup.sh`.

<!-- harness-slim 1.4.0 · generated 2026-08-24 · managed sections above; check drift with skill CHANGELOG.md -->

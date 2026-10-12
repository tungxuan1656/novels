# Verification and Documentation Alignment Implementation Plan

**Goal:** Fix false verification success and align current guidance with the app and approved unit-only/iOS 26.0+ policies.

**Architecture:** Keep the single app module. Add one hosted unit-test target to the existing shared scheme.

## Constraints

- iPhone only; minimum iOS 26.0; Vietnamese UI; English code and documentation.
- Add tests only for high-risk ZIP ingestion, SQLite cache behavior, and tolerant AI response decoding. Separate suites by responsibility.
- No UI tests, new packages, CI, state validator, or changes to past progress/plan evidence.
- Preserve feat-030 acceptance and verification evidence; update only its current handoff.
- Parent owns all edits. Reviewers are read-only; they do not run verification concurrently.

The original phases below were completed with an 18.6 floor. Their checked steps are historical; the current revision follows Phase 3.

## Phase 1 — Verification and Focused Tests

- [x] Create `apps/novelsTests/ZipIngestionTests.swift`: valid package, exact-root rejection, traversal, CRC and expansion-limit rejection.
- [x] Create `apps/novelsTests/ProcessedChapterCacheTests.swift`: key separation, upsert, multi-chunk batch lookup, and version-1 invalidation.
- [x] Create `apps/novelsTests/AIResponseTests.swift`: chat reasoning fallback, Responses block filtering, Anthropic filtering, malformed/no-text responses.
- [x] Add hosted `novelsTests` to `apps/novels.xcodeproj/project.pbxproj` and the shared scheme. Do not add UI tests.
- [x] Replace missing-tool SKIP paths in `init.sh` and `.githooks/pre-commit` with failure. Full init runs unit tests; quick skips build and tests explicitly.
- [x] Confirm negative missing-tool checks return nonzero and new suites pass without network or user-data access.
- [x] Bypass `AppRoot` in the hosted XCTest process and add `TestHostTests.swift` to check detection before production startup.

## Phase 2 — Current Guidance

- [x] Align project deployment defaults to the existing app target floor 18.6. Inspect Debug/Release effective settings and API availability.
- [x] Rewrite `ARCHITECTURE.md` code map and flows from current entry points, reader, AI client/service, cache, and FIFO prefetch.
- [x] Update `README.md`, `AGENTS.md`, `.swiftlint.yml`, current product scope and decisions; record the new verification decision.
- [x] Update affected skill guidance without changing generic API availability references or orchestration policy.
- [x] Set feat-030 current handoff to done/merged PR #34; append new progress only.

## Phase 3 — Review and Delivery

- [x] Run full `./init.sh`; check missing-tool failure, shell syntax, document routes, feature dependencies, and absence of UI-test targets.
- [x] Obtain independent read-only review; address concrete scope-related findings.
- [x] Record evidence and done state only after acceptance passes.
- [x] Commit with hooks, push a new branch, and open a PR to main. Record its URL in handoff.

## Minimum-iOS Revision — User Approved

- [x] Set project, app, and unit-test Debug/Release deployment targets to 26.0.
- [x] Align current documents and skills; retain earlier acceptance evidence as history.
- [x] Check effective settings and run full init on the unchanged 26.5 simulator.
- [ ] Record the result, commit/push, and update existing PR #37.

## Verification Limits

The available simulator is iOS 26.5, not 26.0. Compilation and newer-simulator tests do not substitute for runtime QA on iOS 26.0.

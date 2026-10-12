# Hardening + Release Readiness

- Status: done
- Owner: Tung Doan
- Required to start: [feat-001](task-persistence-foundation.md), [feat-002](task-app-shell-library.md), [feat-003](task-catalog-zip-import.md), [feat-004](task-offline-reader.md), [feat-005](task-settings-cache-manager.md), [feat-006](task-ai-reading.md), [feat-007](task-chapter-prefetch.md)
- Required to integrate/release: none
- Previous ID: feat-008

## Scope and non-goals

Harden the application to iPhone-only release readiness with accessibility compliance and edge-case regression coverage:
- Enforce `TARGETED_DEVICE_FAMILY = 1` (iPhone only) across all build configurations per `docs/decisions/ios-scope.md`; verify iOS 26+ deployment target, launch screen, and app icon assets.
- Accessibility audit: contrast verification (4.5:1 text, 3:1 icons/borders), 44pt minimum touch target sizes, VoiceOver accessibility labels per `docs/design/design-system.md`.
- Comprehensive regression and edge-case sweep: offline catalog handling, invalid ZIP ingestion, missing chapter recovery, invalid custom JSON headers/body handling, SQLite cache clearance, prefetch cancellation, and kill-and-resume on reading screen.

Non-goals: No new catalog, reader, AI, prefetch, or settings features; no scope expansion beyond hardening.

## Acceptance

- [x] `TARGETED_DEVICE_FAMILY` = iPhone only (1) per `docs/decisions/ios-scope.md`, iOS 26+, assets/icons/launch verified.
- [x] Accessibility checks pass: contrast 4.5:1 text / 3:1 icons, 44pt targets per `docs/design/design-system.md:58-64`.
- [x] Regression/edge sweep executed with recorded evidence: offline, invalid ZIP, missing chapter, invalid JSON headers/body, cache clear, prefetch cancel, kill-on-Reading resume.
- [x] `./init.sh` passes; release checklist complete.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/decisions/ios-scope.md](../docs/decisions/ios-scope.md)
- [docs/design/design-system.md](../docs/design/design-system.md)
- [docs/contracts/index.md](../docs/contracts/index.md)
- [SECURITY.md](../SECURITY.md)
- [apps/novels/Info.plist](../apps/novels/Info.plist)
- [apps/novels/Resources/](../apps/novels/Resources/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `swiftformat --lint` 0/88; `swiftlint` 0 violations; `xcodebuild build` PASS; `xcodebuild test` passed 150+ tests (including HardeningRegressionTests 2, HardeningA11yTests 4, HardeningEdgeTests 7); `./init.sh` passed. Project build settings verified `TARGETED_DEVICE_FAMILY = 1` and `IPHONEOS_DEPLOYMENT_TARGET = 26.5`. Historical test suites are documented as historical records under `docs/decisions/verification.md`.
- Blockers: None.
- Next: HISTORICAL: Release readiness achieved; distribution and packaging governed by `SECURITY.md`.

# feat-008 — Hardening + Release Readiness

## Goal

Harden the app to iPhone-only release readiness with accessibility and regression coverage.

## Scope

- Change + verify `TARGETED_DEVICE_FAMILY` = iPhone only (1) per `docs/decisions/ios-scope.md`, iOS 26+, assets/icons/launch verified.
- Accessibility: contrast, labels, 44pt targets per `docs/design/design-system.md`.
- Key UI/regression and edge-case sweep (offline, invalid ZIP, missing chapter, invalid JSON headers/body, cache clear, prefetch cancel, kill-on-Reading resume).
- Final `./init.sh` evidence collection; no new product scope.

## Non-goals

- No new catalog/reader/AI/prefetch/settings functionality, no scope expansion.

## Acceptance

- [x] `TARGETED_DEVICE_FAMILY` = iPhone only (1) per `docs/decisions/ios-scope.md`, iOS 26+, assets/icons/launch verified.
- [x] Accessibility checks pass: contrast 4.5:1 text / 3:1 icons, 44pt targets per `docs/design/design-system.md:58-64`.
- [x] Regression/edge sweep executed with recorded evidence: offline, invalid ZIP, missing chapter, invalid JSON headers/body, cache clear, prefetch cancel, kill-on-Reading resume.
- [x] `./init.sh` passes; release checklist complete.

## Relevant docs

See `AGENTS.md` Routes and `features/feat-template.md` for canonical doc ownership; additional links only if feature-specific beyond routes.

## Plan

External plan at `docs/plans/feat-008.md`

- Link: `docs/plans/feat-008.md`
- Ownership: `Project config, a11y audit, regression matrix, release checklist`

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
- Accessibility audit (VoiceOver/contrast/target size)

## Handoff

- State: done
- Evidence: `docs/plans/feat-008.md`, `apps/novels/Info.plist` (LSRequiresIPhoneOS + UILaunchScreen + ATS localhost-only, ~ipad removed), `project.pbxproj` TARGETED_DEVICE_FAMILY=1 ×6 IPHONEOS_DEPLOYMENT_TARGET=26.5 ×6, `Assets.xcassets/AppIcon` 3×1024, a11y audit 44pt/labels/Dynamic Type/VoiceOver, `apps/novelsTests/HardeningRegressionTests.swift` + `HardeningA11yTests` + `HardeningEdgeTests` PASS, `xcodebuild build` PASS, `swiftformat` 0, `swiftlint` 0, `./init.sh` PASS (format/lint/build/test/drift) — swiftformat 0/88, swiftlint 0 violations in 88 files, xcodebuild build PASS (IDERunDestination empty warning only), xcodebuild test PASS 150+ tests including HardeningRegressionTests 2 + HardeningA11yTests 4 + HardeningEdgeTests 7, ./init.sh PASS [format] PASS [lint] PASS [build] PASS [test] PASS [drift] (21 siblings)
- Blockers: none
- Next: Release ready — tag / TestFlight per `SECURITY.md`; no further feature blocked

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

- [ ] `TARGETED_DEVICE_FAMILY` = iPhone only (1) per `docs/decisions/ios-scope.md`, iOS 26+, assets/icons/launch verified.
- [ ] Accessibility checks pass: contrast 4.5:1 text / 3:1 icons, 44pt targets per `docs/design/design-system.md:58-64`.
- [ ] Regression/edge sweep executed with recorded evidence: offline, invalid ZIP, missing chapter, invalid JSON headers/body, cache clear, prefetch cancel, kill-on-Reading resume.
- [ ] `./init.sh` passes; release checklist complete.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/design/design-system.md`, `docs/design/screens.md`, `docs/design/navigation.md`
- `docs/product/flows.md`, `docs/product/business-rules.md`
- `SECURITY.md`, `docs/decisions/ios-scope.md`, `docs/contracts/*`

## Plan

External plan required at activation (≥4 files expected) — create docs/plans/feat-008.md per feat-001 template

- Link: `docs/plans/feat-008.md` (to be created at activation)
- Ownership: `Project config, a11y audit, regression matrix, release checklist`

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
- Accessibility audit (VoiceOver/contrast/target size)

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-001 through feat-007 completion before activation

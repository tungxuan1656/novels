# feat-008 — Hardening + Release Readiness

## Goal

Harden the app to iPhone-only release readiness with accessibility and regression coverage.

## Scope

- iPhone-only target/assets verification (`TARGETED_DEVICE_FAMILY`, icons, launch).
- Accessibility: contrast, labels, 44pt targets per `docs/design/design-system.md`.
- Key UI/regression and edge-case sweep (offline, invalid ZIP, missing chapter, invalid settings JSON, cache clear, prefetch cancel, kill-on-Reading resume).
- Final `./init.sh` evidence collection; no new product scope.

## Non-goals

- No new catalog/reader/AI/prefetch/settings functionality, no scope expansion.

## Acceptance

- [ ] `TARGETED_DEVICE_FAMILY` iPhone-only, deployment iOS 26+, assets pass.
- [ ] Accessibility checks pass for labeled controls and 44pt targets.
- [ ] Regression/edge sweep executed with recorded evidence.
- [ ] `./init.sh` passes; release checklist complete.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/design/design-system.md`, `docs/design/screens.md`, `docs/design/navigation.md`
- `docs/product/flows.md`, `docs/product/business-rules.md`
- `SECURITY.md`, `docs/decisions/ios-scope.md`, `docs/contracts/*`

## Plan

Detailed planning deferred until activation; inline plan only if bounded. No new product scope.

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
- Accessibility audit (VoiceOver/contrast/target size)

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-001 through feat-007 completion before activation

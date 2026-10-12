# feat-031 — Verification and Documentation Alignment

## Goal

Make verification fail closed and align current documentation with the implemented app.

## Scope

- Require SwiftFormat and SwiftLint in verification and the Swift pre-commit gate.
- Add one iOS unit-test target with separate ZIP, SQLite cache, AI response suites, and a host-startup isolation check.
- Align project and app deployment settings with the approved iPhone-only, iOS 26.0+ scope.
- Repair current architecture, onboarding, decisions, skill guidance, and feat-030 handoff.

No UI tests, CI, state validator, broad test restoration, or unrelated app refactoring. Preserve historical plans and progress.

## Acceptance

- [x] Missing formatter or linter returns nonzero; it cannot produce verification success.
- [x] Focused unit tests pass through the shared `novels` scheme and full `./init.sh`; no UI-test target exists.
- [x] Project, app, and unit-test Debug/Release resolve to iOS 26.0; device family remains `1`.
- [x] Current documents and skill guidance describe implemented code, iOS 26.0+, and the unit-only policy.
- [x] feat-030 stays done; its handoff records merged PR #34 without rewriting historical evidence.
- [ ] Full `./init.sh` passes after the floor revision; existing PR #37 is updated.

## Plan

[Implementation plan](../docs/plans/feat-031.md). Parent owns all writes. Read-only reviewers inspect API compatibility and the final diff.

## Evidence

### Initial Verification — Before Minimum-iOS Revision

The following evidence records the previously approved 18.6 floor, not the current support policy.

- Baseline full `./init.sh` passed on Xcode 26.6, iPhone 17 Pro/iOS 26.5; tests were skipped.
- Full `./init.sh` passes with 0 format/lint violations and 13/13 unit tests passed, 0 skipped/failed (XCResult summary); build and drift pass. Quick mode explicitly skips build/tests.
- Six isolated PATH checks cover missing formatter, missing linter, and both, for `init.sh --quick` and the Swift pre-commit gate. Every case exits 1 without a success message.
- Debug/Release `xcodebuild -showBuildSettings` resolve to deployment 18.6, family `1`, and Swift 5 language mode. Static API review finds no unguarded API above 18.6; reader scroll APIs require 18.0.
- `bash -n`, `plutil -lint`, and `git diff --check` pass. One-off feature/dependency/cycle and changed-document link checks pass; no validator is added.
- Independent review: Approved after correcting host-session/network risk and imprecise ATS prose. XCTest startup now bypasses `AppRoot` before production initialization; the host detection test passes. ATS docs describe the actual localhost/subdomain exception, not a port rule.
- feat-030 remains done. PR #34 is merged; only its current handoff changes. No UI-test target exists.
- Limits: no installed iOS 18.6 runtime; runtime QA on that floor remains unverified. Existing Swift 6 actor-isolation warnings are out of scope. Swift LSP checks time out or use a standalone-file context without Xcode imports; those context errors are recorded as false positives. Compile/test evidence is authoritative.

## Scope Revision

The user selected iOS 26.0+ instead of 18.6+. Keep the simulator on 26.5 and preserve all verification/test repairs.

- Effective Debug/Release settings for `novels` and `novelsTests`: floor 26.0, device family 1, Swift 5 language mode. All six project settings agree.
- Full `./init.sh` passes; XCResult reports 13/13 passed, 0 failed/skipped, on iPhone 17 Pro/iOS 26.5.
- Built app and unit-test Info.plists both report `MinimumOSVersion=26.0`; shell syntax, project plist and diff checks pass. Current docs and skills are aligned; historical 18.6 evidence is retained.
- Runtime limit: no installed iOS 26.0 runtime.

## Handoff

- State: active
- Delivery: [PR #37](https://github.com/tungxuan1656/novels/pull/37), branch `fix/031-verification-docs-alignment`; implementation commit `f9f2154`.
- Blockers: none
- Next: verify the 26.0 revision and push it to PR #37. iOS 26.0 runtime QA remains a separate follow-up.

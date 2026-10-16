# PR 45 - Background Prefetch Lifecycle Repairs

- Status: done
- Owner: Codex
- Required to start: none; user approved the three PR review repairs.
- Required to integrate/release: real-iPhone verification remains required by the background-processing ADR.

## Scope

Bind continued processing to one prefetch generation, complete expired system tasks without waiting for shared AI requests, and repair format/lint failures. Keep the existing FIFO and AI/cache behavior. No unrelated cleanup or new scheduling capabilities.

## Acceptance

- [x] Replacing a worker cannot transfer progress, disappearance protection, or expiration cancellation to another generation.
- [x] Expiration completes the system task once, without waiting for a Reader-owned shared request.
- [x] Regression tests cover replacement, delayed launch, expiration, completion, and refused submission.
- [x] Full `./init.sh` passes.

## Sources

- [Background AI processing decision](../docs/decisions/background-ai-processing.md)
- [Chapter prefetch contract](../docs/product/functional-specs/chapter-prefetch.md)

## Plan

1. Scope protection, progress and cancellation to a worker generation.
2. Add controlled lifecycle regressions and repair formatting/lint.
3. Run full verification and record the handoff.

## Verification And Handoff

- Baseline: `./init.sh` failed SwiftFormat in three files; separate SwiftLint reported two errors. Separate simulator build and unit tests passed.
- Focused lifecycle and bilingual tests passed after the lifecycle changes, using `xcodebuild test` on iPhone 17 Pro / iOS 26.5.
- Full `./init.sh` passed on 2026-10-16: SwiftFormat, strict SwiftLint, simulator build, and all focused unit tests on iPhone 17 Pro / iOS 26.5. `git diff --check` also passed. Log: `/tmp/novels-pr45-fixed-verification.log`.
- Build retains existing Swift concurrency warnings, including actor-isolated SHA256 helpers; these are outside the approved lifecycle repair.
- Independent read-only review found no concrete issue in the inspected lifecycle code and tests, but could not access the diff, so it is not a full change review. The implementing agent inspected the diff.
- Blockers: none for the code repair. Real-iPhone BackgroundTasks delivery/expiration and iOS 26.0 runtime behavior remain unverified and are release gates, not proven by iOS 26.5 simulator checks.
- Pre-commit verification: full `./init.sh` passed again on 2026-10-16, including strict lint, build, and unit tests. Log: `/tmp/novels-pr45-precommit-verification.log`.
- Handoff branch: `feat/ios26-background-ai-processing` for PR 45; user approved commit and push.
- Next: complete the ADR's real-device checks before release.

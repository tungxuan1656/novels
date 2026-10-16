# Recover Failed Prefetch Chapters on Navigation

- Status: done
- Owner: Codex
- Required to start: none
- Required to integrate/release: none

## Scope and non-goals

Recover uncached failed chapters inside the next-N window on Next/Prev without restarting matching work. Fix stale in-flight state and queue-drain races. Keep bounded retries, cache safety, sequential processing, and existing budgets. No new background scheduler, cache schema, or UI.

## Acceptance

- [x] A settled failed chapter is eligible on the next window reconciliation.
- [x] Next and Prev recover failures still inside the window; cached and genuinely running chapters are not duplicated.
- [x] Retries remain bounded; superseded workers cannot change the new queue.
- [x] Queue completion cannot discard navigation top-ups.
- [x] Focused regression tests and full `./init.sh` pass.

## Sources

- [Prefetch behavior](../docs/product/functional-specs/chapter-prefetch.md)
- [Focused verification](../docs/decisions/verification.md)

## Plan

1. Reproduce settled-failure exclusion with focused queue tests.
2. Make queue settlement generation-safe and completion synchronous; cover navigation recovery.
3. Update the behavior contract and run full verification.

## Verification and handoff

- Red: focused `PrefetchQueueTests` failed `testExhaustedFailureIsAdmittedByNextAndPreviousWindows` before the production fix.
- Green: focused queue and bilingual pipeline tests passed after the fix. Added Next/Prev reader-to-cache regressions, bounded retry, in-flight exclusion, and stale-generation rejection.
- Full: final `./init.sh` passed format, strict lint, simulator build, and 164 tests (zero failures) on iPhone 17 Pro / iOS 26.5, including the recovered-chapter-before-new-tail assertion.
- Review: independent static review found no concrete issue; reviewer lacked diff/test access. Implementer checked the diff and ran verification.
- Limits: fixture AI requests, not a live provider; no device or iOS 26.0 runtime check. Queue-drain safety is structural, not a scheduler-controlled race test.
- Blockers: none.
- Next: review PR from `fix/prefetch-failed-chapter-recovery` into `main`. Includes version 1.1.4; `fastlane ios distribute` succeeded. Full `./init.sh` passed again before commit.

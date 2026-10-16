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
- [x] Same-worker recovery clears its chapter error but preserves other failures in status and continued-processing completion.
- [x] Focused regression tests and full `./init.sh` pass after the review repair.

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
- Full: `./init.sh` passed format, strict lint, simulator build, and 166 tests (zero failures) on iPhone 17 Pro / iOS 26.5 after the review repair. Protected-worker regressions verify clean recovery and preservation of another chapter's unresolved failure.
- Review follow-up: same-worker recovery regression failed before repair: cache held chapter 4, but terminal status remained `Hoàn tất với 1 lỗi`. Replaced historical error strings with chapter-keyed unresolved errors.
- Limits: fixture AI requests, not a live provider; no device or iOS 26.0 runtime check. Queue-drain safety is structural, not a scheduler-controlled race test.
- Blockers: none.
- Next: review PR #46 before merge. The previously distributed 1.1.4 IPA does not include this follow-up.

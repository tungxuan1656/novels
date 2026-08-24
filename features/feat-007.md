# feat-007 — Chapter Prefetch

## Goal

Prefetch next N chapters' AI content sequentially and cancellably after a chapter is ready.

## Scope

- Eligibility: mode != `none` and current chapter ready; N = `PREFETCH_COUNT` (default 3, 1..10 else 3).
- Batch cache check for next N via `processed_chapters.sqlite`; process only misses sequentially via feat-006 AI path.
- `Task` cancellation on chapter/mode change; runtime-only `PrefetchStatus` and read-only progress UI.
- Reuse feat-006 chunk/retry/merge/de-dup/cache path unchanged.

## Non-goals

- No new AI protocol/client, no cache schema change, no background scheduling, no writable progress controls.

## Acceptance

- [ ] Prefetch runs only when eligible; batch check skips cached chapters.
- [ ] Sequential processing of misses in order; cancellation stops remaining work.
- [ ] `PrefetchStatus` remains runtime-only (not persisted); progress UI is read-only.
- [ ] Invalid `PREFETCH_COUNT` coerced to 3.

## Relevant docs

- `ARCHITECTURE.md`
- `docs/contracts/ai-service.md`, `docs/contracts/local-data.md`, `docs/contracts/settings-schema.md`
- `docs/product/functional-specs/chapter-prefetch.md`, `docs/product/functional-specs/ai-reading.md`

## Plan

Detailed planning deferred until activation; substantial scope — external/separate plan may be used when activated. No plan created now.

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Awaiting feat-006 completion before activation

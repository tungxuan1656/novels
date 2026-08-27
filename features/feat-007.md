# feat-007 — Chapter Prefetch

## Goal

Prefetch next N chapters' AI content sequentially and cancellably after a chapter is ready.

## Scope

- Eligibility: mode != `none` and current chapter ready; N = `PREFETCH_COUNT` (default 3, 1..10 else 3).
- Batch cache check for next N via `processed_chapters.sqlite`; process only misses sequentially via feat-006 AI path.
- `Task` cancellation on chapter/mode change; runtime-only `PrefetchStatus` (isRunning/total/processed/message/errors[]) read-only UI, not persisted per `docs/product/domain-model.md:66`.
- Per-chapter error → log to `PrefetchStatus.errors` & continue next chapter per `docs/product/functional-specs/chapter-prefetch.md:11`; book deleted mid-run → cancel remaining per `docs/product/flows.md:79`/`chapter-prefetch.md:35`.
- Reuse feat-006 chunk/retry/merge/de-dup/cache path unchanged.

## Non-goals

- No new AI protocol/client, no cache schema change, no background scheduling, no writable progress controls.

## Acceptance

- [x] Prefetch runs only when eligible; batch check skips cached chapters.
- [x] Sequential processing of misses in order; cancellation stops remaining work.
- [x] `PrefetchStatus` runtime-only (isRunning/total/processed/message/errors[]) read-only UI, not persisted per `docs/product/domain-model.md:66`.
- [x] Single chapter failure does not abort batch; errors collected in `PrefetchStatus.errors`.
- [x] Book folder deleted during prefetch cancels pending tasks.
- [x] Invalid `PREFETCH_COUNT` coerced to 3.

## Relevant docs

See `AGENTS.md` Routes and `features/feat-template.md` for canonical doc ownership; additional links only if feature-specific beyond routes.

## Plan

External plan required at activation (≥4 files expected) — create docs/plans/feat-007.md per feat-001 template

- Link: `docs/plans/feat-007.md`
- Ownership: `PrefetchManager (Task), PrefetchStatus (runtime), batch cache check via feat-006 path`

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: done
- Evidence: `docs/plans/feat-007.md` (790 lines, Tasks 1-4), `apps/novels/Domain/PrefetchStatus.swift`, `apps/novels/Services/PrefetchManager.swift`, `apps/novels/Persistence/SettingsStore.swift` `effectivePrefetchCount()`, `apps/novels/Features/Reading/ReaderViewModel.swift` (prefetchStatus/prefetchManager/trigger/cancel wired to load/goNext/goPrev/goToChapter/setAIMode/reprocess/onDisappear + 100ms poll), `apps/novels/Features/Reading/ReaderView.swift` read-only `prefetchStatus` indicator, tests `PrefetchStatusTests` 2 + `PrefetchManagerTests` 7 + `ReaderPrefetchIntegrationTests` 4 PASS; `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet` PASS, `swiftlint` 0, `swiftformat` 0/87, `./init.sh` PASS (format PASS, lint PASS, build PASS, test PASS 80.36s, drift PASS)
- Blockers: none
- Next: feat-008 Hardening + Release Readiness ready (depends feat-007 done) — activate when user approves

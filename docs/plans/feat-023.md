# feat-023 Reader + Prefetch Correctness Round 2 Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the four reported reader/prefetch defects (stale chapter content, wrong prefetch count perception, frozen status, sliding-window queue loss) plus the resource-safety gaps found during investigation, without changing the shipped product contracts unless explicitly noted.

**Architecture:** Five sequential phases, each independently testable: (1) generation-guard the single-slot AI state, (2) fix the status publish path and log terminal contract, (3) make the prefetch-count pipeline observable, (4) bound the prefetch retry/window behavior, (5) cap resource worst cases. Larger remodels (durable queue, event-driven status, cache versioning migration) stay on the roadmap with owner decisions recorded.

**Tech Stack:** Swift 5.0, SwiftUI (@Observable, @MainActor), Swift Concurrency (Task/generation tokens, no new actors), SQLite (chunked IN queries), XCTest (deterministic race tests with controlled mock delays).

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI (per AGENTS.md and docs/design).
- No WebKit / CoreData / Keychain / SwiftData / BGTask (per ARCHITECTURE.md).
- Offline-first: prefetch never blocks foreground chapter load.
- No prompt/chunk raw text in logs — counts and hash prefixes only (per DiagnosticsRedactor).
- `PrefetchStatus` stays runtime-only, never persisted (per feat-007).
- Chapter-level prefetch stays sequential; chunk-level parallelism inside one chapter is allowed (per feat-015/018).
- Every phase ends with `./init.sh --quick`; the feature closes only on full `./init.sh` PASS.
- TDD: failing test first for every behavior change; no production edit without a covering test.

---

## Phase 0 — Baseline

**Files:**
- Modify: none (record-only)

**Interfaces:**
- Consumes: nothing
- Produces: baseline evidence string used by all later phases (init.sh result + failing-test list)

- [ ] **Step 1: Run baseline verification**

Run: `./init.sh`
Expected: PASS (record exact output line counts: format/lint/build/test/drift)

- [ ] **Step 2: Confirm the four reported symptoms map to plan phases**

No code. Map: stale 450/451 content -> Phase 1; "only 3 chapters instead of 20" -> Phase 3 (+ Phase 4 for window behavior); "cache-hit done but UI still processing" -> Phase 2; "each next loads only 1 chapter" -> Phase 4. Record mapping in `features/feat-023.md` Handoff.

---

## Phase 1 — Stale chapter content (P1 hotfix)

Root cause (verified by 2 oracle lanes on current code): `ReaderViewModel.processedContent` is a single slot (`ReaderViewModel.swift:28`) written unconditionally after `await` (`ReaderViewModel.swift:253`), with no chapter/mode/generation check; `load(source:)` never clears it (`ReaderViewModel.swift:83-118`); `setAIMode` never cancels the in-flight `aiTask`; the cache-hit path in `AIReadingService.processedContent` (`AIReadingService.swift:271-281`) returns without a cancellation check, so a cancelled stale task still wins the write.

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift` (generation counter, snapshot guard, `setAIMode` cancel, conditional nil-out on real chapter change)
- Modify: `apps/novels/Features/Reading/ReaderView.swift` (render `processedContent` only when it belongs to the visible chapter/mode)
- Test: `apps/novelsTests/ReaderViewModelTests.swift` (extend) or new `apps/novelsTests/ReaderStaleGuardTests.swift` (preferred: new file, no churn in existing suites)

**Interfaces:**
- Consumes: existing `loadAIContent(isReprocess:)`, `goNext/goPrev/goToChapter`, `setAIMode`, `onDisappear`
- Produces: `aiGeneration: Int` (private, `@MainActor`) + snapshot-compare-before-write invariant relied on by Phases 2 and 4 (no stale overwrite of any VM-published state)

- [ ] **Step 1: Write failing race tests**

New file `apps/novelsTests/ReaderStaleGuardTests.swift` with a controllable mock AI service (fresh-chapter delay 200ms, stale-chapter cache-hit 0ms):
- `testStaleCacheHitDoesNotOverwriteNewChapter`: navigate 450 -> 451 -> 450 with the stale 451 task resolving last; assert final `processedContent` belongs to 450.
- `testRapidABA450_451_450KeepsLastWriter`: three rapid chapter hops; assert only the last generation writes.
- `testSetAIModeCancelsInFlightTask`: start rewrite load, switch mode to none mid-flight; assert stale rewrite never appears.
- `testReprocessLastWriterWins`: two consecutive reprocesses; assert second result stands.

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -only-testing:novelsTests/ReaderStaleGuardTests`
Expected: FAIL (types/members do not exist yet)

- [ ] **Step 2: Add generation guard in `ReaderViewModel`**

Minimal implementation:
- Add `private var aiGeneration = 0` (@MainActor).
- Bump it synchronously on every entry that changes what is displayed: `load(.chapterChange)`, `goNext/goPrev/goToChapter`, `setAIMode` (including `.none`, before clearing `processedContent`), `reprocess`, `onDisappear`.
- In `loadAIContent`, capture `(gen, chapter, mode)` before `await`; after `await`, `guard gen == aiGeneration && chapter == chapterNumber && mode == aiMode else { return }` before assigning `processedContent` (and before touching `isAIProcessing`-dependent error state).
- `setAIMode` must `aiTask?.cancel()` like `load` already does.
- On real `.chapterChange`, nil-out `processedContent` so the view never flashes the old chapter during load.
- Do NOT touch `PrefetchManager.swift`, `AIReadingService.swift`, or the cache schema in this phase.

- [ ] **Step 3: Gate the view on identity**

In `ReaderView.aiSection`, render `processedContent` only when the view model confirms it belongs to the visible `(chapterNumber, aiMode)` (via VM-exposed identity, not a second source of truth). No layout or copy changes.

- [ ] **Step 4: Run tests**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -only-testing:novelsTests/ReaderStaleGuardTests`
Expected: PASS 4/4. Then run existing `ReaderViewModelTests` + `ReaderViewFixTests` unmodified.
Expected: PASS (no regressions).

- [ ] **Step 5: Run quick verification and commit**

Run: `./init.sh --quick`
Expected: PASS. Then: `git add apps/novels/Features/Reading/ReaderViewModel.swift apps/novels/Features/Reading/ReaderView.swift apps/novelsTests/ReaderStaleGuardTests.swift && git commit -m "fix(reader): generation-guard AI content writes"`

**Acceptance (manual):** read ch450 with rewrite on, prefetch 451 finishes, open Log, go back -> ch450 still shows ch450 content; rapid next/prev x5 -> content always matches header; switch AI mode mid-spinner -> no ghost content from the old mode.

---

## Phase 2 — Status and log contract (P3)

Root cause (verified): three unsynchronized definitions of "done" — foreground `isAIProcessing` (`ReaderView.swift:249`), batch `statusValue.isRunning` held `true` until `finish()` after per-chapter `cache.save` logs (`PrefetchManager.swift:135-142,283`), and `LogRunBuilder.status` which ignores `cache.hit`/`dedup.shared` so hit-only groups stay `.processing` forever (`LogScreen.swift:326-340`); plus the 100ms poll publishing unconditionally after cancel (`ReaderViewModel.swift:324-336`, trailing read at L334-335) while `onDisappear` assigns "cancelled" synchronously and cancels the manager fire-and-forget (`ReaderViewModel.swift:191-199`).

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift` (epoch-guarded poll, single cancel path, one-shot resync on `.returnFromLog`)
- Modify: `apps/novels/Features/Diagnostics/LogScreen.swift` (`LogRunBuilder.status`: `cache.hit`/`dedup.shared`/`allCached` are terminal success; legitimate `prefetch.cancel` is muted, never red)
- Modify: `apps/novels/Services/PrefetchManager.swift` (log-only: add `storedN/effectiveN` to `prefetch.batchCheck` detail; no behavior change)
- Test: extend `apps/novelsTests/PrefetchStatusTests.swift` + `apps/novelsTests/LogScreenGroupingTests.swift`; no new files unless a suite grows past ~150 lines

**Interfaces:**
- Consumes: Phase 1 generation invariant (same guard discipline for every post-`await` publish)
- Produces: truthful per-run badges and a non-freezing poll, relied on by Phase 4 log assertions (`overlapKept/topUpAdded`)

- [ ] **Step 1: Write failing status tests**
- Poll test: cancel prefetch, then let the trailing read run; assert the stale `isRunning=true` never overwrites the terminal state.
- Epoch test: rapid `goNext -> goPrev -> goNext`; assert poll N-1 never overwrites poll N.
- Badge tests: group with only `cache.hit` -> Success (green); `dedup.shared` group -> not stuck Processing; `prefetch.cancel(reason=chapterChange)` group -> muted, not Failed-red.
- `returnFromLog` test: peek Log and return to the same chapter+mode; assert status resyncs from `manager.currentStatus()` instead of freezing.

Run: targeted `xcodebuild test -only-testing:` for the touched suites
Expected: FAIL on the new assertions

- [ ] **Step 2: Epoch-guard the poll and unify the cancel path**

Minimal implementation:
- Add `private var prefetchEpoch = 0`; bump synchronously in `triggerPrefetch`, `cancelPrefetch`, `onDisappear`. Poll captures its epoch; every publish (in-loop AND trailing) returns early on `Task.isCancelled || epoch != prefetchEpoch`.
- Replace the fire-and-forget `Task { await prefetchManager.cancel() }` in `onDisappear` with `prefetchEpoch += 1` plus a single ordered `Task { await cancelPrefetch() }`; remove the second terminal-write path so "cancelled" is written exactly once.
- `load(.returnFromLog)`: keep zero-API for the current chapter, but resync once via `prefetchStatus = await manager.currentStatus()` and restart the poll iff still running.
- Mark `prefetchStatus` as debug-only (comment: do not bind to Reader UI — header stays on `isAIProcessing` per `ReaderViewFixTests` contract). Deletion is explicitly deferred to roadmap.

- [ ] **Step 3: Fix the log terminal contract**

- `LogRunBuilder.status`: terminal success on `cache.hit`, on `dedup.shared` joined with its origin `cache.save`, and on `prefetch.skip(reason=allCached|emptyRange)`; legitimate cancel reasons map to a muted Cancelled state, never Failed-red. No layout changes; keep Vietnamese copy, confirmed against `docs/product/glossary.md`.
- `PrefetchManager` `batchCheck` detail gains `storedN/effectiveN` (log-only, feeds Phase 3 diagnosis).

- [ ] **Step 4: Run tests and quick verification, then commit**

Run: touched suites PASS, then `./init.sh --quick` PASS.
Commit: `git commit -m "fix(status): epoch-guarded prefetch poll and truthful log badges"`

**Acceptance (manual):** cache-hit chapter shows Success in Log, never stuck Processing; cancel-on-navigate never shows red Failure; peek Log and return -> status resyncs, never frozen "loading".

---

## Phase 3 — Prefetch-count transparency (P2)

Root cause (verified): the settings pipeline is correct for `20` (`20 in 0...1000`, covered by `SettingsStoreTests` and `PrefetchManagerTests:369-388`), so "set 20, only 3 load" is a transparency defect, not a clamp defect: strict `Int()` parsing in editor/`setValue` vs lenient `trim+Double` in `intValue()`; `SettingsView` shows stored while the manager consumes effective (diverge when out-of-range); editor copy promises "falls back to 3" while the code blocks save; `batchCheck` logs no `N`, so settings faults are indistinguishable from cache/total/budget cuts.

**Files:**
- Modify: `apps/novels/Features/Settings/SettingsView.swift` (row shows effective N)
- Modify: `apps/novels/Features/Settings/SettingsViewModel.swift` + `apps/novels/Persistence/SettingsStore.swift` (one shared trim rule; truthful editor copy)
- Modify: `docs/contracts/settings-schema.md` (document block-vs-coerce + stored-vs-effective)
- Test: extend `apps/novelsTests/SettingsEditorValidationTests.swift` + `apps/novelsTests/SettingsStoreCoercionTests.swift`

**Interfaces:**
- Consumes: `storedN/effectiveN` log fields from Phase 2
- Produces: user-visible effective-N + truthful validation copy; no range-policy change (stays `0...1000 else 3` per BR-08)

- [ ] **Step 1: Write failing transparency tests**
- `" 20"` / `"20 "` / `"20.0"` behave identically in validate, `setValue`, and `intValue` (single trim rule — product decision: accept after trim; `"20.0"` accepted via Double path like `intValue`).
- Out-of-range editor copy states the true behavior (blocked, keeps old value) instead of promising fallback-to-3.
- Settings row exposes effective N (test the view-model string, not pixels).

Run: targeted suites
Expected: FAIL on new assertions

- [ ] **Step 2: Implement (display + copy + one parser rule only)**
- No change to `0...1000 else 3`, no new settings, no migration. `sanitize()` stays silent-or-logged as today; if it coerces, emit the existing diagnostics event shape (no new event types).

- [ ] **Step 3: Update `settings-schema.md`, run suites + quick verification, commit**

Commit: `git commit -m "fix(settings): truthful prefetch-count display and validation"`

**Acceptance (manual):** set 20 with surrounding spaces saves as 20; invalid input message matches actual behavior; with 20 set, Log `batchCheck` shows `effectiveN=20` so any "only 3 load" case is attributable to cache/total/mode, not settings.

---

## Phase 4 — Prefetch retry and window behavior (P4, bounded)

Constraint (verified + spec-checked): current code implements the spec (`cancel on chapter/mode change`, `log-and-continue`, retry only via window slide or manual reprocess — `flows.md` §6, `chapter-prefetch.md` §4-5, BR-08). The user expects a durable queue. Full durable queue is roadmap. This phase stops the bleeding inside the sliding-window model: bounded in-batch retry, failed-chapter priority in the next window, trigger debounce, and overlap-preserving top-up.

**Files:**
- Modify: `apps/novels/Services/PrefetchManager.swift` (in-batch single retry, next-window failed-first ordering, overlap keep/drop/add)
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift` (200ms trigger debounce only; no lifecycle change)
- Modify: `docs/product/functional-specs/chapter-prefetch.md` (§4 Step 5: retry <= 1 in same batch + failed-first in next window)
- Test: extend `apps/novelsTests/PrefetchManagerTests.swift` (keep `testCancellationStopsRemaining` semantics for book/mode change; add retry/top-up tests)

**Interfaces:**
- Consumes: Phase 1 guard discipline + Phase 2 epoch/log fields
- Produces: no permanently-dropped near-window chapters; `prefetch.cancel(reason=chapterChange)` log volume drops on steady forward reading

- [ ] **Step 1: Write failing queue tests**
- `testFailedChapterRetriedOnceInBatch`: transient failure mid-batch is retried once, then recorded in `errors[]`.
- `testFailedChapterPrioritizedInNextWindow`: error at 453 while at 450, move to 451 -> 453 is attempted before fresh tail.
- `testOverlappingStartKeepsRunningBatch`: `start(450)` then `start(451)` same book+mode with overlap -> same generation continues, only the new tail is appended (assert via `overlapKept/topUpAdded` log fields + no duplicate `processedContent` calls for kept chapters).
- `testJumpFarRestarts`: `goToChapter` far outside overlap -> clean restart (documents the boundary).

Run: targeted suite
Expected: FAIL on new assertions; existing cancel/error tests still PASS (update only if behavior intentionally changed, with spec citation in the test comment).

- [ ] **Step 2: Implement bounded retry + top-up (no durable cross-book/mode queue)**
- Keep `generation` bump + full cancel on book/mode change, `mode == .none`, book deletion, invalid N. Same book+mode with non-empty overlap: keep the running task, update totals, append new-tail misses only.
- `returnFromLog` keeps zero-API for the current chapter (spec) but may resume background prefetch when misses remain (interpretation recorded in `chapter-prefetch.md`: "zero API for current chapter", not "zero all API").
- No new event types beyond the `overlapKept/topUpAdded/retry-enqueue` detail fields on existing events.

- [ ] **Step 3: Update spec, run suites + quick verification, commit**

Commit: `git commit -m "fix(prefetch): bounded retry and overlap-preserving window"`

**Acceptance (manual):** the exact reported walk (450 -> 451 loads 454, back to 450 quiet, 454 finishes, next to 451 loads 455) now shows continuous forward progress with no chapter silently skipped; a transient-failed chapter reappears once without manual reprocess; steady reading shows ~1 tail fetch per next instead of full-batch churn in Log.

---

## Phase 5 — Resource worst-case guards (P5B safety)

Scope (verified): `N=1000` is legal input and implies thousands of chunk POSTs per batch; `batchStatus` binds up to ~1000 params per navigation; the 100ms poll is 10 actor-hop round trips per second for batches that can run minutes. This phase caps the worst case with no product-contract change.

**Files:**
- Modify: `apps/novels/Services/PrefetchManager.swift` (runtime `appliedCap`, chunked `batchStatus`, `do/catch` that never treats query failure as miss-all, end-of-book message)
- Modify: `apps/novels/Persistence/ProcessedChapterCache.swift` (chunked helper, e.g. 200 ids per query, accumulated `Set`)
- Test: extend `apps/novelsTests/PrefetchManagerTests.swift` + `apps/novelsTests/ProcessedChapterCacheTests.swift`

**Interfaces:**
- Consumes: nothing new
- Produces: bounded per-batch cost; `appliedCap` log field for future tuning

- [ ] **Step 1: Write failing guard tests**
- Cap test: request N=1000 -> runtime applies documented `hardCap` (default 10 unless owner overrides) and logs `appliedCap`.
- Chunked query test: 1000-id `batchStatus` returns the same set as one query, without hitting bind limits.
- Query-failure test: simulated `batchStatus` throw -> batch keeps prior state and logs, does NOT refetch everything as misses.
- End-of-book test: `current=98, total=100, N=10` -> message distinguishes "2 remaining chapters" from a generic `0/10`.

Run: targeted suites
Expected: FAIL on new assertions

- [ ] **Step 2: Implement guards (no range-policy, budget, or timeout changes)**
- Keep public `0...1000 else 3`, per-chapter/global budgets, timeouts, and sequential chapters untouched. No outer-chapter concurrency (explicitly rejected: multiplies data/battery, breaks ordering tests, contradicts offline-first).

- [ ] **Step 3: Run suites + quick verification, commit**

Commit: `git commit -m "fix(prefetch): bound worst-case batch cost"`

**Acceptance (manual):** N=1000 behaves like a capped N with an honest message; airplane-mode mid-batch never triggers mass refetch; last chapters of a book show a "remaining chapters" message.

---

## Roadmap (explicitly NOT in this feature)

1. **Durable FIFO prefetch queue** (P4A approach A/C): needs owner sign-off on cancelling vs keeping on chapter change, `maxRetry`, evict policy, dynamic totals, and `returnFromLog` pause-vs-resume. Requires BR-08 / flows §6 amendment first.
2. **Event-driven status** replacing the 100ms poll (P3B approach A): only after Phases 2+5 ship and wake/CPU numbers justify it.
3. **Cache versioning migration** (`user_version 1->2` with source/prompt hash columns; P5A-B2): hotfix now is clear-on-reimport plus confirm-clear on prompt change (small, file a follow-up if wanted).
4. **Outer-chapter concurrency**: rejected unless measured `current+1` hit-rate proves the sequential model insufficient.

## Owner confirmations (defaults used unless overridden)

- `hardCap` default 10 for runtime prefetch window (public range unchanged).
- Retry: max 1 in-batch retry per chapter + failed-first in next window.
- `returnFromLog` means zero-API for the current chapter; background prefetch may resume.
- Editor copy fix direction: tell the truth (invalid input is blocked, old value kept).
- Budgets (600s/1800s), timeouts, and `0...1000 else 3` unchanged.

## File ownership (parallelization)

- Lane R (reader/state): `ReaderViewModel.swift`, `ReaderView.swift` — Phases 1, 2 (poll part), 4 (debounce part). Sequential: 1 -> 2 -> 4.
- Lane S (settings/log): `SettingsStore.swift`, `SettingsView(Model).swift`, `SettingEditorView.swift`, `LogScreen.swift`, `PrefetchManager.swift` (log-only fields) — Phase 3 + Phase 2 (badge part). May run parallel with Lane R Phase 1 (no shared files except `ReaderViewModel`, which Lane S must not touch until Lane R Phase 1 merges).
- Lane P (prefetch engine): `PrefetchManager.swift`, `ProcessedChapterCache.swift` — Phases 4 (engine part), 5. Starts after Lane R Phase 1 (shared generation discipline) to avoid conflicting `PrefetchManager` edits with Lane S log-only edits — coordinate via `overlapKept/topUpAdded/appliedCap` field names fixed above.

## Self-review

- [x] Spec coverage: P1 stale-write, P2 count, P3 status, P4 window, P5B resources each map to exactly one phase; roadmap items have no phase (by design).
- [x] Placeholder scan: no TBD/TODO; every step names files, tests, commands, and expected outcomes.
- [x] Type consistency: `aiGeneration`/`prefetchEpoch` (Int, @MainActor), `overlapKept/topUpAdded/appliedCap/storedN/effectiveN` (log detail fields on existing events, no new event types, no schema change).
- [x] No silent contract breaks: `ReaderViewFixTests` prefetch-spinner ban, `testCancellationStopsRemaining`, `testSequentialProcessingInOrder`, and `0...1000 else 3` are preserved or updated only with spec citation.

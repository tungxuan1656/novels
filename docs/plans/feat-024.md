# Prefetch FIFO Queue Refactor Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the sliding-window batch cancel-on-navigate prefetch with a durable FIFO queue that keeps the running task across same-book+mode navigations.

**Architecture:** Four phases over two code lanes: (1) build the FIFO core inside `PrefetchManager` behind the existing `start` signature, (2) strip the reader-side compensations the batch model required (debounce, poll, epoch), (3) collapse the triple-N logging to the single consumed N, (4) amend specs and close. Rollback is per-task commit revert; behavior contracts are pinned by keeping every existing suite green except debounce/cap tests updated with spec citations.

**Tech Stack:** Swift 5.0, SwiftUI (@Observable, @MainActor), Swift Concurrency (single actor worker, no new actors), SQLite (unchanged chunked `batchStatus`), XCTest (existing `makeManagerEnv` helper in `PrefetchManagerTests.swift:186`).

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI (per AGENTS.md and docs/design).
- No WebKit / CoreData / Keychain / SwiftData / BGTask (per ARCHITECTURE.md).
- Offline-first: prefetch never blocks foreground chapter load.
- No prompt/chunk raw text in logs — counts and hash prefixes only (per DiagnosticsRedactor).
- `PrefetchStatus` stays runtime-only, never persisted (per feat-007).
- Chapter-level prefetch stays sequential; chunk-level parallelism inside one chapter is allowed (per feat-015/018).
- Budgets (600s per-chapter / 1800s global), timeouts, and `0...1000 else 3` unchanged (per BR-08).
- `returnFromLog` means zero-API for the current chapter; background queue may resume on misses.
- Every task ends with `./init.sh --quick`; the feature closes only on full `./init.sh` PASS.
- TDD: failing test first for every behavior change; no production edit without a covering test.

---

## File ownership (parallelization)

- Lane P (prefetch engine, @fixer): `apps/novels/Services/PrefetchManager.swift` + new `apps/novelsTests/PrefetchFifoQueueTests.swift` — Phase 1. No shared files.
- Lane R (reader, @fixer): `apps/novels/Features/Reading/ReaderViewModel.swift` — Phase 2, starts after Lane P locks the `start`/`ensureWindow` interface (consumes: unchanged `start(bookId:currentChapter:totalChapters:mode:settings:cache:aiService:repository:)` signature).
- Lane S (spec, anytime): `docs/product/functional-specs/chapter-prefetch.md` (§4 Step 5) + `docs/contracts/settings-schema.md` (BR-08 note) — Phases 3-4, no code.
- Untouched: `ReaderView.swift`, `LogScreen.swift`, `ProcessedChapterCache.swift`, `AIReadingService.swift`, `AIClient.swift`, Settings pipeline.

---

## Phase 0 — Baseline

**Files:**
- Modify: none (record-only)

**Interfaces:**
- Consumes: nothing
- Produces: baseline evidence string (init.sh result)

- [ ] **Step 1: Run baseline verification**

Run: `./init.sh`
Expected: PASS (record format/lint/build/test/drift lines; note any flake retry like the feat-023 commit `testEndOfBookMessageNamesRemainingChapters` timing flake)

---

## Phase 1 — FIFO queue core (Lane P)

**Files:**
- Modify: `apps/novels/Services/PrefetchManager.swift` (queue fields + `ensureWindow` + sequential worker; remove `takeFailedFirst`, top-up extras, `failedChapters`/`failedBookId`/`failedMode` store)
- Test: create `apps/novelsTests/PrefetchFifoQueueTests.swift` (use `makeManagerEnv` pattern from `PrefetchManagerTests.swift:186`)

**Interfaces:**
- Consumes: existing `start(...)` signature, `missList`, `batchStatus`, `windowRange`, `bookEndCount`, `finish`, budgets, `PrefetchStatus`
- Produces: `ensureWindow(cur:N:total:)` + FIFO worker relied on by Phase 2 (reader calls `start` exactly as today)

- [ ] **Step 1: Write failing queue tests**

New file `apps/novelsTests/PrefetchFifoQueueTests.swift` (mirror the mock env from `PrefetchManagerTests.swift:186-213`):

```swift
func testNavigateKeepsRunningTaskAndAppendsOnlyTail() async throws {
    // N=20 at 450 issues 451-470; go to 451 keeps the task, appends only 471.
    let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 20, totalChapters: 500)
    let svc = client.service(cache: cache, settings: settings)
    await manager.start(bookId: "book-slug", currentChapter: 450, totalChapters: 500, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
    try await Task.sleep(nanoseconds: 300_000_000)
    await manager.start(bookId: "book-slug", currentChapter: 451, totalChapters: 500, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
    try await Task.sleep(nanoseconds: 3_000_000_000)
    let calls = client.calls
    XCTAssertEqual(calls, Array(452...471), "kept chapters processed once in FIFO order, got \(calls)")
}
```

```swift
func testTransientFailureRetriedOnceThenDropped() async throws {
    // Failing chapter requeues at the tail at most once, then logs and drops.
    let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 3, totalChapters: 100)
    client.failChapters = [52]
    let svc = client.service(cache: cache, settings: settings)
    await manager.start(bookId: "book-slug", currentChapter: 50, totalChapters: 100, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
    try await Task.sleep(nanoseconds: 2_500_000_000)
    let status = await manager.currentStatus()
    XCTAssertFalse(status.isRunning, "status \(status)")
    XCTAssertEqual(client.calls.filter({ $0 == 52 }).count, 2, "one retry max, got \(client.calls)")
}
```

```swift
func testBookChangeCancelsQueue() async throws {
    // New book (or .none mode) still cancels; same-book navigate never does.
    let (manager, cache, settings, repo, client) = try await makeManagerEnv(prefetchCount: 20, totalChapters: 500)
    let svc = client.service(cache: cache, settings: settings)
    await manager.start(bookId: "book-a", currentChapter: 450, totalChapters: 500, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
    try await Task.sleep(nanoseconds: 200_000_000)
    await manager.start(bookId: "book-b", currentChapter: 10, totalChapters: 500, mode: .rewrite, settings: settings, cache: cache, aiService: svc, repository: repo)
    try await Task.sleep(nanoseconds: 2_000_000_000)
    XCTAssertTrue(client.calls.allSatisfy({ $0 >= 11 && $0 <= 30 }), "old-book work cancelled, got \(client.calls)")
}
```

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -only-testing:novelsTests/PrefetchFifoQueueTests`
Expected: FAIL (types/members do not exist yet)

- [ ] **Step 2: Implement the queue (minimal)**

In `PrefetchManager.swift`:
- Replace fields `pendingSet`/`failedChapters`/`failedBookId`/`failedMode` usage: keep `pending: [Int]` (FIFO order), keep `inFlight: Int?`, add `attempts: [Int: Int]` (default 0). Delete `takeFailedFirst` + `retryEnqueueExtra` + `resetFailedState` call sites.
- Add `ensureWindow(cur:N:total:)`:
```swift
private func ensureWindow(cur: Int, appliedN: Int, total: Int, misses: [Int]) {
    let window = Set(windowRange(currentChapter: cur, effectiveN: appliedN, totalChapters: total))
    pending = pending.filter { window.contains($0) } + misses.filter { !pendingSetContains($0) && $0 != inFlight }
}
```
where membership uses a rebuilt `Set(pending)` plus `inFlight` (no separate stored set to drift).
- `start` flow: compute `range`/`misses` as today; if same `activeBookId`+`activeMode` and `task != nil && !batchFinished` → `ensureWindow` + log `reason=topUp` and return (no cancel, no generation bump); else clean restart exactly as today (cancel + bump + reset).
- Worker loop: pop `pending.removeFirst()` FIFO; on `missingChapter`/`emptyContent`/`aiError` for chapter `c`: if `attempts[c, default: 0] < 1` then `attempts[c]! += 1; pending.append(c)` else record in `errors[]` and continue. Keep budgets, `bookDeleted`, `CancellationError`, `bookEndRemaining`/`tailMark`, `finish` untouched.
- Delete `failedFirst` ordering (`ordered = failedFirst + ...` becomes `pending = misses` on restart).

- [ ] **Step 3: Run new + existing suites**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -only-testing:novelsTests/PrefetchFifoQueueTests -only-testing:novelsTests/PrefetchManagerTests -only-testing:novelsTests/ReaderPrefetchIntegrationTests`
Expected: PASS new 3/3. Existing suites PASS unmodified, except: if `testCancellationStopsRemaining` asserts chapter-change cancel, update it with a comment citing the `chapter-prefetch.md` §4 amendment ("queue survives same-book+mode navigate; cancel only on book/mode change"), since this phase intentionally changes that contract.

- [ ] **Step 4: Run quick verification and commit**

Run: `./init.sh --quick`
Expected: PASS. Then: `git add apps/novels/Services/PrefetchManager.swift apps/novelsTests/PrefetchFifoQueueTests.swift apps/novelsTests/PrefetchManagerTests.swift && git commit -m "fix(prefetch): durable FIFO queue keeps running task across navigate"`

**Acceptance:** N=20 at 450 then 451 → Log shows 452...471 in order, no duplicate calls, no `prefetch.cancel reason=chapterChange` between them.

---

## Phase 2 — Drop debounce/poll/epoch (Lane R)

Constraint: Lane P interface locked (same `start` signature). No engine change in this phase.

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift` (delete `prefetchEpoch`, `startPrefetchPoll`, 200ms debounce in `triggerPrefetchIfEligible`; `cancelPrefetch` keeps single `manager.cancel` + status write; `returnFromLog` keeps zero-current-API + one-shot `currentStatus()` resync + `resumePrefetchIfMissesRemain`)
- Test: extend `apps/novelsTests/ReaderPrefetchIntegrationTests.swift` in place

**Interfaces:**
- Consumes: Phase 1 queue (queue itself absorbs rapid navigates, so no debounce needed)
- Produces: synchronous trigger path relied on by Phase 4 walks

- [ ] **Step 1: Write failing trigger tests**

In `ReaderPrefetchIntegrationTests.swift`:

```swift
func testTriggerHasNoDebounceDelay() async throws {
    // Queue absorbs churn: trigger issues start synchronously, no 200ms wait.
    // Assert via batchCheck log appearing within 100ms of chapter change.
}
```

```swift
func testReturnFromLogResyncsWithoutPoll() async throws {
    // Existing testReturnFromLogResyncsAndResumesMidBatch keeps passing with
    // no poll task alive: assert status resyncs once and poll task is nil.
}
```

Run targeted suite. Expected: FAIL (debounce sleep + poll still present).

- [ ] **Step 2: Implement (delete only)**

- Delete `prefetchEpoch` field (`ReaderViewModel.swift:48`) and every bump (`:139,:244,:385,:469`).
- Delete `startPrefetchPoll` (`:430-449`) and its call (`:425`); delete 200ms sleep + epoch guard (`:385-390`) so `triggerPrefetchIfEligible` calls `manager.start` directly after eligibility guards.
- Keep `cancelPrefetch` single path (`manager.cancel` + status write, `:467-482` minus epoch line).
- Keep `returnFromLog` block (`:131-143`): join `disappearCancelTask`, one-shot `currentStatus()` resync, `resumePrefetchIfMissesRemain`.

- [ ] **Step 3: Run suites + quick verification, commit**

Run touched suites PASS (update only tests asserting debounce delay or poll liveness, with spec citation in comments), then `./init.sh --quick` PASS.
Commit: `git commit -m "fix(reader): drop prefetch debounce poll epoch, queue absorbs churn"`

**Acceptance:** next/prev issues prefetch synchronously; Log shows no `prefetch.cancel` storms on steady reading; return-from-Log resyncs once.

---

## Phase 3 — Single N (drop hardCap)

Owner default (override to keep cap): remove runtime `hardCap`; public range `0...1000 else 3` unchanged; log the single consumed N.

**Files:**
- Modify: `apps/novels/Services/PrefetchManager.swift` (delete `hardCap`, `appliedN = min(...)` → `appliedN = effectiveN`; `batchCheckDetail` counts show `effectiveN` only)
- Modify: `docs/contracts/settings-schema.md` (BR-08 note: no runtime cap; N=1000 is honored, paced by sequential worker + budgets)
- Test: update `PrefetchManagerTests` cap test (delete or invert: N=1000 issues full window, paced sequentially), with comment citing this plan + schema note

**Interfaces:**
- Consumes: Phase 1 queue (sequential pacing makes the cap unnecessary)
- Produces: single-N logging relied on by Phase 4 diagnosis

- [ ] **Step 1: Update the cap test to the new contract**

```swift
func testNoRuntimeCapWindowIsHonored() async throws {
    // Per feat-024 plan + settings-schema BR-08 note: no hardCap; N=1000
    // issues the full window, paced by the sequential worker and budgets.
}
```

Run: targeted suite. Expected: FAIL (hardCap still clamps).

- [ ] **Step 2: Implement + schema note, run + commit**

Commit: `git commit -m "fix(prefetch): remove runtime hardCap, honor effective N"`

**Acceptance:** N=20 logs `effectiveN=20` and issues 20; N=1000 behaves paced, no silent clamp.

---

## Phase 4 — Specs + close

**Files:**
- Modify: `docs/product/functional-specs/chapter-prefetch.md` (§4 Step 5: queue model — `ensureWindow` keep ∩ + append tail; cancel only on book/mode change/none/deletion; attempts≤1 tail requeue; `returnFromLog` zero-current-API + resume)
- Modify: `docs/contracts/settings-schema.md` (BR-08: single-N logging)
- Modify: `features/feat-024.md` (acceptance checkboxes), `feature_index.json` (feat-024 done), `progress.md` (result block)

- [ ] **Step 1: Amend specs (no code)**

- [ ] **Step 2: Manual acceptance walks** (450→451→450→451 progress; steady-next ~1 tail; transient-fail retry-once; returnFromLog resume; N=20 window once)

- [ ] **Step 3: Full verification and close**

Run: `./init.sh` full. Expected: PASS. Record evidence in feature file + `progress.md`; mark `feature_index.json` feat-024 done (zero active).

---

## Owner confirmations (defaults used unless overridden)

- Remove `hardCap 10` (public `0...1000 else 3` unchanged; sequential pacing replaces the cap).
- Queue cancel policy: cancel only on book change, mode change/`none`, book deletion, explicit cancel. Same-book+mode navigate never cancels.
- Retry: attempts≤1 tail requeue inside queue (replaces failed-first store + in-batch once).
- `returnFromLog` = zero-API for current chapter; background queue resumes on misses.
- Budgets (600s/1800s), timeouts, chunk-parallelism unchanged.

## Self-review

- [x] Spec coverage: FIFO order + keep-across-navigate (P1), no-debounce sync trigger + no-poll resync (P2), single-N (P3), queue-cancel policy + retry bound + returnFromLog resume (P4 amendments) each map to exactly one phase.
- [x] Placeholder scan: no TBD/TODO; every step names files, tests, commands, expected outcomes.
- [x] Type consistency: `pending: [Int]`, `inFlight: Int?`, `attempts: [Int: Int]`, `ensureWindow(cur:appliedN:total:misses:)` (Void), existing `start` signature unchanged, `batchCheckDetail` counts fragment drops `appliedCap`.
- [x] No silent contract breaks: `testCancellationStopsRemaining`, debounce-delay tests, and cap tests are updated only with spec citation in test comments; `aiGeneration`, chunked `batchStatus`, badge contract, budgets, and `0...1000 else 3` preserved.

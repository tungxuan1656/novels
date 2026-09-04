# Rewrite + Prefetch Correctness Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement feat-018 so chunk batches join in order with one retry of exactly the failed chunk, prefetch runs sequentially only on real chapter change, header shows the sole rewrite spinner, and back-from-Log makes zero API calls.

**Architecture:** Keep `AIClient` per-chunk (add 2-attempt loop with stable `requestId`), keep `AIReadingService` TaskGroup parallel-chunks + sequential-chapters, add explicit trigger source (`chapterChange` vs `returnFromLog`) in `ReaderViewModel`/`PrefetchManager`, move spinner to `ReaderView.topHeader` and delete content/sheet spinners.

**Tech Stack:** Swift 6, SwiftUI (`ReaderView`, `ReaderBottomSheet`), `@Observable` + `actor` (`ReaderViewModel`, `AIClient`, `AIReadingService`, `PrefetchManager`), `URLSession` OpenAI-compatible POST, SQLite `ProcessedChapterCache`, `DiagnosticsLog`, XCTest, `./init.sh`.

## Global Constraints

- iPhone only (`TARGETED_DEVICE_FAMILY=1`), iOS 26.5, Vietnamese UI.
- Offline-first: check `ProcessedChapter` cache (`bookId + chapterNumber + mode`) before any call; `none` bypasses cache + service.
- Chunk hint `AI_MIN_CHUNK_SIZE = 1300`; join with `"\n"` in source order; no partial cache write.
- Bounded retry: max 2 attempts per failed chunk only (every error kind), never whole batch; then toast once + raw fallback + manual "Xử lý lại".
- Prefetch N default 3, valid 1..10 else 3; sequential chapters, one batch at a time.
- Back from Log to same chapter: zero API calls, keep previous terminal status.
- No raw body/prompt/auth in logs; shape fields only (`responseJsonKeys`, `choicesCount`, `contentKind`, `hasReasoningContent`, `hasToolCalls`); `attempt` 1/2 logged separately with stable `requestId`.
- Timeouts 180s request / 600s resource, `waitsForConnectivity = true`, ATS localhost-only `http://localhost:8317`.
- `CancellationError` clears flag silently, no toast.
- Verify every task with `./init.sh --quick` and final full `./init.sh`.

---

## File Structure

- Modify: `apps/novels/Services/AIClient.swift` — per-chunk 2-attempt loop, stable `requestId`, attempt logging.
- Verify (no logic change unless broken): `apps/novels/Services/AIReadingService.swift` — TaskGroup index-keyed ordered join, fail-fast, no partial cache.
- Modify: `apps/novels/Services/PrefetchManager.swift` — generation guard already exists; ensure `start` only from chapter-change source, keep `batchStatus` + sequential + `error-continue`.
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift` — add `load(source:)`, suppress reload + prefetch on `returnFromLog`, keep `cancelPrefetch`/`triggerPrefetchIfEligible` for `chapterChange`.
- Modify: `apps/novels/Features/Reading/ReaderView.swift` — delete `aiSection` spinner + `prefetchIndicator` from content; add 12px spinner left of prev/next capsule in `topHeader`, visible only when `isAIProcessing`.
- Modify: `apps/novels/Features/Reading/ReaderBottomSheet.swift` — delete `aiProgress` block entirely; keep picker + reprocess + log button.
- Test: `apps/novelsTests/AIClientTests.swift`, `apps/novelsTests/AIReadingServiceTests.swift`, `apps/novelsTests/ReaderViewFixTests.swift` (or current UI test file), `apps/novelsTests/PrefetchManagerTests.swift` — extend, no new files unless needed.

---

### Task 1: AIClient per-chunk bounded retry (2 attempts, stable requestId)

**Files:**
- Modify: `apps/novels/Services/AIClient.swift:52-57` (attempt loop)
- Test: `apps/novelsTests/AIClientTests.swift`

**Interfaces:**
- Consumes: `AIDiagnosticsContext(requestId: UUID, bookId, chapterNumber, mode, chunkIndex, chunkTotal)` — unchanged.
- Produces: `func complete(prompt: String, chunk: String, context: AIDiagnosticsContext) async throws -> String` — same signature, now up to 2 URLSession calls for the same `context.requestId` with `attempt` 1 then 2.

- [ ] **Step 1: Write the failing test (retry exactly failed chunk)**

```swift
func testFailedChunkRetriesOnceWithStableRequestId() async throws {
    // Mock URLProtocol: first call 500, second call 200 with choices[0].message.content = "ok"
    // Call client.complete(prompt: "p", chunk: "hello", context: ctx) once.
    // Expect: result == "ok", requestCount == 2, both log entries share ctx.requestId with attempt 1 then 2.
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./init.sh --quick` (format+lint+drift) then targeted `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIClientTests`
Expected: FAIL — currently 1 request then throw (single-attempt).

- [ ] **Step 3: Write minimal implementation (loop 0..<2, all errors retry once)**

```swift
// Inside actor AIClient.complete, replace single-attempt body with:
try Task.checkCancellation()
var lastError: Error?
for attemptNumber in 1...2 {
    let attemptStart = Date()
    do {
        try Task.checkCancellation()
        // ... build request (same as today), log api entry with attempt: attemptNumber ...
        let (data, response) = try await session.data(for: request)
        // ... status/shape/decode/resolvedText handling (same as today) ...
        // on success: log success with attemptNumber, return content
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        lastError = error
        // Log failure with attemptNumber (keep today's per-branch logging, add attempt field)
        if attemptNumber == 2 { throw error }
        // attempt 1 -> fall through to retry same chunk (no sleep needed; TaskGroup already fans out)
        continue
    }
}
throw lastError ?? AIClientError.noResponse
```

Rules: retry every error kind (httpError, URLError, DecodingError→noResponse, noResponse) exactly once; `requestId` = `context.requestId` both attempts; `Task.checkCancellation()` before each attempt; `CancellationError` never logged as failure and never retried.

- [ ] **Step 4: Run test to verify it passes**

Run: targeted `AIClientTests` as above
Expected: PASS — 500 then 200 succeeds with 2 requests; 500 then 500 throws with 2 requests.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Services/AIClient.swift apps/novelsTests/AIClientTests.swift
git commit -m "fix(feat-018): per-chunk bounded retry 2 attempts stable requestId"
```

---

### Task 2: AIReadingService parallel join verification (no logic change)

**Files:**
- Modify: `apps/novels/Services/AIReadingService.swift:100-182` (only if broken)
- Test: `apps/novelsTests/AIReadingServiceTests.swift`

**Interfaces:**
- Consumes: `AIClient.complete` from Task 1 (2 attempts per chunk).
- Produces: `processedContent(...)` / `reprocess(...)` — parallel chunks, ordered `"\n"` join, fail-fast, cache save once.

- [ ] **Step 1: Write the failing test (reverse-delay ordering + single-chunk retry)**

```swift
func testParallelChunksJoinInOrderDespiteReverseDelays() async throws {
    // 5 chunks where chunk 4 delays 5ms and chunk 0 delays 50ms (reverse).
    // Expect joined == chunk0 + "\n" + chunk1 + ... in source order.
}
func testOneChunkRetryDoesNotDuplicateOtherChunks() async throws {
    // Chunk 1 fails once then succeeds; chunks 0,2 succeed first try.
    // Expect: chunk1 requestCount == 2, others == 1, joined correct.
}
```

- [ ] **Step 2: Run test to verify current state**

Run: targeted `AIReadingServiceTests`
Expected: PASS already (TaskGroup exists) — if FAIL, fix `buffer[index]` join before proceeding.

- [ ] **Step 3: Minimal fix only if needed (keep index-keyed buffer)**

```swift
var buffer = [String?](repeating: nil, count: total)
for try await (index, text) in group {
    buffer[index] = text
}
return buffer.compactMap { $0 }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
```

No partial cache: `throw` on any child error before `cache.upsert` (already the case — do not add partial save).

- [ ] **Step 4: Run test to verify it passes**

Run: targeted `AIReadingServiceTests`
Expected: PASS.

- [ ] **Step 5: Commit (only if changed; otherwise skip commit)**

```bash
git add apps/novels/Services/AIReadingService.swift apps/novelsTests/AIReadingServiceTests.swift
git commit -m "fix(feat-018): verify parallel ordered join fail-fast no partial cache"
```

---

### Task 3: Prefetch trigger source + back-from-Log zero-API

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift:70-101,263-312` (`load`, `triggerPrefetchIfEligible`)
- Modify: `apps/novels/Services/PrefetchManager.swift:51-60` (no signature change; caller gates)
- Test: `apps/novelsTests/PrefetchManagerTests.swift`, `apps/novelsTests/AIReadingViewModelTests.swift` (or Reader integration tests)

**Interfaces:**
- Consumes: `PrefetchManager.start(bookId:currentChapter:totalChapters:mode:settings:cache:aiService:repository:)` — unchanged.
- Produces: `func load(source: LoadSource)` where `enum LoadSource { case chapterChange, returnFromLog }`; only `.chapterChange` may start current-chapter AI + prefetch.

- [ ] **Step 1: Write the failing test (back-from-Log zero API)**

```swift
func testReturnFromLogMakesZeroCalls() async {
    // Seed: ch22 failed (no cache), prefetch terminal with errors.
    // Call vm.load(source: .returnFromLog).
    // Expect: aiService callCount == 0, prefetchManager.startCount == 0, prefetchStatus unchanged.
}
func testChapterChangeChecksCacheThenSequential() async {
    // Seed: range 23..25, 24 cached.
    // Call vm.load(source: .chapterChange) at ch22->23 path.
    // Expect: batchStatus checked, only misses processed sequentially, errors recorded + continued.
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: targeted prefetch + viewmodel suites
Expected: FAIL — today `load()` always fires `aiTask` + `triggerPrefetchIfEligible` (back-from-Log retries).

- [ ] **Step 3: Write minimal implementation (source gate)**

```swift
enum LoadSource { case chapterChange, returnFromLog }

func load(source: LoadSource = .chapterChange) async {
    // ... existing book/blocks loading (unchanged) ...
    isLoading = false
    if source == .returnFromLog {
        return // zero API: no aiTask, no triggerPrefetchIfEligible, keep prefetchStatus as-is
    }
    if aiMode != .none {
        aiTask?.cancel()
        aiTask = Task { await loadAIContent(isReprocess: false) }
    }
    if aiMode != .none, errorMessage == nil {
        await triggerPrefetchIfEligible()
    } else {
        await cancelPrefetch()
    }
}
// Call sites: goNext/goPrev/goToChapter/setAIMode/reprocess -> .chapterChange (default).
// ReaderView.onAppear after pop from Log -> pass .returnFromLog when chapterNumber + aiMode unchanged since disappear.
```

Track `lastVisibleChapter` + `lastVisibleMode` in `onDisappear`; in `ReaderView.onAppear` compare and pass the right source. Keep `PrefetchManager` sequential loop + `batchStatus` + `error-continue` exactly as today (no all-at-once fan-out).

- [ ] **Step 4: Run test to verify it passes**

Run: targeted prefetch + viewmodel suites
Expected: PASS — return-from-Log zero calls; chapter-change sequential with skip.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReaderViewModel.swift apps/novels/Features/Reading/ReaderView.swift apps/novels/Services/PrefetchManager.swift apps/novelsTests/PrefetchManagerTests.swift
git commit -m "fix(feat-018): prefetch only on chapter change, back-from-log zero API"
```

---

### Task 4: ReaderView header-only spinner (delete content indicators)

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderView.swift:47-64,122-146,213-315,317-336`
- Test: `apps/novelsTests/ReaderViewFixTests.swift` (assert identifiers)

**Interfaces:**
- Consumes: `viewModel.isAIProcessing: Bool` (current chapter only).
- Produces: header spinner `accessibilityIdentifier == "aiProgressHeader"`; content contains no `aiProgress`/`prefetchStatus` spinners.

- [ ] **Step 1: Write the failing test (header-only)**

```swift
func testHeaderSpinnerOnlyForCurrentChapter() {
    // isAIProcessing = true -> header contains aiProgressHeader; content has no aiProgress/prefetchStatus.
    // prefetchStatus.isRunning = true + isAIProcessing = false -> no spinner anywhere in Reading.
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: targeted `ReaderViewFixTests`
Expected: FAIL — today content has `aiProgress` + `prefetchStatus`.

- [ ] **Step 3: Write minimal implementation**

```swift
// 1. Delete aiSection spinner block and prefetchIndicator from content VStack (keep raw fallback + toast).
// 2. In topHeader second HStack, left of prev/next capsule:
if viewModel.isAIProcessing {
    ProgressView()
        .scaleEffect(0.7)
        .frame(width: 22, height: 28)
        .accessibilityIdentifier("aiProgressHeader")
        .accessibilityLabel("Đang xử lý")
}
// 3. Keep old "aiProgress" identifier removed; update any snapshot queries to aiProgressHeader.
```

Do not show prefetch progress/errors in Reading content at all (Log badge only).

- [ ] **Step 4: Run test to verify it passes**

Run: targeted `ReaderViewFixTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReaderView.swift apps/novelsTests/ReaderViewFixTests.swift
git commit -m "fix(feat-018): header-only rewrite spinner, remove content prefetch indicator"
```

---

### Task 5: ReaderBottomSheet delete loading indicator

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderBottomSheet.swift:103-149`
- Test: UI/snapshot or `ReaderViewFixTests` sheet section

**Interfaces:**
- Consumes: `viewModel.aiMode`, `viewModel.isAIProcessing` (only for disabling reprocess button).
- Produces: sheet with no `ProgressView`, no `aiProgress` identifier; reprocess disabled while processing.

- [ ] **Step 1: Write the failing test (no spinner in sheet)**

```swift
func testBottomSheetHasNoLoadingIndicator() {
    // viewModel.isAIProcessing = true -> sheet still has no aiProgress identifier.
    // reprocessButton disabled == true while processing.
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: targeted sheet/UI tests
Expected: FAIL — today sheet shows `aiProgress` when processing.

- [ ] **Step 3: Write minimal implementation (delete block)**

```swift
// Delete:
if viewModel.isAIProcessing {
    ProgressView()
        .tint(DesignTokens.accent)
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityIdentifier("aiProgress")
        .accessibilityLabel("Đang xử lý")
}
// Keep HStack picker + "Xử lý lại" (disabled when .none || isAIProcessing) + apiLogButton unchanged.
```

- [ ] **Step 4: Run test to verify it passes**

Run: targeted sheet/UI tests
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/novels/Features/Reading/ReaderBottomSheet.swift
git commit -m "fix(feat-018): remove bottom-sheet loading indicator"
```

---

### Task 6: Regression + full verification + docs link

**Files:**
- Modify: `features/feat-018.md` (Handoff evidence)
- Test: full suite via `./init.sh`

**Interfaces:**
- Consumes: Tasks 1-5.
- Produces: `features/feat-018.md` acceptance all checked + `./init.sh` PASS.

- [ ] **Step 1: Run quick gate**

Run: `./init.sh --quick`
Expected: PASS (format + lint + drift).

- [ ] **Step 2: Run affected suites**

Run: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests/AIClientTests -only-testing:novelsTests/AIReadingServiceTests -only-testing:novelsTests/PrefetchManagerTests -only-testing:novelsTests/ReaderViewFixTests`
Expected: PASS.

- [ ] **Step 3: Run full verification**

Run: `./init.sh`
Expected: PASS (format PASS, lint PASS, build PASS, test PASS, drift PASS).

- [ ] **Step 4: Update feat-018 Handoff + link plan**

```markdown
## Handoff (done)
- State: done — Tasks 1-6 done; `./init.sh` full PASS.
- Evidence: AIClient 2 attempts stable requestId, TaskGroup ordered join, load(source:) zero-API, header aiProgressHeader, sheet no spinner, targeted + full suites PASS.
- Plan: docs/plans/feat-018.md
```

Also ensure `features/feat-018.md` Plan section links `docs/plans/feat-018.md`.

- [ ] **Step 5: Commit**

```bash
git add features/feat-018.md docs/plans/feat-018.md feature_index.json
git commit -m "docs(feat-018): link plan + mark evidence"
```

---

## Self-Review

**1. Spec coverage:** ai-service Chunking/Retry → Tasks 1-2; ai-reading batch + manual retry → Tasks 1-2 + Task 5 reprocess; chapter-prefetch trigger/sequential/skip/back-zero-API/two reload paths → Task 3; screens Loading header-only + sheet-none + toast/raw + prefetch-silent → Tasks 4-5; CancellationError silent + shape/attempt logging → Task 1 + Task 3; tests + `./init.sh` → Task 6. No gaps.

**2. Placeholder scan:** No TBD/TODO/XXX; every code step has concrete file:line + code block + run command + expected output; no "similar to Task N" without repeat.

**3. Type consistency:** `LoadSource` defined once in Task 3 and reused; `aiProgressHeader` named once in Task 4 (old `aiProgress` removed in Tasks 4-5 consistently); `complete(prompt:chunk:context:)` signature unchanged across Tasks 1-2.

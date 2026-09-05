# Chapter Prefetch

> Prepares the next N chapters in the background for the active AI mode for instant reads.

## Flow (ordered steps actor / system)

1. Trigger: only when the chapter number truly changes (`goNext` / `goPrev` / `goToChapter` / References tap) or the mode changes / manual reprocess — after the new current chapter renders and is ready (book exists, chapter ready, mode not `none`). The trigger is debounced 200ms so rapid successive triggers collapse and only the latest window starts a batch. Returning from Log to the same chapter triggers zero API calls for the current chapter (no current-chapter reload); the previous terminal prefetch status is kept as-is, but background prefetch may resume when misses remain (overlap-preserving top-up, no new event types). If any readiness check fails, do nothing.
2. System reads N from persistent settings store (default 3, 0..1000 else 3), then applies the runtime window cap (default 10, logged as `appliedCap` on the existing `prefetch.batchCheck` event) and computes range next to `min(current + applied, total)`. The public range policy, per-chapter/global budgets, and timeouts are unchanged. Empty → done (at the book end the message names the remaining tail, e.g. "còn 2 chương cuối", instead of a generic done).
3. System batch-checks processed chapter cache for range and mode in ~200-id chunks accumulated into one set. All cached → zero service calls, finish as done. Otherwise list only the missing chapters. A cache query failure keeps the prior state and logs (never treated as miss-all, never mass-refetches).
4. System processes each missing chapter in order, one chapter batch at a time (never all N at once): each chapter runs its own parallel chunk batch (see `ai-service.md` Chunking), then joins and saves before moving to the next chapter. Update progress after each.
5. Per-chapter error → log, record once in `errors[]`, skip and continue with the next missing chapter. In-batch retry is bounded to at most 1 per chunk attempt (enforced by the per-chunk attempt loop in the AI client; the manager never re-queues a failed chapter inside one batch). A failed prefetch chapter is retried later through exactly two paths: (a) moving to the next chapter re-checks the new window automatically with failed chapters attempted first (failed-first, logged as `retry-enqueue` detail on the existing `prefetch.batchCheck` event), or (b) outside the window the actor opens that chapter and taps "Xử lý lại" manually. Same book+mode with non-empty window overlap keeps the running batch (generation bump + full cancel only on book/mode change or empty overlap): totals are updated and only the new-tail misses are appended (logged as `overlapKept`/`topUpAdded` detail on the existing `prefetch.batchCheck` event). At end, mark not running.

## Rules (business rules, link to business-rules.md)

- Runs only when mode not `none` and chapter is ready ([business-rules.md](../business-rules.md) BR-08).
- Default N is 3. Only 0..1000 is valid, else use 3. N=0 disables prefetch (empty range → done). Skip cached items ([business-rules.md](../business-rules.md) BR-08).
- Triggers only on real chapter or mode change; returning from Log to the same chapter makes zero calls ([business-rules.md](../business-rules.md) BR-08, [flows.md](../flows.md) §6).
- Cancel on chapter or mode change ([business-rules.md](../business-rules.md) BR-08, [flows.md](../flows.md) §6).
- Cache key is `bookId + chapterNumber + mode` ([business-rules.md](../business-rules.md) BR-07).

## States

- **Prefetch Status:** idle → checking cache → processing sequentially → done. Any stage → cancelled on chapter or mode change ([domain-model.md](../domain-model.md) Prefetch Status)
- Progress: isRunning, currentBookId, totalChapters, processedChapters, message, errors.

## Cases

| Case | Result |
|------|--------|
| Mode `none` | No prefetch |
| Chapter still loading | Wait, do not start |
| All N chapters cached | Done with zero work |
| N = 0 | No prefetch (empty range → done) |
| N invalid (1001, -1, "abc") | Use 3 |
| N huge (e.g. 1000) | Bounded by the runtime cap (default 10), logged as `appliedCap` |
| Cache query fails mid-batch | Keep prior state, log, no mass refetch |
| Window reaches the book end | Terminal message names the remaining chapters |
| Service fails for one chapter | Record error, skip, continue batch |
| User changes chapter/mode mid-run | Cancel + restart on book/mode change or far jump; same-window moves top-up the running batch |
| Back from Log to same chapter | Zero API calls for the current chapter, keep previous status; background prefetch may resume on misses |
| Failed chapter outside window | Actor opens it and taps "Xử lý lại" manually |
| Book deleted mid-run | Cancel |

## Acceptance

- [ ] When mode is `rewrite` and the chapter is ready after a real chapter change, the next N uncached chapters are processed one chapter batch at a time.
- [ ] Cached chapters are skipped without service calls.
- [ ] Progress shows total, processed, and errors without stopping the batch.
- [ ] Changing chapter or mode cancels current prefetch and starts a new one when eligible.
- [ ] Returning from Log to the same chapter makes zero calls.
- [ ] Mode `none` or not-ready chapter runs no prefetch.

## Links

- Domain: [domain-model.md](../domain-model.md) (PrefetchStatus, ProcessedChapter, AI Mode) — `PrefetchStatus.currentBookId` / `ProcessedChapter.bookId` is slug
- Flows: [flows.md](../flows.md) §6 Prefetch Background
- Integrations: [integrations.md](../integrations.md) §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-07, BR-08
- Contracts: [ai-service](../../contracts/ai-service.md), [local-data](../../contracts/local-data.md) (SQLite + `Task`/`actor`); Decisions: [book-identity](../../decisions/book-identity.md), [local-persistence](../../decisions/local-persistence.md)

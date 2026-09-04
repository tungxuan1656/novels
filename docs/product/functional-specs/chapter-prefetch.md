# Chapter Prefetch

> Prepares the next N chapters in the background for the active AI mode for instant reads.

## Flow (ordered steps actor / system)

1. Trigger: only when the chapter number truly changes (`goNext` / `goPrev` / `goToChapter` / References tap) or the mode changes / manual reprocess — after the new current chapter renders and is ready (book exists, chapter ready, mode not `none`). Returning from Log to the same chapter triggers zero API calls (no current-chapter reload, no prefetch retry); the previous terminal prefetch status is kept as-is. If any readiness check fails, do nothing.
2. System reads N from persistent settings store (default 3, 0..1000 else 3), computes range next to `min(current + N, total)`. Empty → done.
3. System batch-checks processed chapter cache for range and mode. All cached → zero service calls, finish as done. Otherwise list only the missing chapters.
4. System processes each missing chapter in order, one chapter batch at a time (never all N at once): each chapter runs its own parallel chunk batch (see `ai-service.md` Chunking), then joins and saves before moving to the next chapter. Update progress after each.
5. Per-chapter error → log, record in `errors[]`, skip and continue with the next missing chapter. A failed prefetch chapter is retried later through exactly two paths: (a) moving to the next chapter re-checks the new window automatically, or (b) outside the window the actor opens that chapter and taps "Xử lý lại" manually. At end, mark not running.

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
| Service fails for one chapter | Record error, skip, continue batch |
| User changes chapter/mode mid-run | Cancel current, start new if eligible |
| Back from Log to same chapter | Zero API calls, keep previous status |
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

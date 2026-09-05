# Chapter Prefetch

> Prepares the next N chapters in the background for the active AI mode for instant reads.

## Flow (ordered steps actor / system)

1. Trigger: only when the chapter number truly changes (`goNext` / `goPrev` / `goToChapter` / References tap) or the mode changes / manual reprocess — after the new current chapter renders and is ready (book exists, chapter ready, mode not `none`). The trigger calls start synchronously; rapid successive navigations are absorbed by the durable queue with no debounce and no restart. Returning from Log to the same chapter triggers zero API calls for the current chapter (no current-chapter reload); the previous terminal prefetch status is kept as-is, but the background queue resumes when misses remain (no new event types). If any readiness check fails, do nothing.
2. System reads N from persistent settings store (default 3, 0..1000 else 3), honors it as-is with no runtime cap, logs the single consumed N on the existing `prefetch.batchCheck` event, and computes range next to `min(current + N, total)`. The public range policy, per-chapter/global budgets, and timeouts are unchanged. Empty → done (at the book end the message names the remaining tail, e.g. "còn 2 chương cuối", instead of a generic done).
3. System batch-checks processed chapter cache for range and mode in ~200-id chunks accumulated into one set. All cached → zero service calls, finish as done. Otherwise list only the missing chapters. A cache query failure keeps the prior state and logs (never treated as miss-all, never mass-refetches).
4. System processes the queue sequentially in FIFO order, one chapter at a time (never all N at once): each chapter runs its own parallel chunk batch (see `ai-service.md` Chunking), then joins and saves before moving to the next queued chapter. Update progress after each.
5. The engine is a durable FIFO queue (`pending: [Int]` + `inFlight` + `attempts`) with a single sequential worker. On start with the same book and mode as the running task, the queue is never cancelled: `ensureWindow` keeps the overlap (`pending` ∩ window) in order and appends only the new-tail misses, so steady reading issues about one tail fetch per next chapter. Cancel happens only on book change, mode change (including to `none`), empty window at the book end, book deletion, or explicit cancel. Per-chapter error → log, record once in `errors[]`, and requeue at the tail at most once (`attempts <= 1`); a chapter still failing after one retry is logged and dropped, with no failed-first reorder, and is picked up later only when a later window miss check lists it again (or the actor opens it and taps "Xử lý lại" manually). Returning from Log to the same chapter and mode makes zero API calls for the current chapter and resumes the background queue when misses remain. At end, mark not running. Example: N=20 at chapter 450 issues 451-470 once; navigating to 451 keeps the running task and appends only 471.

## Rules (business rules, link to business-rules.md)

- Runs only when mode not `none` and chapter is ready ([business-rules.md](../business-rules.md) BR-08).
- Default N is 3. Only 0..1000 is valid, else use 3. N=0 disables prefetch (empty range → done). N is honored as-is with no runtime cap; large N is paced by the sequential worker plus the per-chapter/global budgets. Skip cached items ([business-rules.md](../business-rules.md) BR-08).
- Triggers only on real chapter or mode change; returning from Log to the same chapter makes zero calls for the current chapter and resumes the queue on misses ([business-rules.md](../business-rules.md) BR-08, [flows.md](../flows.md) §6).
- Same book and mode never cancels on navigate; cancel only on book change, mode change (including to `none`), empty window, book deletion, or explicit cancel ([business-rules.md](../business-rules.md) BR-08, [flows.md](../flows.md) §6).
- Cache key is `bookId + chapterNumber + mode` ([business-rules.md](../business-rules.md) BR-07).

## States

- **Prefetch Status:** idle → checking cache → processing sequentially → done. Any stage → cancelled only on book change, mode change (including to `none`), book deletion, or explicit cancel; same-book+mode navigate keeps the running queue ([domain-model.md](../domain-model.md) Prefetch Status)
- Progress: isRunning, currentBookId, totalChapters, processedChapters, message, errors.

## Cases

| Case | Result |
|------|--------|
| Mode `none` | No prefetch |
| Chapter still loading | Wait, do not start |
| All N chapters cached | Done with zero work |
| N = 0 | No prefetch (empty range → done) |
| N invalid (1001, -1, "abc") | Use 3 |
| N huge (e.g. 1000) | Honored as-is with no runtime cap, paced by the sequential worker plus per-chapter/global budgets; `prefetch.batchCheck` logs the single consumed N |
| Cache query fails mid-batch | Keep prior state, log, no mass refetch |
| Window reaches the book end | Terminal message names the remaining chapters |
| Service fails for one chapter | Record error, requeue at tail at most once, then log and drop; later miss check picks it up with no reorder |
| User changes chapter/mode mid-run | Same book and mode keeps the running queue and appends only new-tail misses; book change, mode change (including to `none`), or book deletion cancels |
| Back from Log to same chapter | Zero API calls for the current chapter, keep previous status; background queue resumes when misses remain |
| Failed chapter outside window | Actor opens it and taps "Xử lý lại" manually |
| Book deleted mid-run | Cancel |

## Acceptance

- [ ] When mode is `rewrite` and the chapter is ready after a real chapter change, the next N uncached chapters are queued and processed one chapter at a time in FIFO order.
- [ ] Cached chapters are skipped without service calls.
- [ ] Progress shows total, processed, and errors without stopping the queue.
- [ ] Changing chapter within the same book and mode keeps the running queue and appends only new-tail misses; book change, mode change, or deletion cancels and starts a new queue when eligible.
- [ ] Returning from Log to the same chapter makes zero calls for the current chapter and resumes the queue when misses remain.
- [ ] Mode `none` or not-ready chapter runs no prefetch.

## Links

- Domain: [domain-model.md](../domain-model.md) (PrefetchStatus, ProcessedChapter, AI Mode) — `PrefetchStatus.currentBookId` / `ProcessedChapter.bookId` is slug
- Flows: [flows.md](../flows.md) §6 Prefetch Background
- Integrations: [integrations.md](../integrations.md) §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-07, BR-08
- Contracts: [ai-service](../../contracts/ai-service.md), [local-data](../../contracts/local-data.md) (SQLite + `Task`/`actor`); Decisions: [book-identity](../../decisions/book-identity.md), [local-persistence](../../decisions/local-persistence.md)

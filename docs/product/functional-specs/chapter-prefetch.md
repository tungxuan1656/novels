# Chapter Prefetch

> Prepares the next N chapters in the background for the active AI mode for instant reads.

## Flow (ordered steps actor / system)

1. Trigger: after current chapter renders, system checks: book exists, chapter ready, mode not `none`. If any fails, do nothing.
2. System reads N from persistent settings store (default 3, 1..10 else 3), computes range next to `min(current + N, total)`. Empty → done.
3. System batch-checks processed chapter cache for range and mode; skips cached.
4. System processes each missing chapter in order via AI reading path (read raw → call AI service → save). Update progress after each.
5. Per-chapter error → log and continue. If all cached, finish with no work; at end mark not running.

## Rules (business rules, link to business-rules.md)

- Runs only when mode not `none` and chapter is ready ([business-rules.md](../business-rules.md) BR-08).
- Default N=3; only 1..10 valid, else 3; cached items skipped ([business-rules.md](../business-rules.md) BR-08).
- Cancel on chapter or mode change ([business-rules.md](../business-rules.md) BR-08, [flows.md](../flows.md) §6).
- Cache key is `bookId + chapterNumber + mode` ([business-rules.md](../business-rules.md) BR-07).

## States

- **Prefetch Status:** idle → checking cache → processing sequentially → done; any stage → cancelled on chapter or mode change ([domain-model.md](../domain-model.md) Prefetch Status)
- Progress: isRunning, currentBookId, totalChapters, processedChapters, message, errors.

## Cases

| Case | Result |
|------|--------|
| Mode `none` | No prefetch |
| Chapter still loading | Wait, do not start |
| All N chapters cached | Done with zero work |
| N invalid (0, 99, "abc") | Use 3 |
| Service fails for one chapter | Record error, continue |
| User changes chapter/mode mid-run | Cancel current, start new if eligible |
| Book deleted mid-run | Cancel |

## Acceptance

- [ ] When mode is translate/summary and chapter is ready, the next N uncached chapters are processed sequentially.
- [ ] Cached chapters are skipped without service calls.
- [ ] Progress shows total, processed, and errors without stopping the batch.
- [ ] Changing chapter or mode cancels current prefetch and starts a new one when eligible.
- [ ] Mode `none` or not-ready chapter runs no prefetch.

## Links

- Domain: [domain-model.md](../domain-model.md) (PrefetchStatus, ProcessedChapter, AI Mode)
- Flows: [flows.md](../flows.md) §6 Prefetch Background
- Integrations: [integrations.md](../integrations.md) §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-07, BR-08
- Tech counterpart: [chapter-prefetch.md](./chapter-prefetch.md) — tech shapes colocated in this functional spec

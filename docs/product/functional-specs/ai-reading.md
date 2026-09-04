# AI Reading

> Offers two modes per chapter — original ("Không") and rewrite ("Rewrite") — with cache-first reuse and on-demand AI processing based on user-configured Prompt.

## Flow (ordered steps actor / system)

1. Actor opens a chapter. System checks AI mode. If mode is `none` ("Không"), show raw text parsed from HTML in file storage and render with SwiftUI.Text. If mode is `rewrite` ("Rewrite"), check processed chapter cache for `bookId + chapterNumber + "rewrite"`.
2. Cache hit → render cached text with SwiftUI.Text, no service call.
3. Cache miss → split raw text into chunks (hint 1300), call one service request per chunk in parallel, wait for every chunk to succeed, join outputs in source order, clean, save the joined text as one cache entry, render with SwiftUI.Text. One failed chunk is retried once alone (max 2 attempts per chunk, every error kind, same `requestId`); the whole batch is never retried at once.
4. Actor switches mode → reload same chapter via cache-first path.
5. In Reading bottom sheet, "AI Rewrite" is shown with an inline picker ("Không", "Rewrite") and the Reprocess ("Xử lý lại") button placed right beside it in the same row.
6. One chunk still failing after its retry aborts the chapter → toast once, render raw fallback, no cache write. Actor retries manually via "Xử lý lại". Concurrent same-key requests are de-duplicated.

## Rules (business rules, link to business-rules.md)

- Cache is the only AI cache. Check cache before any call. Key is `bookId + chapterNumber + mode` ([business-rules.md](../business-rules.md) BR-07).
- AI Rewrite uses single `AI_PROMPT` system prompt configured in settings ([business-rules.md](../business-rules.md) BR-03, BR-04).
- Mode `none` bypasses cache and service. Bounded retry: max 2 attempts per failed chunk only. No cache on final failure ([integrations.md](../integrations.md) §2).

## States

- **AI Mode:** none ("Không") ↔ rewrite ("Rewrite") (switch anytime via inline picker, [domain-model.md](../domain-model.md) AI Mode)
- **Processing:** idle → checking cache → processing → cached/rendered | error

## Cases

| Case | Result |
|------|--------|
| Mode `none` | Render raw text (parsed from HTML) with SwiftUI.Text, no cache |
| Cache hit | Render instantly |
| Cache miss, success | Parallel chunk calls, join in order, save to cache and render |
| Empty response after retry | Toast once, render raw fallback, no cache |
| One chunk fails twice | Abort chapter, toast once, raw fallback, manual "Xử lý lại" |
| Concurrent same key | Single call, both share result |

## Acceptance

- [ ] Switching Không / Rewrite reloads same chapter with correct source.
- [ ] Cached chapter renders without calling the service.
- [ ] Uncached chapter calls one request per chunk in parallel with `AI_PROMPT`, retries only the failed chunk once, joins in order, saves text to cache, then renders with SwiftUI.Text.
- [ ] Sheet shows "AI Rewrite" inline picker with options "Không" and "Rewrite", with Reprocess button right beside it.
- [ ] Failed response after retry toasts once, renders raw fallback, and creates no entry.

## Links

- Domain: [domain-model.md](../domain-model.md) (ProcessedChapter, AI_PROMPT, AI Mode) — `ProcessedChapter.bookId` is slug `book.json.id`
- Flows: [flows.md](../flows.md) §5 AI Mode with Cache
- Integrations: [integrations.md](../integrations.md) §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-03, BR-04, BR-05, BR-06, BR-07
- Contracts: [ai-service](../../contracts/ai-service.md), [settings-schema](../../contracts/settings-schema.md), [local-data](../../contracts/local-data.md) (SQLite via `libsqlite3`); Decisions: [book-identity](../../decisions/book-identity.md), [local-persistence](../../decisions/local-persistence.md)

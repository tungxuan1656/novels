# AI Reading

> Offers three modes per chapter — original, translate, summary — with cache-first reuse and on-demand AI processing.

## Flow (ordered steps actor / system)

1. Actor opens a chapter. System checks AI mode: `none` → raw text parsed from HTML in file storage and rendered with SwiftUI.Text; `translate`/`summary` → check processed chapter cache for `bookId + chapterNumber + mode`.
2. Cache hit → render cached text with SwiftUI.Text, no service call.
3. Cache miss → read raw text, get prompt from AI actions in persistent settings store, send to AI processing service, clean, save to cache as text, render with SwiftUI.Text.
4. Actor switches mode → reload same chapter via cache-first path.
5. Failure or empty response → show error, no cache write. Concurrent same-key requests are de-duplicated.

## Rules (business rules, link to business-rules.md)

- Cache is the only AI cache; checked before any call, keyed by `bookId + chapterNumber + mode` ([business-rules.md](../business-rules.md) BR-07).
- Translate keeps honorifics, natural Vietnamese, names/places/terms, 100% meaning ([business-rules.md](../business-rules.md) BR-03, BR-04).
- Summary 50–60%, keeps plot order, key events, twists, key dialogue, removes only scenery and repeated emotion, never invents ([business-rules.md](../business-rules.md) BR-05, BR-06).
- Mode `none` bypasses cache/service. Up to 3 retries; no cache on final failure ([integrations.md](../integrations.md) §2).

## States

- **AI Mode:** none → translate → summary → none (switch anytime, [domain-model.md](../domain-model.md) AI Mode)
- **Processing:** idle → checking cache → processing → cached/rendered | error

## Cases

| Case | Result |
|------|--------|
| Mode `none` | Render raw text (parsed from HTML) with SwiftUI.Text, no cache |
| Cache hit | Render instantly |
| Cache miss, success | Save to cache and render |
| Empty response | Show "no response", no cache |
| Service fails after retries | Show error, no cache |
| Concurrent same key | Single call, both share result |

## Acceptance

- [ ] Switching none/translate/summary reloads same chapter with correct source.
- [ ] Cached chapter renders without calling the service.
- [ ] Uncached chapter calls service, saves text to cache, then renders with SwiftUI.Text.
- [ ] Empty or failed response shows error and creates no entry.
- [ ] Translate and summary follow honorific and faithful-summary rules.

## Links

- Domain: [domain-model.md](../domain-model.md) (ProcessedChapter, AIAction, AI Mode) — `ProcessedChapter.bookId` is slug `book.json.id`
- Flows: [flows.md](../flows.md) §5 AI Mode with Cache
- Integrations: [integrations.md](../integrations.md) §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-03, BR-04, BR-05, BR-06, BR-07
- Contracts: [ai-service](../../contracts/ai-service.md), [settings-schema](../../contracts/settings-schema.md), [local-data](../../contracts/local-data.md) (SQLite via `libsqlite3`); Decisions: [book-identity](../../decisions/book-identity.md), [local-persistence](../../decisions/local-persistence.md)

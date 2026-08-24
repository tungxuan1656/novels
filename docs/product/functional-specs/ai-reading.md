# AI Reading

> Offers three modes per chapter — original, translate, summary — with cache-first reuse and on-demand AI processing.

## Flow (ordered steps actor / system)

1. Actor opens a chapter. System checks AI mode: `none` → raw HTML from file storage; `translate`/`summary` → check processed chapter cache for `bookId + chapterNumber + mode`.
2. Cache hit → render cached HTML, no service call.
3. Cache miss → read raw text, get prompt from AI actions in persistent settings store, send to AI processing service, clean and convert to HTML, save to cache, render.
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
| Mode `none` | Render raw HTML, no cache |
| Cache hit | Render instantly |
| Cache miss, success | Save to cache and render |
| Empty response | Show "no response", no cache |
| Service fails after retries | Show error, no cache |
| Concurrent same key | Single call, both share result |

## Acceptance

- [ ] Switching none/translate/summary reloads same chapter with correct source.
- [ ] Cached chapter renders without calling the service.
- [ ] Uncached chapter calls service, saves HTML to cache, then renders.
- [ ] Empty or failed response shows error and creates no entry.
- [ ] Translate and summary follow honorific and faithful-summary rules.

## Links

- Domain: [domain-model.md](../domain-model.md) (ProcessedChapter, AIAction, AI Mode)
- Flows: [flows.md](../flows.md) §5 AI Mode with Cache
- Integrations: [integrations.md](../integrations.md) §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-03, BR-04, BR-05, BR-06, BR-07
- Tech counterpart: [docs/specs/ai-reading.md](../../specs/ai-reading.md)

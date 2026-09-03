# Business Rules — Novels

> **Scope owner:** Owns durable business rules. For entities see [domain-model.md](./domain-model.md), terms [glossary.md](./glossary.md), behavior [overview.md](./overview.md).

## Rules

| Rule ID | Rule | Applies to | Exception |
|---|---|---|---|
| BR-01 | Reading works offline after import. Opening and navigating chapters needs no network. | Reader, Library | Import needs network. Offline does not refresh catalog. |
| BR-02 | If import succeeds, delete the ZIP package. Never keep the ZIP after success. | Import | If any step fails, do not list a partial book. |
| BR-03 | AI processing uses the single `Prompt` setting configured by the user as system prompt (defaulting to natural Vietnamese translation with honorifics). The AI operation (translating, summarizing, rewriting) is dictated directly by this prompt. | AI `rewrite` | None. |
| BR-04 | Preserve content integrity according to the system prompt. Do not hallucinate or drop key information unless instructed by the prompt. | AI `rewrite` | None. |
| BR-05 | AI Rewrite mode checks cache for `bookId + chapterNumber + "rewrite"`. If cached, render immediately; if miss, process via AI service with `AI_PROMPT`. | AI `rewrite` | None. |
| BR-06 | Mode `none` bypasses cache and AI service. Render original HTML-parsed content. | Reader | None. |
| BR-07 | Use the processed chapter cache as the only AI cache. Before you call the AI service, check the cache. Save results by `bookId + chapterNumber + mode` (`none` or `rewrite`). | AI reading, Prefetch | Mode `none` bypasses the cache. |
| BR-08 | Prefetch the next N chapters in background. Use N=3 by default. Allow N=1..10. Run only when mode is not `none` and current chapter is ready. Skip cached chapters. Cancel on chapter or mode change. If N is missing or out of range, use 3. | Prefetch | None. |
| BR-09 | Save scroll position per book in the persistent settings store. Restore position only for the same book. Start a new chapter at top. If no saved offset exists, start at top. | Reader | None. |
| BR-10 | Delete removes the entire book folder from the local book repository. Delete also removes the library entry. | Library | Other books stay unchanged. Cached AI results for the deleted book become unreachable. |
| BR-11 | Persist typography in the persistent settings store. Apply typography to every render. | Reader | If values are missing, use defaults. |
| BR-12 | On launch, sanitize settings. If a value is invalid or missing, fall back to defaults. Defaults are catalog URL, AI endpoint, model `gpt-4o`, N=3, chunk 1300, default `AI_PROMPT`, and provider `openai`. Ignore unknown and legacy keys. Keep only current keys. | Persistent settings store (`UserDefaults` + `@Observable`) | If provider is unknown, use `openai`. If prompt is empty, use default prompt. |

## Notes

- Chapters use 1-based indexing. A valid package contains `book.json` at root and `chapters/chapter-N.html`.
- Chunk hint is 1300 characters. Short content uses one unit.

## Links

- Model: [domain-model.md](./domain-model.md) · Terms: [glossary.md](./glossary.md) · Overview: [overview.md](./overview.md)
- Specs: [book-import](./functional-specs/book-import.md) · [book-library](./functional-specs/book-library.md) · [book-reader](./functional-specs/book-reader.md) · [ai-reading](./functional-specs/ai-reading.md) · [chapter-prefetch](./functional-specs/chapter-prefetch.md) · [settings-management](./functional-specs/settings-management.md)

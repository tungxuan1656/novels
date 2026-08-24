# Business Rules — Novels

> **Scope owner:** Owns durable business rules. For entities see [domain-model.md](./domain-model.md), terms [glossary.md](./glossary.md), behavior [overview.md](./overview.md).

## Rules

| Rule ID | Rule | Applies to | Exception |
|---|---|---|---|
| BR-01 | Reading works offline after import. No network needed to open or navigate chapters. | Reader, Library | Import needs network; offline does not refresh catalog. |
| BR-02 | On successful import the ZIP package is deleted. ZIP never remains after success. | Import | If any step fails, do not treat a partial book as valid. |
| BR-03 | Translate keeps all honorifics unchanged (ta, nguoi, han, nang, huynh, de, etc.). Never map ta→em/anh or nguoi→ban. | AI `translate` | None — always enforce. |
| BR-04 | Translate replaces Sino-Vietnamese syntax with natural Vietnamese. Keep 100% meaning, names, places, terms. Do not add or cut content. | AI `translate` | None. |
| BR-05 | Summary cuts length to 50–60% by removing only long scenery, repeated emotion, and non-plot background. | AI `summary` | If chapter is very short, return shortest faithful summary. |
| BR-06 | Summary keeps plot order, key events, twists, and key dialogue (may shorten but keep intent). Never invent content. | AI `summary` | None. |
| BR-07 | Processed chapter cache is the only AI cache. Check it before calling the AI processing service; save by `bookId + chapterNumber + mode`. | AI reading, Prefetch | Mode `none` bypasses cache. |
| BR-08 | Prefetch next N chapters in background. Default N=3, allowed 1..10. Runs only when mode != `none` and current chapter is ready. | Prefetch | If N missing or out of range, use 3. Skip cached chapters. Cancel on chapter or mode change. |
| BR-09 | Scroll position is saved per book in the persistent settings store and restored only for the same book. New chapter starts at top. | Reader | If no saved offset, start at top. |
| BR-10 | Delete removes the whole book folder from the local book repository and removes the entry from the library. | Library | Other books unaffected. Cached AI results for that book become unreachable. |
| BR-11 | Typography (font, size, line height, spacing) persists in the persistent settings store and applies to every render. | Reader | Missing values use defaults. |
| BR-12 | Settings sanitize on launch: invalid or missing values fall back to defaults (catalog URL, AI endpoint, model `gpt-4o`, N=3, chunk 1300, provider `openai`). Legacy keys migrate. | Persistent settings store | Unknown provider → `openai`. Invalid action list → `translate` + `summary`. |

## Notes

- Chapters are 1-based. Valid package: `book.json` at root and `chapters/chapter-N.html`.
- Chunk hint is 1300 characters; short content is sent as one unit.

## Links

- Model: [domain-model.md](./domain-model.md) · Terms: [glossary.md](./glossary.md) · Overview: [overview.md](./overview.md)
- Specs: [book-import](./functional-specs/book-import.md) · [book-library](./functional-specs/book-library.md) · [book-reader](./functional-specs/book-reader.md) · [ai-reading](./functional-specs/ai-reading.md) · [chapter-prefetch](./functional-specs/chapter-prefetch.md) · [settings-management](./functional-specs/settings-management.md)

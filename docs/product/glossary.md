# Glossary — Novels

> **Scope owner:** This file owns term definitions. For entities and invariants see [domain-model.md](./domain-model.md). For behavior see [overview.md](./overview.md). For rules see [business-rules.md](./business-rules.md).

| Term | Definition |
|---|---|
| **Book** | A novel stored in the local book repository. It holds `id`, `name`, `author`, and an ordered list of chapter references. |
| **Chapter** | One readable unit of a Book. Identify it by `bookId` and 1-based `number`. Content is HTML. |
| **Reference** | The ordered chapter index of a Book. It lists titles and determines navigation bounds. |
| **Book Metadata** | Descriptive fields of a Book: slug, chapter count, status, synopsis, and last update time. |
| **Exported Book** | A remote catalog entry that points to a downloadable ZIP via `exportUrl`. |
| **Book Package (ZIP)** | The import archive. It must contain `book.json` and `chapters/chapter-N.html`. |
| **Local Book Repository** | The on-device folder that stores imported books. Each book lives in its own subfolder. |
| **Processed Chapter** | A cached AI result for one chapter and one mode. Key is `bookId + chapterNumber + mode`. |
| **Processed Chapter Cache** | The persistent cache for AI results. Check it before calling the AI provider. |
| **AI Action** | A configurable AI operation with `key`, `name`, and `prompt`. Defaults: `translate` and `summary`. |
| **AI Mode** | The active reading mode: `none` (original), `translate`, or `summary`. |
| **Reading Session** | Persisted position: `bookId`, `onScreen` flag, and `scrollOffset`. It drives launch routing. |
| **Typography Setting** | Reader appearance: `font`, `fontSize`, `lineHeight`, and `letterSpacing`. |
| **Prefetch Status** | Runtime progress of background prefetch: running flag, totals, processed count, and errors. |
| **Persistent Settings Store** | The key-value store for settings, sessions, and typography. It restores state on launch. |
| **Library** | The home view that lists all books from the local book repository. |
| **Reader** | The view that parses HTML → text spans and renders with SwiftUI.Text, handles navigation, and saves scroll offset. |
| **Import** | The flow: fetch catalog → download ZIP → extract → delete ZIP → list in library. |

## Links

- Model: [domain-model.md](./domain-model.md)
- Rules: [business-rules.md](./business-rules.md)
- Overview: [overview.md](./overview.md)

# Domain Model — Novels

> **Scope owner:** This file owns entities, relationships, invariants, and state machines. For product behavior see [overview.md](./overview.md). For business rules see [business-rules.md](./business-rules.md). For term definitions see [glossary.md](./glossary.md).

## 1. Relationship Map

```
ExportedBook 1──1 BookMeta
Book 1──* Chapter
Book 1──* Reference (ordered chapter index)
Book 1──* ProcessedChapter
Book 1──* ReadingSession (one active per book)
AIAction *──* ProcessedChapter (via mode key)
ReadingSession *──1 Book
ReadingSession *──1 Chapter (current)
TypographySetting 1──* ReadingSession (render)
PrefetchStatus 1──* ProcessedChapter (background fill)
```

Flow: Import → Local Book Repository → Reader → Processed Chapter Cache.

## 2. State Machines

### AI Mode

```
none ──► rewrite
  ▲          │
  └──────────┘
```

- `none` ("Không"): Render original raw text. `rewrite` ("Rewrite"): Check cache first; on miss process using `AI_PROMPT` setting and cache.
- Switch mode at any time in the reading sheet.

### Reading Position

```
closed ──► open (restore offset) ──► navigate ──► save offset ──► closed
```

- Track `bookId`, 1-based `chapterNumber`, and `offset`. Clamp to `1 .. total`.

### Prefetch Status

```
idle ──► checking cache ──► processing sequentially ──► done
              │                        │
              └────► cancelled ◄───────┘
```

- Run only when mode is not `none`. Cancel on chapter or mode change.

## 3. Entities

| Entity | Description | Key Fields | Owner |
|---|---|---|---|
| **Book** | Downloaded novel in local book repository | `id`, `name`, `author`, `count`, `references[]` | Local repository |
| **Chapter** | Single readable unit of a Book | `bookId`, `number` (1-based), `htmlContent` | Local repository |
| **Reference** | Ordered pointer to a Chapter | `index`, `title` | Book |
| **ExportedBook** | Remote catalog entry for import | `id`, `bookId`, `exportUrl`, `fileSize`, `exportFormat`, `exportedAt`, `book` | Remote catalog |
| **BookMeta** | Descriptive metadata of an ExportedBook | `id`, `name`, `slug`, `author`, `chapterCount`, `status`, `synopsis`, `lastUpdated` | Remote catalog |
| **ProcessedChapter** | Cached AI result for one chapter and mode | `bookId`, `chapterNumber`, `mode`, `content`, `contentHash`, `createdAt`, `updatedAt` | Processed chapter cache |
| **AI_PROMPT** | Configurable AI system prompt | `prompt` | Persistent settings store |
| **ReadingSession** | Persisted reading position | `bookId`, `onScreen`, `offset` | Persistent settings store |
| **TypographySetting** | Reader appearance | `font`, `fontSize`, `lineHeight`, `letterSpacing` | Persistent settings store |
| **PrefetchStatus** | Background prefetch progress (runtime only) | `isRunning`, `currentBookId`, `totalChapters`, `processedChapters`, `message`, `errors[]` | Runtime |

## 4. Invariants

- Chapter indexing and package structure follow [business-rules.md](./business-rules.md) Notes.
- ZIP lifecycle follows [business-rules.md](./business-rules.md) BR-02.
- Cache key follows [business-rules.md](./business-rules.md) BR-07.
- Prefetch N and trigger follow [business-rules.md](./business-rules.md) BR-08.
- Treat `AIMode.rawValue` (`none` / `rewrite`) as `ProcessedChapter.mode`.
- Offset storage follows [business-rules.md](./business-rules.md) BR-09.
- Keep AI cache separate from files and settings. See [business-rules.md](./business-rules.md) BR-07.

## Links

- Terms: [glossary.md](./glossary.md)
- Rules: [business-rules.md](./business-rules.md)
- Behavior: [overview.md](./overview.md)
- Specs: [functional-specs](./functional-specs/) (`book-import`, `book-library`, `book-reader`, `ai-reading`, `chapter-prefetch`, `settings-management`) — tech shapes in `./functional-specs/*`

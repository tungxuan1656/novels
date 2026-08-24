# Domain Model — rn-read-books

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
none ──► translate ──► summary ──┐
  ▲          │            │       │
  └──────────┴────────────┘───────┘
```

- `none`: Render original. `translate`/`summary`: Check cache first; on miss process and cache.
- Switch mode at any time.

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
| **AIAction** | Configurable AI transformation | `key`, `name`, `prompt` | Persistent settings store |
| **ReadingSession** | Persisted reading position | `bookId`, `onScreen`, `offset` | Persistent settings store |
| **TypographySetting** | Reader appearance | `font`, `fontSize`, `lineHeight`, `letterSpacing` | Persistent settings store |
| **PrefetchStatus** | Background prefetch progress (runtime only) | `isRunning`, `currentBookId`, `totalChapters`, `processedChapters`, `message`, `errors[]` | Runtime |

## 4. Invariants

- Use 1-based chapter indexing. First chapter is `1`. Never use `0`.
- A valid ZIP contains `book.json` at root and `chapters/chapter-N.html` for `N = 1 .. count`.
- Delete ZIP after successful import.
- Enforce unique `bookId + chapterNumber + mode`. Upsert on conflict.
- Prefetch N follows BR-08: default 3, allowed 1..10; ignore invalid values. See [business-rules.md](./business-rules.md) BR-08.
- Prefetch never runs when mode is `none`.
- Treat `AIAction.key` as `ProcessedChapter.mode`.
- Store offset per session; restore only for same `bookId`.
- Keep AI cache separate from files and settings.

## Links

- Terms: [glossary.md](./glossary.md)
- Rules: [business-rules.md](./business-rules.md)
- Behavior: [overview.md](./overview.md)
- Specs: [functional-specs](./functional-specs/) (`book-import`, `book-library`, `book-reader`, `ai-reading`, `chapter-prefetch`, `settings-management`) — tech shapes in `../specs/*`

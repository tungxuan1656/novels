# Book Reader

> Parses chapter HTML from file storage to one optional title plus one plain body string, renders with SwiftUI.Text, handles navigation, and restores position and typography.

## Flow (ordered steps actor / system)

1. Actor opens a locally installed book. System marks the session on-screen, reconciles its per-book checkpoint with private iCloud when available, then opens the saved chapter or chapter 1. System reads `chapters/chapter-N.html`, parses the first heading as an optional untranslated title, and displays it at body size + 8 bold. Mid-chapter headings merge into plain body text chunks. The reader restores the same device's offset when available or the saved paragraph in a matching rendition. With no compatible position, it starts at the chapter top. Pipeline: [local-data.md](../../contracts/local-data.md).
2. Actor navigates. Next and Previous step one chapter within 1..total. Buttons are disabled at ends. Index jump moves directly to the selected chapter.
3. System saves the local offset and portable chapter/paragraph position while reading. Pending changes can sync when connectivity returns.
4. Actor closes the reader. System marks it off-screen and keeps the position for resume. A cloud update never moves a reader that is already open.
5. Missing file → "Failed to load chapter."

## Rules (business rules, link to business-rules.md)

- Raw and cached reading is offline after import. Uncached AI and explicit Google sentence lookup need network ([business-rules.md](../business-rules.md) BR-01).
- Chapters are 1-based and clamped to 1..total ([domain-model.md](../domain-model.md) Invariants).
- Position is restored only for the same book ([business-rules.md](../business-rules.md) BR-09). Import the same package on both devices and use the same Apple Account for iCloud resume. Book content, AI cache, and settings stay local. See [reading progress sync](../../decisions/reading-progress-sync.md).
- Song ngữ renders typed VI/EN pairs with switchable primary/secondary styling; an English paragraph opens sentence learning. Speech and Google lookup follow [bilingual-learning](bilingual-learning.md).
- Typography persists and applies to every render. Missing values use defaults ([business-rules.md](../business-rules.md) BR-11).
- Opening the diagnostic Log covers Reading without cancelling current-chapter AI or prefetch. Returning to the same chapter keeps that work/result without another current-chapter request. Actual Reader exit and chapter/mode changes retain their cancellation rules.

## States

- **Reading position:** closed → open (restore chapter/offset/paragraph) → navigate → save position → closed ([domain-model.md](../domain-model.md) Reading Position)
- **Session flag:** on-screen true while reading, false in library (drives launch routing).
- **Chapter load:** loading → rendered | error

## Cases

| Case | Result |
|------|--------|
| Open different book | Loads only that book's position |
| Synced chapter absent in local package | Keep the local position or default |
| Synced rendition differs | Start at the saved chapter's top |
| iCloud unavailable | Use the local checkpoint or session |
| Missing file | Show error, allow other navigation |
| Typography changed | Reader re-renders immediately |
| Scroll during load | Offset saved after render ready |

## Acceptance

- [ ] Reader parses HTML to one optional title plus one plain body string and renders the title (body + 8, bold) above native paragraph `Text` chunks using current typography, with no emphasis anywhere.
- [ ] Next and Previous move one chapter within bounds. Buttons are disabled at ends. Index jump works.
- [ ] Open the same installed book on iPhone and Mac to resume the latest synced chapter and paragraph in a matching rendition. New chapters start at top.
- [ ] Closing preserves position; opening another book does not reuse wrong offset.
- [ ] Missing content shows error without crash.

## Links

- Domain: [domain-model.md](../domain-model.md) (Book, Chapter, Reference, ReadingSession, TypographySetting) — `ReadingSession.bookId` uses the resolved `Book.id` slug
- Flows: [flows.md](../flows.md) §1 Startup and Resume, §4 Reading and Navigation
- Integrations: [integrations.md](../integrations.md) (none for raw reading)
- Rules: [business-rules.md](../business-rules.md) BR-01, BR-09, BR-11
- Contracts: [local-data](../../contracts/local-data.md) (SwiftUI.Text pipeline + `Application Support`); Decisions: [book-identity](../../decisions/book-identity.md), [local-persistence](../../decisions/local-persistence.md)

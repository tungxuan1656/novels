# Book Reader

> Renders chapter HTML from file storage, handles navigation, and restores position and typography.

## Flow (ordered steps actor / system)

1. Actor opens a book. System marks session on-screen, loads saved chapter or 1, reads `chapters/chapter-N.html` from file storage, renders with typography from persistent settings store, restores offset for same book (top if none; new chapters start at top).
2. Actor navigates: Next/Previous step one within 1..total (disabled at ends); scroll near bottom auto-advances, scroll far above top goes back; index jumps directly. Short lock prevents rapid jumps.
3. System saves offset per book while scrolling.
4. Actor closes reader. System marks not on-screen but keeps offset for resume.
5. Missing file → "Failed to load chapter."

## Rules (business rules, link to business-rules.md)

- Reading is offline after import; no network ([business-rules.md](../business-rules.md) BR-01).
- Chapters are 1-based and clamped to 1..total ([domain-model.md](../domain-model.md) Invariants).
- Offset is saved per book and restored only for the same book ([business-rules.md](../business-rules.md) BR-09).
- Typography persists and applies to every render; missing values use defaults ([business-rules.md](../business-rules.md) BR-11).

## States

- **Reading position:** closed → open (restore offset) → navigate → save offset → closed ([domain-model.md](../domain-model.md) Reading Position)
- **Session flag:** on-screen true while reading, false in library (drives launch routing).
- **Chapter load:** loading → rendered | error

## Cases

| Case | Result |
|------|--------|
| Open different book | Loads its own chapter and offset |
| Chapter out of bounds | Clamped to 1 or total |
| No saved offset | Starts at top |
| Missing file | Show error, allow other navigation |
| Typography changed | Reader re-renders immediately |
| Scroll during load | Offset saved after render ready |

## Acceptance

- [ ] Reader loads HTML from file storage and renders with current typography.
- [ ] Next/Previous move one chapter within bounds; disabled at ends; index jump works.
- [ ] Offset is saved per book and restored for same book; new chapter starts at top.
- [ ] Closing preserves position; opening another book does not reuse wrong offset.
- [ ] Missing content shows error without crash.

## Links

- Domain: [domain-model.md](../domain-model.md) (Book, Chapter, Reference, ReadingSession, TypographySetting) — `Book.id` / `ReadingSession.bookId` is slug `book.json.id`
- Flows: [flows.md](../flows.md) §1 Startup and Resume, §4 Reading and Navigation
- Integrations: [integrations.md](../integrations.md) (none for raw reading)
- Rules: [business-rules.md](../business-rules.md) BR-01, BR-09, BR-11
- Contracts: [local-data](../../contracts/local-data.md) (WKWebView + `Application Support`); Decisions: [book-identity](../../decisions/book-identity.md), [local-persistence](../../decisions/local-persistence.md)

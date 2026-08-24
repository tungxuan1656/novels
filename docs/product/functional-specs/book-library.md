# Book Library

> Lists all imported books from the local book repository and lets the user view details or delete a book.

## Flow (ordered steps actor / system)

1. Actor opens Library. System scans the local book repository in file storage, reads each `book.json`, and builds the list. Invalid folders are skipped.
2. System renders: with books → rows with name, author, chapter count, cover; empty → prompt to add via Add action.
3. Actor taps a row. System opens a details sheet with metadata (name, author, synopsis, status, last updated) and the ordered chapter index.
4. Actor swipes a row to delete: system shows confirm dialog; confirm → system removes the whole book folder from file storage and the library entry; success feedback shown; cancel → no change.
5. Delete failure → show "Cannot delete book", keep entry. No network needed.

## Rules (business rules, link to business-rules.md)

- Library works offline after import ([business-rules.md](../business-rules.md) BR-01).
- Delete removes the entire book folder; other books are unaffected ([business-rules.md](../business-rules.md) BR-10).
- After delete, processed results for that book become unreachable ([business-rules.md](../business-rules.md) BR-10).
- Chapter count equals number of references; indexing is 1-based ([domain-model.md](../domain-model.md) Invariants).

## States

- **Library view:** loading → populated | empty
- **Delete:** idle → confirming → deleting → done | failed
- Details sheet reflects current file content.

## Cases

| Case | Result |
|------|--------|
| Folder without `book.json` | Skipped, not shown |
| Cover missing | Row shows text only |
| Delete while book is open in reader | Folder removed; next navigation shows error |
| Delete fails (lock) | Show error, keep entry |
| Empty repository | Show prompt with Add action |
| New import while library is open | List refreshes |

## Acceptance

- [ ] Library shows every valid book with name, author, chapter count, and cover when present.
- [ ] Tap opens details sheet with metadata and chapter index.
- [ ] Swipe-to-delete asks for confirmation and, when confirmed, removes the folder and entry.
- [ ] Cancel leaves library unchanged.
- [ ] Empty state shows prompt to add.

## Links

- Domain: [domain-model.md](../domain-model.md) (Book, Reference, Chapter) — local identity is `Book.id` slug (`book.json.id`)
- Flows: [flows.md](../flows.md) §3 Library Browse and Manage
- Integrations: [integrations.md](../integrations.md) (no external call)
- Rules: [business-rules.md](../business-rules.md) BR-01, BR-10
- Contracts: [local-data](../../contracts/local-data.md), [book-package](../../contracts/book-package.md); Decisions: [book-identity](../../decisions/book-identity.md)

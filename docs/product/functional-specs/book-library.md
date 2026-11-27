# Book Library

> Lists all imported books from the local book repository and lets the user view details or delete a book.

## Flow (ordered steps actor / system)

1. On first load or refresh, system scans the local book repository outside UI execution. It reads each `book.json` and validates chapters. Invalid folders are skipped. Returning from Settings reuses the loaded list.
2. If books exist, show rows with name, author, and chapter count. Selecting a row opens Reader. If empty, show the Add Book prompt.
3. Swipe a row on iPhone or open its context menu on Mac for Info or Delete. Info shows title, author, and chapter count.
4. Delete asks for confirmation. If confirmed, remove the book folder and refresh the list. If cancelled, leave the book unchanged.
5. Delete failure → show "Cannot delete book", keep entry. No network needed.

## Rules (business rules, link to business-rules.md)

- Library works offline after import ([business-rules.md](../business-rules.md) BR-01).
- Import and confirmed deletion refresh the list. Pull-to-refresh rescans local storage; an unchanged navigation return does not.
- Delete removes the entire book folder. Other books stay unaffected ([business-rules.md](../business-rules.md) BR-10).
- After delete, processed results for that book become unreachable ([business-rules.md](../business-rules.md) BR-10).
- Indexing follows [domain-model.md](../domain-model.md) Invariants and [business-rules.md](../business-rules.md) Notes.

## States

- **Library view:** loading → populated | empty
- **Delete:** idle → confirming → deleting → done | failed
- Details sheet reflects current file content.

## Cases

| Case | Result |
|------|--------|
| Folder without `book.json` | Skipped, not shown |
| Delete while book is open in reader | Folder removed; next navigation shows error |
| Delete fails (lock) | Show error, keep entry |
| Empty repository | Show prompt with Add action |
| New import while library is open | List refreshes |

## Acceptance

- [ ] Library shows every valid book with name, author, and chapter count.
- [ ] Selecting a row opens Reader; Info is available in the book actions.
- [ ] Delete asks for confirmation and, when confirmed, removes the folder and entry.
- [ ] Cancel leaves library unchanged.
- [ ] Empty state shows prompt to add.

## Links

- Domain: [domain-model.md](../domain-model.md) (Book, Reference, Chapter) — local identity is the resolved `Book.id` slug
- Flows: [flows.md](../flows.md) §3 Library Browse and Manage
- Integrations: [integrations.md](../integrations.md) (no external call)
- Rules: [business-rules.md](../business-rules.md) BR-01, BR-10
- Contracts: [local-data](../../contracts/local-data.md), [book-package](../../contracts/book-package.md); Decisions: [book-identity](../../decisions/book-identity.md)

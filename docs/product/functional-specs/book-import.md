# Book Import

> Discovers books from the remote book catalog and imports the selected ZIP package into the local book repository for offline reading.

## Flow (ordered steps actor / system)

1. Actor opens Add Book. System reads catalog address from persistent settings store and requests the exported list from the remote book catalog.
2. System shows the catalog state. If items exist, show list with name, author, size, and synopsis. If empty, show "No books available". If failure, show "Cannot load catalog, try again" and allow pull to retry.
3. Actor selects a book. System ensures repository and temp folders exist in file storage, downloads ZIP to temp, extracts to local book repository, deletes ZIP, refreshes library.
4. Valid package has `book.json` at root and `chapters/chapter-N.html` for N = 1..count.
5. Any failure → show error, no partial entry, allow retry.

## Rules (business rules, link to business-rules.md)

- No authentication for listing or download ([business-rules.md](../business-rules.md) BR-01, [integrations.md](../integrations.md) §1).
- ZIP is deleted only after full success. Failed imports never create a valid book ([business-rules.md](../business-rules.md) BR-02).
- Package structure and 1-based indexing are fixed ([domain-model.md](../domain-model.md) Invariants).
- Listing is safe to retry. Re-import atomically replaces the same slug folder with the incoming package, without confirmation.
- Sort locally: default name A→Z; "Mới nhất" sorts descending by `book.lastUpdated`, falling back to `ExportedBook.updatedAt`.
- During download and extraction, block interaction with a simple spinner, not percentage progress. See [screen patterns](../../design/screens.md).
- Invalid packages show "Gói sách không hợp lệ, không thể nhập". Success shows "Đã nhập sách", then follows [navigation rules](../../design/navigation.md) to pop and refresh Library.

## States

- **Catalog fetch:** idle → loading → loaded | empty | error
- **Import:** idle → downloading → extracting → done | failed
- ZIP exists only while downloading or extracting.

## Cases

| Case | Result |
|------|--------|
| No network on catalog fetch | Show error, library unchanged |
| Catalog returns failure flag | Show its message or generic failure |
| ZIP missing `book.json` or chapters | Fail import, no entry added |
| Network lost during download | Fail import, no partial book |
| Same slug imported again, including updated content | Atomically replace the folder without confirmation or a duplicate entry |
| ZIP delete fails after success | Book remains listed |

## Acceptance

- [ ] Opening Add Book shows loading then list, empty, or error with retry.
- [ ] Selecting a book downloads, extracts to the local book repository, deletes the ZIP, and the book appears in the library.
- [ ] Invalid package or network failure shows error and creates no entry.
- [ ] Re-import replaces content without duplication.

## Links

- Domain: [domain-model.md](../domain-model.md) (Book, ExportedBook, BookMeta)
- Flows: [flows.md](../flows.md) §2 Discover and Import
- Integrations: [integrations.md](../integrations.md) §1 Remote Book Catalog
- Rules: [business-rules.md](../business-rules.md) BR-01, BR-02
- Contracts: [catalog-api](../../contracts/catalog-api.md), [book-package](../../contracts/book-package.md), [local-data](../../contracts/local-data.md); Decisions: [book-identity](../../decisions/book-identity.md), [local-persistence](../../decisions/local-persistence.md)

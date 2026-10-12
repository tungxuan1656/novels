# Title & Single Body String Reader

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md), [feat-006](task-ai-reading.md), [feat-007](task-chapter-prefetch.md)
- Required to integrate/release: none
- Previous ID: feat-028

## Scope and non-goals

Streamline HTML chapter parsing and rendering into an optional raw chapter title and a single plain body string, superseding the rich block and span machinery from [task-offline-reader](task-offline-reader.md):
- Simplified parser: `HtmlParser.parseChapter(html:) -> (title: String?, body: String)` extracts the first heading (if present) as the title and merges all remaining text into a single plain body string; mid-chapter headings merge directly into the body text.
- Removed legacy constructs: delete `TextSpan.swift` and `ReaderContentView.swift`, eliminating `TextBlock`, `TextSpan`, and inline font rendering logic.
- Reader and AI alignment: `ReaderView` renders raw chapter title (body font + 8, bold, never translated) followed by a single body `Text` element across both raw and AI modes; AI processing and prefetch operate directly on the single body string.
- Cache schema versioning: historical clear via SQLite `user_version` 1 to 2 clearing pre-migration cached entries (historical migration record; no new database migrations required).
- Documentation updates: align reader, flow, and AI specifications to title and single body string architecture.

Non-goals: No rich text formatting (bold/italics removed); no changes to newline paragraph separation (`\n\n`), whitespace collapsing, or AI chunk budgets (1,300 chars); no secondary cache migrations.

## Acceptance

- [x] `parseChapter` returns first-heading title (nil when absent) + plain body; heading-free bodies byte-identical to the old join output.
- [x] Raw and AI modes render title (body + 8, bold, never translated) + single body `Text`; no emphasis anywhere.
- [x] No `TextBlock`/`TextSpan`/`ReaderContentView`/`fontFor`/`joinedBodyText`/`firstHeadingText` remains in Swift sources.
- [x] AI input is the body string by construction; pre-migration entries never served (v2 clear).
- [x] Docs describe title + string (no spans language); `./init.sh` full PASS; Simulator walk recorded (owner-verified on Simulator 2026-09-07).

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/product/functional-specs/ai-reading.md](../docs/product/functional-specs/ai-reading.md)
- [docs/product/functional-specs/book-reader.md](../docs/product/functional-specs/book-reader.md)
- [docs/decisions/local-persistence.md](../docs/decisions/local-persistence.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [apps/novels/Domain/HtmlParser.swift](../apps/novels/Domain/HtmlParser.swift)
- [apps/novels/Features/Reading/ReaderView.swift](../apps/novels/Features/Reading/ReaderView.swift)
- [apps/novels/Features/Reading/ReaderViewModel.swift](../apps/novels/Features/Reading/ReaderViewModel.swift)
- [apps/novels/Persistence/ProcessedChapterCache.swift](../apps/novels/Persistence/ProcessedChapterCache.swift)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed full `./init.sh` PASS (format 0/57, lint 0, build PASS on iPhone 17 Pro iOS 26.5, drift check PASS 21/21). This was the then-current build-only policy, not a unit-test pass; focused tests were restored later in [verification alignment](task-verification-docs-alignment.md). Grep verified zero legacy span or block references in Swift sources and documentation. The project owner performed and verified the manual Simulator walk on 2026-09-07 across heading and heading-free chapters in both raw and Rewrite modes, confirming clean prefetch and rendering.
- Blockers: None.
- Next: HISTORICAL: Merge title and single body reader changes to main.

# App Shell + Home Library

- Status: done
- Owner: Tung Doan
- Required to start: [feat-001](task-persistence-foundation.md)
- Required to integrate/release: none
- Previous ID: feat-002

## Scope and non-goals

Establish `NavigationStack` startup routing and the offline Home Library shell with shared UI primitives:
- Startup restoration of session and settings without network; routing `onScreen ? Reading(bookId: slug) : Library` per navigation specs.
- Navigation router supporting Library (root), Reading, and References placeholder routes.
- Shared UI primitives: `LoadingView`, `ToastView`, and `BottomSheetView` using design system tokens.
- Offline Library view: scans `Application Support/novels/books/<slug>/`, lists valid books from `book.json`, renders empty state when no books exist.
- Book info sheet showing book details and chapter index; swipe-to-delete with confirmation alert, deleting whole book folder via the repository boundary.
- Vietnamese UI copy throughout; iPhone-only shell (`TARGETED_DEVICE_FAMILY = 1`).

Non-goals: No catalog import or ZIP downloads, no HTML text reader rendering, no settings editing screens, and no AI or prefetch processing.

## Acceptance

- [ ] Launch restores session and routes correctly; invalid `bookId` toasts and stays on Library.
- [ ] Library lists only folders with valid `book.json`; empty state shown when zero books.
- [ ] Info sheet shows `name`/`author`/`count`/`references`; delete confirms then removes folder and refreshes list.
- [ ] Loading/toast/bottom-sheet primitives work on Library; Vietnamese copy present.
- [ ] Back at root does not crash; Reading back clears `onScreen`.
- [ ] Reading shell sets/clears `onScreen` per `docs/design/navigation.md:49-50` (Home tap row → `onScreen=true`, Reading back → `onScreen=false`).

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/design/navigation.md](../docs/design/navigation.md)
- [docs/design/screens.md](../docs/design/screens.md)
- [docs/design/design-system.md](../docs/design/design-system.md)
- [docs/product/functional-specs/book-library.md](../docs/product/functional-specs/book-library.md)
- [apps/novels/App/](../apps/novels/App/)
- [apps/novels/Features/Library/](../apps/novels/Features/Library/)
- [apps/novels/SharedUI/](../apps/novels/SharedUI/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Tasks 1-5 implemented and Task 6 verification passed: `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` passed 40+ tests (ToastCenterTests 2, RouterTests 4, LibraryViewModelTests 5, ReadingShellTests 3, plus persistence test suites). `./init.sh` passed (format 0, lint 0, build PASS, test PASS). Historical UITests were later retired per `docs/decisions/verification.md`. Note on checklist status: The feature record was marked `done` historically with passing verification, but all six acceptance criteria checkboxes remained unchecked in the original record; preserved as unchecked pending owner confirmation.
- Blockers: No migration blocker. Historical `done` and six unsigned acceptance checks are preserved without manufacturing acceptance evidence; checklist reconciliation requires owner confirmation if this work is reopened.
- Next: HISTORICAL: feat-003 Catalog Import + ZIP Ingestion ready to activate.

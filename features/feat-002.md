# feat-002 — App Shell + Home Library

## Goal

Establish NavigationStack startup routing and offline Home Library shell with shared primitives so later import/reader/settings flows have a consistent Vietnamese UI container.

## Scope

- Startup restore of session/settings (no network) and routing `onScreen ? Reading(bookId: slug) : Library` per `docs/design/navigation.md`.
- `NavigationStack` with routes Library (root), Reading, References — shell only, no reader content.
- Shared primitives: loading overlay, toast, bottom sheet (reusable `LoadingView`/`ToastView`/`BottomSheetView` primitives for all features).
- Offline Library: scan `Application Support/novels/books/<slug>/`, list rows from `book.json`, empty state when none.
- Library info sheet only (book details + chapter index from selected book) — NOT Reading sheet. Reading sheet ownership belongs to feat-004/006.
- Swipe-to-delete with confirmation; deletes slug folder via repository boundary from feat-001.
- Vietnamese UI strings; iPhone-only shell.

## Non-goals

- No catalog import/ZIP download, no Text reader (HTML→SwiftUI.Text), no settings UI, no AI/prefetch.

## Acceptance

- [ ] Launch restores session and routes correctly; invalid `bookId` toasts and stays on Library.
- [ ] Library lists only folders with valid `book.json`; empty state shown when zero books.
- [ ] Info sheet shows `name`/`author`/`count`/`references`; delete confirms then removes folder and refreshes list.
- [ ] Loading/toast/bottom-sheet primitives work on Library; Vietnamese copy present.
- [ ] Back at root does not crash; Reading back clears `onScreen`.
- [ ] Reading shell sets/clears `onScreen` per `docs/design/navigation.md:49-50` (Home tap row → `onScreen=true`, Reading back → `onScreen=false`).

## Relevant docs

See `AGENTS.md` Routes and `features/feat-template.md` for canonical doc ownership; additional links only if feature-specific beyond routes.

## Plan

External plan required at activation (≥4 files expected) — create `docs/plans/feat-002.md` per `feat-001` template (`features/feat-001.md:47-51` and `docs/plans/feat-001.md`).

- Link: `docs/plans/feat-002.md` — created on branch `feat/002-app-shell-home-library` per brainstorming approved design (2026-08-25)
- Design: Minimal shell — `AppRoot` + `@Observable Router` (NavigationPath + Route enum), `LibraryViewModel` scanning `FileBookRepository(AppPaths.booksRoot())`, shared `LoadingView`/`ToastView`/`BottomSheetView` with design-system tokens, `BookInfoSheet` + swipe-delete confirm, `ReadingShellView` placeholder with `onScreen` toggles per `navigation.md:49-50`; Vietnamese copy “Thư viện / Chưa có sách / Thông tin sách / Xóa sách? / Hủy / Xóa / Không tìm thấy sách”; `TARGETED_DEVICE_FAMILY=1` already aligned

## Ownership

- Owns: `AppRoot.swift`, `Router.swift`, `LibraryView.swift`, Overlays (`LoadingView`/`ToastView`/`BottomSheetView`), `DeleteConfirm`, strings vi
- Shared: `LibraryView` refresh hook consumed by feat-003 (no ownership conflict)

## Verify

- `./init.sh`
- `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`

## Handoff

- State: done
- Evidence: Tasks 1-5 implemented + Task 6 verification PASS — `apps/novels/App/AppRoot.swift`, `apps/novels/App/Router.swift`, `apps/novels/SharedUI/LoadingView.swift`, `apps/novels/SharedUI/ToastView.swift`, `apps/novels/SharedUI/BottomSheetView.swift`, `apps/novels/Resources/DesignTokens.swift`, `apps/novels/Features/Library/LibraryView.swift`, `apps/novels/Features/Library/LibraryViewModel.swift`, `apps/novels/Features/Library/BookInfoSheet.swift`, `apps/novels/Features/Reading/ReadingShellView.swift`, `apps/novels/NovelsApp.swift`, tests `apps/novelsTests/ToastCenterTests.swift` (2), `apps/novelsTests/RouterTests.swift` (4), `apps/novelsTests/LibraryViewModelTests.swift` (5), `apps/novelsTests/ReadingShellTests.swift` (3), `apps/novelsTests/DomainCodableTests.swift` (13), `apps/novelsTests/BookRepositoryTests.swift` (13), `apps/novelsTests/ProcessedChapterCacheTests.swift` (6), `apps/novelsTests/SettingsStoreTests.swift` (6), `apps/novelsTests/FixtureTests.swift` (1), `apps/novelsUITests/LaunchSmokeTests.swift` (2) — `xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` PASS 40+ tests, `./init.sh` PASS (format 0/lint 0/build PASS/test PASS), `grep TARGETED_DEVICE_FAMILY` = "1" (6 hits), Vietnamese hits “Thư viện/Chưa có sách/Thông tin sách/Xóa sách?/Không tìm thấy sách” in LibraryView/BookInfoSheet/Router, no SwiftData/Core Data/Keychain/BGTask/WebKit (grep 1), no catalog-ai/Prefetch/ProcessedChapter in App/Features (grep 1), no hard-coded Application Support/novels in tests (grep 1 via AppPaths injection), `TARGETED_DEVICE_FAMILY=1` iPhone-only, `SWIFT_VERSION=5.0` iOS 26.5, synchronized groups auto-include
- Blockers: none
- Next: feat-003 Catalog Import + ZIP Ingestion ready to activate (depends_on feat-001, feat-002 done)

# ARCHITECTURE.md — Novels

> Current topology for agents. Product behavior → `docs/product/` and `docs/design/`. Wire and storage → `docs/contracts/`.

## 1. Topology

- **App:** iPhone only, minimum iOS 26.0, Vietnamese UI. Single reader, offline-first. App Debug and Release use device family `1`.
- **Stack:** SwiftUI, Foundation, Observation, system SQLite3. `apps/novels.xcodeproj`, shared scheme `novels`, app module `novels`, unit-test target `novelsTests`. No SwiftPM or Node workspace.
- **Toolchain:** Xcode 26+ with Swift 6.2-capable compiler; `SWIFT_VERSION=5.0` is the language mode, not the compiler version. Verification uses iPhone 17 Pro/iOS 26.5. SDK version is separate from the deployment floor. See `docs/decisions/ios-scope.md`.
- **Quality tools:** SwiftLint and SwiftFormat are required. Configuration: `.swiftlint.yml`, `.swiftformat`, `.githooks/pre-commit`; setup: `scripts/setup.sh`. Setup installs Homebrew versions, not pinned versions.
- **Integrations:** Catalog listing and ZIP download, plus configurable AI endpoints supporting Chat Completions, Responses, and Anthropic messages. Explicit Google sentence lookup uses a system browser sheet. Network is needed for catalog/import, uncached AI and Google lookup, not local reading or installed system English speech. See `docs/contracts/catalog-api.md` and `docs/contracts/ai-service.md`.
- **Stores:** Books in `Application Support/novels/books/<slug>/` via FileManager and Codable; processed chapters in `cache/processed_chapters.sqlite` via SQLite3. Settings, session, and typography use UserDefaults with an `@Observable` store. No Keychain. See `docs/contracts/local-data.md` and `docs/contracts/settings-schema.md`.
- **Rendering:** Foundation parses HTML into an optional title and a plain body string. Reader splits plain bodies into paragraph chunks for SwiftUI `Text`. Bilingual payloads decode once into stable-ID VI/EN rows; English taps open on-demand sentence learning. No reader WebKit or per-word controls.
- **File handling:** Local ZIP extraction supports stored/deflated entries, hygiene filtering, data descriptors, and single-wrapper flattening. Root validation, traversal, CRC, and expansion limits remain enforced. See `docs/contracts/book-package.md`.
- **Security:** ATS has an insecure-HTTP exception for localhost and its subdomains; it does not restrict ports. `http://localhost:8317` is the default AI endpoint, not an ATS port rule. No React Native packages or migration. See `SECURITY.md`.

## 2. Code Map

All paths below exist in the app. This is not a proposed layout.

| Location | Responsibility |
|---|---|
| `apps/novels/NovelsApp.swift`, `apps/novels/App/` | Entry point, dependency composition in `AppRoot`, navigation and session restore in `Router` |
| `apps/novels/Features/Library/`, `apps/novels/Features/Import/` | Local library, book info/delete, catalog and ZIP import view models and screens |
| `apps/novels/Features/Reading/` | Reader view/model, body splitter, references, controls, scroll offset, typography, bilingual rows, system speech and Google browser sheet |
| `apps/novels/Features/Settings/`, `apps/novels/Features/Diagnostics/` | Settings editors, cache management, in-session diagnostic viewer |
| `apps/novels/Domain/`, `apps/novels/Models/` | Book/chapter/session/settings types, HTML parser, slug validation, hashing and exported-book model |
| `apps/novels/Persistence/` | `FileBookRepository`, paths/defaults, ZIP extraction/root validation, `SettingsStore`, `SQLiteProcessedChapterCache` |
| `apps/novels/Services/` | `CatalogService`, `AIClient`, request/response helpers, `AIReadingService`, `PrefetchManager`, diagnostic logging |
| `apps/novels/SharedUI/`, `apps/novels/Shared/`, `apps/novels/Resources/` | Sheets, loading/toast UI, accessibility helpers, design tokens and bundled fonts |
| `apps/novelsTests/` | Separate ZIP ingestion, processed-cache, and AI response unit suites; no UI-test target |

## 3. Boundaries

This is one app module; the folders are responsibility boundaries, not separate framework targets.

- Views and view models coordinate domain types, repositories, settings, and services. Domain models do not import SwiftUI, UIKit, or WebKit.
- Persistence and services use domain models; they do not depend on feature views. Actors return results to UI coordination on the main actor.
- `AIReadingService` and `PrefetchManager` share one processed-chapter cache and AI pipeline. No second AI cache.
- Contracts own wire/storage rules; `docs/product/business-rules.md` owns business rules. Do not duplicate those rules here.
- No SwiftData, Core Data, Swift package, Keychain, or BGTaskScheduler for these boundaries. See `docs/decisions/local-persistence.md`.
- No persisted Network Logger. The in-session viewer follows redaction rules in `docs/decisions/diagnostic-log-viewer.md` and `SECURITY.md`.

## 4. Flows

- **Startup:** `NovelsApp` → `AppRoot` → `Router.restoreInitialRoute()`. Restore a valid reading session without network; otherwise show Library.
- **Import:** `ImportViewModel` loads catalog, downloads a ZIP to temporary storage, extracts, resolves the canonical root, and validates it. `FileBookRepository` imports by slug and refreshes Library. See `docs/contracts/book-package.md` and `docs/decisions/book-identity.md`.
- **Library:** `LibraryViewModel` scans local books through the repository. Confirmed deletion removes the slug folder and related state. See `docs/product/functional-specs/book-library.md`.
- **Reader:** `ReaderViewModel` loads source HTML or processed text. `HtmlParser` extracts title/body; `ReaderBodySplitter` prepares paragraph chunks for `ReaderView`. Navigation and scrolling persist per-book position through `SettingsStore`.
- **AI:** Mode `none` uses source text; independent `rewrite` and `bilingual` check SQLite by slug, chapter, and selected mode. On a miss, `AIReadingService` de-duplicates work and processes chunks in parallel. `AIClient` makes at most two attempts per chunk. Rewrite joins ordered text. Bilingual validates source IDs and nonempty VI/EN pairs, then serializes one versioned chapter; only a complete successful result enters cache. See `docs/contracts/ai-service.md`.
- **Prefetch:** `PrefetchManager` batch-checks cache, then processes chapters sequentially through the same AI pipeline. Same-book/mode navigation reconciles the FIFO queue; book/mode changes or explicit cancellation end it. An unsuccessful chapter can be requeued once. See `docs/product/functional-specs/chapter-prefetch.md`.
- **Settings:** `SettingsStore` sanitizes persisted values, uses defaults for invalid values, and stores validated edits in UserDefaults. See `docs/contracts/settings-schema.md`.

## 5. Verification and Routes

- **Verification:** `init.sh` is canonical. Full `./init.sh` runs format, lint, build, and focused unit tests sequentially, stopping at the first failure. Quick `--quick`/`-q` runs format and lint, explicitly skipping build/tests. Missing SwiftFormat or SwiftLint fails verification.
- **Tests:** Only targeted unit tests for difficult or high-risk logic, in separate files under `apps/novelsTests/`. The hosted test process bypasses `AppRoot` before production stores or session restoration; a startup guard test checks host detection. No UI tests or blanket coverage requirement. See `docs/decisions/verification.md`.
- **Runtime limit:** The current verification destination is iOS 26.5, not 26.0. Deployment settings and API review do not prove runtime behavior on iOS 26.0.
- **Product:** `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md`, `docs/product/flows.md`, `docs/product/functional-specs/`, `docs/product/decisions.md`.
- **Design:** `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md`.
- **Contracts:** `docs/contracts/index.md`; **Decisions:** `docs/decisions/index.md`; **Security:** `SECURITY.md`.
- **Work routes:** [tasks/index.md](tasks/index.md) owns roadmap/navigation only. Each task owns scope, status, dependencies, evidence and handoff. Task completion does not require PR merge. Historical evidence does not describe live Git status.

## 6. Maintenance

Update this map when entry points, topology, or verification change. Follow linked contracts rather than copying their detailed defaults here.

Keep documentation-only work separate from Swift/project changes unless approved. Preserve useful execution evidence in task records before retiring redundant history.
Preserve the tracked sample ZIP; its wrapper shape is non-canonical producer output, not a canonical test fixture.

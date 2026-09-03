# ARCHITECTURE.md — Novels

> Topology for agents. Product behavior → `docs/product/` and `docs/design/`. Wire and storage → `docs/contracts/`.

## 1. Topology

- **App:** iPhone only, iOS 26+, Vietnamese UI. Single reader, offline-first. [Intended — product is iPhone-only/Vietnamese; project `apps/novels.xcodeproj` still lists family `1,2`]
- **Stack:** SwiftUI / Xcode — `apps/novels.xcodeproj` (scheme `novels`, iOS 26.5, Swift 5.0, `DEVELOPMENT_TEAM M5U4E4H84J`). Module `apps/novels`. No SwiftPM/Node. No test target yet. Toolchain is SwiftLint 0.65.1 and SwiftFormat 0.62.1 via `.swiftlint.yml` / `.swiftformat` and `.githooks/pre-commit` (setup `scripts/setup.sh`). [Observed — `init.sh`]
- **Integrations:** Remote Book Catalog (listing and ZIP) and one OpenAI-compatible AI service (rewrite via `AI_PROMPT`). Both need network. Library, Reader, and settings work offline. See `docs/contracts/catalog-api.md`, `docs/contracts/ai-service.md`, `docs/product/integrations.md`.
- **Local stores (accepted native):** See `docs/decisions/local-persistence.md` and `docs/decisions/book-identity.md`.
  - Local Book Repository → `books/<slug>/` in `Application Support/novels/` via `Foundation.FileManager` and `Codable`. See `docs/contracts/local-data.md` and `docs/decisions/book-identity.md`.
  - ProcessedChapter cache → `processed_chapters.sqlite` in `Application Support/novels/cache/` via system `SQLite3` (`libsqlite3`, no package). See `docs/contracts/local-data.md`.
  - Settings, Session, Typography → `UserDefaults` wrapped by `@Observable`. Stores `AI_CUSTOM_HEADERS` as normal JSON. No `Keychain`. See `docs/contracts/settings-schema.md`.
   - File handling: `FileManager.unzipItem` extracts ZIP with tolerant hygiene + wrapper flatten + data-descriptor support, strict security invariants preserved. See `docs/contracts/book-package.md` and `docs/contracts/local-data.md`.
  - HTML rendering: `Foundation` parses `div`, `h*`, `p`, `br`, `b`, `strong`, `i`, `em`, `span` into spans for `SwiftUI.Text`. No WebKit. See `docs/contracts/local-data.md`.
  - Networking: `URLSession` uses `async/await`, `Task` cancellation, and `actor` de-duplication for catalog, AI, and prefetch. See `docs/contracts/catalog-api.md` and `docs/contracts/ai-service.md`.
  - Security: `NSAppTransportSecurity` allows `http://localhost:8317` only.
  - Scope: No React Native packages. No RN migration in any direction. Historical RN findings are reference only.
- **Settings keys:** Current keys only. Canonical list lives in `docs/contracts/settings-schema.md`. Keys include `BOOKS_API_URL`, `OPENAI_API_URL`, `OPENAI_MODEL`, `PREFETCH_COUNT`, and `DIAGNOSTICS_VERBOSE`. Defaults are `gpt-4o`, prefetch `3`, chunk `1300`. Invalid JSON is ignored. Unknown or legacy keys are ignored. See `docs/decisions/local-persistence.md`. [Accepted]

## 2. Code Map

> Current code is stub (`apps/novels/ContentView.swift` is `Hello, world!`). Map below is intended layering. All locations are [Proposed/Intended].

| Layer | Responsibility | Intended location | Native choice |
|---|---|---|---|
| Presentation | SwiftUI screens, navigation, overlays (Library, Add Book, Reading, References, Settings, Cache Manager, Setting Editor, Bottom Sheet, Toast) | `apps/novels/**` views | SwiftUI and `SwiftUI.Text` (HTML → spans, no WebKit) |
| Domain | Entities and invariants from `docs/product/domain-model.md`, state machines (AI Mode, Reading Position, Prefetch Status), rules BR-01..12 | domain models / use-cases | pure Swift |
| Data — Repository | Scan, extract, and delete ZIP; read `book.json` and HTML; per-book offset and typography | `docs/contracts/local-data.md`, `docs/contracts/book-package.md` | `FileManager` + `Codable` + `FileManager.unzipItem` in `Application Support` |
| Data — Cache | ProcessedChapter cache, de-duplication, `contentHash` | `docs/contracts/local-data.md` | system `SQLite3` (`processed_chapters.sqlite`) |
| Data — Settings | Restore and sanitize on launch; validate on edit | `docs/contracts/settings-schema.md` | `UserDefaults` + `@Observable` (no Keychain) |
| Integrations | Catalog POST client, ZIP download, AI chunk and retry client (merge `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY`) | `docs/contracts/catalog-api.md`, `docs/contracts/ai-service.md` | `URLSession` `async/await` + `actor` de-dup + `Task` cancel |
| Cross-cutting | Chunking (~1300), retry (3×, `1000/2000 ms`), prefetch status (runtime-only) | `docs/contracts/ai-service.md`, `docs/product/functional-specs/chapter-prefetch.md` | — |

No test target exists yet. First feature will add tests. Do not change project or test config in docs tasks. [Observed/Open — test target shape only]

## 3. Boundaries

Allowed direction: Presentation → Domain → Data/Integrations. Contracts are interfaces.

- **Allowed:** Presentation can depend on Domain and contracts. Domain can depend on contract protocols and types. Data and Integrations implement contracts and can depend on Domain entities.
- **Allowed:** `chapter-prefetch` can depend on `ai-reading` cache path and `local-data` cache boundary.
- **Forbidden:** Domain must not import SwiftUI, UIKit, or WebKit. Data must not import Presentation. Integrations must not mutate UI state directly. They return results to Domain. No business rule duplication outside `docs/product/business-rules.md`. No second AI cache. Use the accepted boundaries in `docs/decisions/local-persistence.md` and `docs/contracts/local-data.md`.
- **Forbidden:** No `SwiftData`, `Core Data`, Swift package, `Keychain`, or `BGTaskScheduler` for these boundaries (see `local-persistence.md` Non-Decisions). No React Native dependency or migration. No persisted Network Logger; in-session diagnostic viewer allowed with redaction per `docs/decisions/diagnostic-log-viewer.md` (partial supersede `network-logger-removed.md`).

## 4. Flows

Startup → Session restore (no network) → route `onScreen ? Reading(bookId: slug) : Library`. See `docs/product/flows.md` §1 and `docs/design/navigation.md`.

Discover and Import → read `BOOKS_API_URL` and POST catalog (no body). Then it lists results, downloads ZIP via `URLSession` to temp, extracts with `FileManager.unzipItem` to `Application Support/novels/books/<slug>/`, validates root, deletes ZIP, and refreshes Library. See `docs/contracts/catalog-api.md`, `docs/contracts/book-package.md`, `docs/contracts/local-data.md`, `docs/decisions/book-identity.md`.

Library → scan `Application Support/novels/books/` and `Codable` read `book.json`. Then it shows rows, and supports Info sheet or swipe Delete (confirm removes slug folder). See `docs/contracts/local-data.md`, `docs/product/functional-specs/book-library.md`.

Reader → parse `chapters/chapter-N.html` to text spans and render with `SwiftUI.Text`. It uses typography from `@Observable` store. Previous, Next, and index save offset per slug `bookId`. See `docs/contracts/local-data.md`, `docs/product/functional-specs/book-reader.md`.

AI Reading → mode `none` shows raw text. Mode `rewrite` checks cache first (`bookId(slug)+chapterNumber+mode` via SQLite). On miss, the app chunks text (~1300) and POSTs each chunk to `OPENAI_API_URL` via `URLSession`. It merges `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` JSON and ignores invalid JSON. It retries 3× (`1000/2000 ms`) with `actor` de-duplication, joins and cleans text, then does `INSERT OR REPLACE` into cache. See `docs/contracts/ai-service.md`, `docs/contracts/settings-schema.md`, `docs/product/functional-specs/ai-reading.md`.

Prefetch → runs when mode is not `none` and chapter is ready. N = `PREFETCH_COUNT` (default `3`, range `1..10`, else `3`). Batch-check SQLite → sequential chapters via same AI path → `Task` cancels on chapter or mode change. See `docs/contracts/ai-service.md`, `docs/contracts/local-data.md`, `docs/product/functional-specs/chapter-prefetch.md`.

Settings → sanitize on launch (missing or invalid → defaults; unknown or legacy → ignored; unknown provider → `openai`; empty `AI_PROMPT` → default prompt). Edit → validate → persist to `UserDefaults`. See `docs/contracts/settings-schema.md`, `SECURITY.md`, `docs/product/functional-specs/settings-management.md`.

## 5. Verification and Routes

- **Build and test:** `init.sh` is canonical. Full `./init.sh` runs format, lint, build, test, drift; `--quick` (`-q`) runs format + lint + drift only (skip build/test) for fast local loops. Evidence: `apps/novels.xcodeproj/project.pbxproj` (scheme `novels`, iOS 26.5), `xcodebuild -list` shows single target, `xcrun simctl list` shows iPhone 17 Pro (iOS 26.5). Format and lint use SwiftLint and SwiftFormat. [Observed]
- **Product truth:** `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md`, `docs/product/flows.md`, `docs/product/glossary.md`, `docs/product/integrations.md`, `docs/product/functional-specs/*`, business decisions `docs/product/decisions.md`.
- **Design:** `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md`.
- **Contracts:** `docs/contracts/index.md` → `catalog-api.md`, `ai-service.md`, `book-package.md`, `settings-schema.md`, `local-data.md`.
- **Decisions:** `docs/decisions/index.md` → `ios-scope.md`, `network-logger-removed.md`, `ai-service-defaults.md`, `book-package-shape.md`, `local-persistence.md`, `book-identity.md`; business canonical `docs/product/decisions.md`.
- **Security:** `SECURITY.md` (no Keychain, no Network Logger, no secrets in docs).
- **Work state:** `feature_index.json`, `features/*`, `progress.md`, `init.sh`.

## 6. Notes

- Labels: **Observed** is in repo; **Intended** is accepted but not in code; **Open** is undecided detail (for example backup exclusion and test target shape).
- Do not edit Swift, Xcode project, `feature_index.json`, `features/`, `progress.md`, `init.sh`, or delete `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip` in docs tasks. That ZIP is tracked. It has an outer folder and `__MACOSX` data. It is not a valid fixture. See `docs/contracts/book-package.md`.

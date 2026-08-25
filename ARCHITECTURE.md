# ARCHITECTURE.md — Novels

> Concise topology for agents and contributors. Behavioral truth stays in `docs/product/` and `docs/design/`; wire details in `docs/contracts/`.

## 1. Topology

- **App:** iOS, iPhone only, iOS 26+, UI language Vietnamese. Single reader, offline-first. [Intended — product scope iPhone-only/Vietnamese; project `project.pbxproj` still lists family `1,2` unchanged in this docs-only task]
- **Stack:** SwiftUI / Xcode — `apps/novels.xcodeproj` (scheme `novels`, iOS 26.5, Swift 5.0, `DEVELOPMENT_TEAM M5U4E4H84J`). Single workspace module `apps/novels`. No SwiftPM/Node, no test target yet. Toolchain: SwiftLint 0.65.1 + SwiftFormat 0.62.1 via `.swiftlint.yml`/`.swiftformat` + `.githooks/pre-commit` (setup `scripts/setup.sh`). [Observed — `init.sh`]
- **External integrations:** Remote Book Catalog (read-only listing + ZIP download) and one OpenAI-compatible AI service (translate/summary per chunk). Both require network; reading/library/settings work offline. See `docs/contracts/catalog-api.md`, `docs/contracts/ai-service.md`, and `docs/product/integrations.md`.
- **Local layers (accepted native):** see `docs/decisions/local-persistence.md` and `docs/decisions/book-identity.md`
  - Logical → physical: Local Book Repository → `Application Support/novels/books/<slug>/` via `Foundation.FileManager` + `Codable` (`book-identity.md`); ProcessedChapter single cache → `Application Support/novels/cache/processed_chapters.sqlite` via system `SQLite3` (`libsqlite3`, no package); Settings/Session/Typography → `UserDefaults` wrapped by `@Observable` store (includes normal storage of `AI_CUSTOM_HEADERS` JSON, no Keychain).
  - Native choices: `FileManager.unzipItem` for ZIP with strict archive-root validation; `Foundation` HTML → `SwiftUI.Text` pipeline (lightweight parse `div`/`h*`/`p`/`br`/`b`/`strong`/`i`/`em`/`span`) for `chapter-N.html`; `URLSession` `async/await` + `Task` cancellation + `actor` de-duplication for catalog/AI/prefetch; `localhost`-only `NSAppTransportSecurity` exception for `http://localhost:8317`.
  - No React Native packages and no RN data/settings/cache migration in any direction; historical RN findings are reference only.
- **Settings keys (current-only, canonical in `docs/contracts/settings-schema.md`):** `BOOKS_API_URL`, `OPENAI_API_URL`, `OPENAI_MODEL`, `PREFETCH_COUNT`, … — see `settings-schema.md` for full list. Defaults: `gpt-4o`, prefetch `3`, chunk `1300`. Invalid JSON for headers/body is ignored; unknown/legacy keys are ignored and defaults apply. See `docs/decisions/local-persistence.md`. [Accepted]

## 2. Interpreted Code Map

> Current code is stub (`apps/novels/ContentView.swift` shows `Hello, world!`, `apps/novels/novelsApp.swift` only hosts `ContentView`). Map below is intended layering, not observed files. All code locations are [Proposed/Intended] until code exists.

| Layer | Responsibility | Intended location | Native choice |
|---|---|---|---|
| Presentation | SwiftUI screens, navigation, overlays (Library, Add Book, Reading, References, Settings, Cache Manager, Setting Editor, Bottom Sheet, Toast) | `apps/novels/**` views | SwiftUI + `SwiftUI.Text` (HTML → text spans, no WebKit) |
| Domain | Entities/invariants from `docs/product/domain-model.md`, state machines (AI Mode, Reading Position, Prefetch Status), business rules BR-01..12 | domain models / use-cases | pure Swift |
| Data — Repository | Scan/extract/delete ZIP, read `book.json` + chapter HTML, per-book offset, typography persistence | local data boundaries (`docs/contracts/local-data.md`, `docs/contracts/book-package.md`) | `FileManager` + `Codable` + `FileManager.unzipItem` in `Application Support` |
| Data — Cache | ProcessedChapter single cache, de-duplication, `contentHash` | `docs/contracts/local-data.md` | system `SQLite3` (`processed_chapters.sqlite`) |
| Data — Settings | Restore/sanitize on launch, validate on edit | `docs/contracts/settings-schema.md` | `UserDefaults` + `@Observable` (no Keychain) |
| Integrations | Catalog POST client, ZIP download/extract, AI chunk + retry client (merge `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY`) | `docs/contracts/catalog-api.md`, `docs/contracts/ai-service.md` | `URLSession` `async/await` + `actor` de-dup + `Task` cancel |
| Cross-cutting | Chunking (~1300), retry (3×, `1000/2000 ms`), prefetch status (runtime-only) | `docs/contracts/ai-service.md`, `docs/product/functional-specs/chapter-prefetch.md` | — |

No test target exists yet. First feature will add unit/UI tests — do not modify project/test config in this docs task. [Observed/Open — test target shape only]

## 3. Allowed / Forbidden Dependency Edges

Allowed direction: Presentation → Domain → Data/Integrations. Contracts are interfaces, not implementations.

- **Allowed:** Presentation may depend on Domain and contracts; Domain may depend on contract protocols/types; Data and Integrations implement contracts and depend on Domain entities.
- **Allowed:** `chapter-prefetch` may depend on `ai-reading` cache path and `local-data` cache boundary.
- **Forbidden:** Domain must not import SwiftUI/UIKit/WebKit. Data must not import Presentation. Integrations must not directly mutate UI state — they return results to Domain. No business rule duplication outside `docs/product/business-rules.md`. No second AI cache. Depend on the accepted native boundaries in `docs/decisions/local-persistence.md` / `docs/contracts/local-data.md` — not on an open choice.
- **Forbidden:** No `SwiftData`, `Core Data`, Swift package, `Keychain`, or `BGTaskScheduler` for these boundaries (see `local-persistence.md` Non-Decisions). No React Native dependency or migration. No Network Logger screen/route — removed from product/design scope (see `docs/decisions/network-logger-removed.md`). Do not reintroduce.

## 4. Major Flows (system)

Startup → Session restore (no network) → route `onScreen ? Reading(bookId: slug) : Library`. See `docs/product/flows.md` §1 and `docs/design/navigation.md`.

Discover & Import → read `BOOKS_API_URL` → POST catalog (no body) → list → download ZIP via `URLSession` to temp → `FileManager.unzipItem` to `Application Support/novels/books/<slug>/` with strict root validation → delete ZIP → refresh Library. See `docs/contracts/catalog-api.md`, `docs/contracts/book-package.md`, `docs/contracts/local-data.md`, `docs/decisions/book-identity.md`.

Library → scan `Application Support/novels/books/` → `Codable` read `book.json` → rows → Info sheet / swipe Delete (confirm → `FileManager` remove slug folder). See `docs/contracts/local-data.md`, `docs/product/functional-specs/book-library.md`.

Reader → parse `chapters/chapter-N.html` to text spans → render with `SwiftUI.Text` using typography from `@Observable` store → Previous/Next/index → save offset per slug `bookId`. See `docs/contracts/local-data.md`, `docs/product/functional-specs/book-reader.md`.

AI Reading → mode `none` raw; `translate`/`summary` cache-first `bookId(slug)+chapterNumber+mode` via SQLite → on miss chunk ~1300 → `URLSession` POST `OPENAI_API_URL` per chunk (merge `AI_CUSTOM_HEADERS` JSON + `AI_EXTRA_BODY` JSON; ignore invalid JSON) → retry 3× (1000/2000 ms) + `actor` de-dup → join/clean/text → `INSERT OR REPLACE` cache. See `docs/contracts/ai-service.md`, `docs/contracts/settings-schema.md`, `docs/product/functional-specs/ai-reading.md`.

Prefetch → eligible when mode != `none` and chapter ready → N = `PREFETCH_COUNT` (default 3, 1..10 else 3) → batch-check SQLite → sequential `bookId(slug)` chapters via same AI path → `Task` cancellable on chapter/mode change. See `docs/contracts/ai-service.md`, `docs/contracts/local-data.md`, `docs/product/functional-specs/chapter-prefetch.md`.

Settings → sanitize on launch (missing/invalid → defaults; unknown/legacy → ignored; unknown provider → `openai`; bad actions → `translate`+`summary`), edit → validate → persist to `UserDefaults`. See `docs/contracts/settings-schema.md`, `SECURITY.md`, `docs/product/functional-specs/settings-management.md`.

## 5. Verification and Related-Doc Routes

- **Build/test:** `./init.sh` → format → lint → `xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` → test SKIP. Evidence: `apps/novels.xcodeproj/project.pbxproj` (scheme novels, iOS 26.5), `xcodebuild -list` single target, `xcrun simctl list` iPhone 17 Pro iOS 26.5. Format/lint active via SwiftLint/SwiftFormat; test SKIP — no test target yet (explicit SKIP in `init.sh`). [Observed]
- **Product truth:** `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md`, `docs/product/flows.md`, `docs/product/glossary.md`, `docs/product/integrations.md`, `docs/product/functional-specs/*`, business decisions `docs/product/decisions.md`.
- **Design:** `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md`.
- **Contracts:** `docs/contracts/index.md` → `catalog-api.md`, `ai-service.md`, `book-package.md`, `settings-schema.md`, `local-data.md`.
- **Decisions:** `docs/decisions/index.md` → `ios-scope.md`, `network-logger-removed.md`, `ai-service-defaults.md`, `book-package-shape.md`, `local-persistence.md`, `book-identity.md`; business canonical `docs/product/decisions.md`.
- **Security:** `SECURITY.md` (no Keychain, no Network Logger, no secrets in docs).
- **Work state:** `feature_index.json`, `features/*`, `progress.md`, `init.sh`.

## 6. Notes on Facts

- Labels: **Observed** = seen in repo; **Intended** = not yet in code but accepted; **Open** = genuinely undecided operational detail (e.g. backup exclusion for Application Support if not covered by default, and test target shape).
- Do not edit Swift, Xcode project, feature_index.json, features/, progress.md, init.sh, or delete docs/samples/van-gioi-chi-rut-thuong-he-thong.zip in docs-only tasks. That ZIP is tracked, has an outer folder and __MACOSX data, and is not a valid fixture; see docs/contracts/book-package.md.

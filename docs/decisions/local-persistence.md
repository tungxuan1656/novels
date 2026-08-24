# ADR — Native Local Persistence Stack

- **Date:** 2026-08-24
- **Status:** Accepted
- **Supersedes:** open physical-technology items in `docs/contracts/local-data.md`, `SECURITY.md`, and `ARCHITECTURE.md` §1/§6; no longer open

## Context

Physical persistence was open (`SwiftData` / `UserDefaults` / `FileManager` / `Core Data` / `SQLite` etc.). Product needs an offline-first native iOS 26+ stack without React Native packages, data/settings/cache migration, extra Swift packages, or platform schedulers. Settings already include `AI_CUSTOM_HEADERS` as user-entered JSON that must remain usable without a special credential store.

## Decision

Use the native Swift stack — Foundation + system frameworks only. No React Native data to read or migrate; RN findings are historical reference only.

| Logical boundary | Physical store | Native API | Location / detail | Status |
|---|---|---|---|---|
| Local Book Repository | File system — Codable + FileManager | `Foundation.FileManager` + `Codable` | `Application Support/novels/books/<book.json.id>/` with `book.json` + `chapters/chapter-N.html` | Accepted |
| ProcessedChapter cache (single AI cache) | SQLite via system `libsqlite3` | `SQLite3` (system `libsqlite3.dylib`, no Swift package) — gated behind protocol so it can be swapped | `Application Support/novels/cache/processed_chapters.sqlite` — table `processed_chapters` | Accepted |
| Settings / Session / Typography | UserDefaults via `@Observable` wrapper | `Foundation.UserDefaults` + `Observation.@Observable` | Current keys only (`BOOKS_API_URL`, `OPENAI_API_URL`, `OPENAI_MODEL`, `AI_CUSTOM_HEADERS`, `AI_EXTRA_BODY`, `PREFETCH_COUNT`, `AI_PROVIDER`, `AI_PROCESS_ACTIONS`, `AI_MIN_CHUNK_SIZE`, typography/session); `AI_CUSTOM_HEADERS` stored as normal settings JSON with no Keychain | Accepted |
| ZIP extraction | System unzip | `Foundation.FileManager.unzipItem(at:to:)` | Strict archive-root validation (`book.json` at root); rejects wrapper sample | Accepted |
| Chapter rendering | Web view | `WebKit.WKWebView` via `UIViewRepresentable` | Loads `chapters/chapter-N.html` | Accepted |
| Network | URLSession concurrency | `Foundation.URLSession` `async/await` + `Task` cancellation + `actor` de-duplication | Catalog POST + AI Chat Completions per `docs/contracts/catalog-api.md` / `ai-service.md`; `localhost` ATS exception for `http://localhost:8317` | Accepted |

Exact official references:
- FileManager / Application Support / unzipItem: https://developer.apple.com/documentation/foundation/filemanager
- Codable: https://developer.apple.com/documentation/swift/codable
- UserDefaults: https://developer.apple.com/documentation/foundation/userdefaults
- Observation: https://developer.apple.com/documentation/observation
- WebKit WKWebView: https://developer.apple.com/documentation/webkit/wkwebview
- URLSession: https://developer.apple.com/documentation/foundation/urlsession
- App Sandbox / File System / ATS: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox and https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity
- SQLite is a system library, not a Swift package; accessed via `libsqlite3` (`import SQLite3` when present) behind an internal protocol.

## Consequences

- App writes only to Application Support and UserDefaults; no Documents/iCloud sync by default. Bundle is not written.
- Single cache table (see `docs/contracts/local-data.md` schema) keyed by `book_id + chapter_number + mode`; Upsert via `UNIQUE(book_id, chapter_number, mode)`; batch-check, index, clear, and delete-on-book-remove semantics apply.
- Settings sanitize on launch uses current keys only; unknown/legacy keys are ignored and defaults apply (no migration).
- `AI_CUSTOM_HEADERS` persists as normal settings; do not add Keychain, encryption, or redaction-log feature.
- No extra capabilities needed for ZIP, web, or network beyond the `localhost` ATS exception.

## Non-Decisions

- No React Native dependency or data/settings/cache migration in any direction.
- No `SwiftData`, `Core Data`, or Swift package for persistence/networking.
- No `Keychain` or special credential store.
- No background-task scheduler (`BGTaskScheduler`) for prefetch; prefetch remains foreground/task-scoped.
- No custom file backup exclusion flag decided — operational detail remains open only if not already covered by Application Support defaults; do not invent a value.

## Links

- `ARCHITECTURE.md` (topology, logical→physical map) · `docs/contracts/local-data.md` · `docs/contracts/settings-schema.md` · `docs/contracts/book-package.md` · `docs/contracts/ai-service.md` · `SECURITY.md` · `docs/decisions/book-identity.md`

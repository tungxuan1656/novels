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
| Chapter rendering | Native text | `Foundation` HTML → `SwiftUI.Text` pipeline (lightweight parse) | Parses `chapters/chapter-N.html` (`div`/`h*`/`p`/`br`/`b`/`strong`/`i`/`em`/`span`) → `SwiftUI.Text` in `VStack` | Accepted |
| Network | URLSession concurrency | `Foundation.URLSession` `async/await` + `Task` cancellation + `actor` de-duplication | Catalog POST + AI Chat Completions per `docs/contracts/catalog-api.md` / `ai-service.md`; `localhost` ATS exception for `http://localhost:8317` | Accepted |

Exact official references:
- FileManager / Application Support / unzipItem: https://developer.apple.com/documentation/foundation/filemanager
- Codable: https://developer.apple.com/documentation/swift/codable
- UserDefaults: https://developer.apple.com/documentation/foundation/userdefaults
- Observation: https://developer.apple.com/documentation/observation
- SwiftUI Text: https://developer.apple.com/documentation/swiftui/text
- URLSession: https://developer.apple.com/documentation/foundation/urlsession
- App Sandbox / File System / ATS: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox and https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity
- SQLite is a system library, not a Swift package; accessed via `libsqlite3` (`import SQLite3` when present) behind an internal protocol.

## Consequences

- App writes only to Application Support and UserDefaults; no Documents sync. Bundle is read-only.
- Single cache table keyed by `book_id + chapter_number + mode` (`UNIQUE(book_id, chapter_number, mode)`); covers upsert, batch-check, index, clear, delete-on-book-remove.
- Settings sanitize on launch for current keys only; unknown keys ignored, defaults apply; no migration.
- `AI_CUSTOM_HEADERS` stays as normal settings; no Keychain, encryption, or redaction log.
- No extra capabilities beyond `localhost` ATS exception.

## Non-Decisions

- No React Native dependency or migration.
- No `SwiftData`/`Core Data`/Swift package; no `Keychain`.
- No `BGTaskScheduler` for prefetch (foreground/task-scoped); no custom backup exclusion.

## Links

- `ARCHITECTURE.md` (topology, logical→physical map) · `docs/contracts/local-data.md` · `docs/contracts/settings-schema.md` · `docs/contracts/book-package.md` · `docs/contracts/ai-service.md` · `SECURITY.md` · `docs/decisions/book-identity.md`

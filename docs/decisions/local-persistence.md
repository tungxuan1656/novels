# ADR — Native Local Persistence Stack

- **Date:** 2026-08-24
- **Status:** Accepted
- **Supersedes:** open physical-technology items in `../contracts/local-data.md`, `SECURITY.md`, and `../../ARCHITECTURE.md` §1/§6; no longer open

## Context

Physical persistence was open (`SwiftData` / `UserDefaults` / `FileManager` / `Core Data` / `SQLite` etc.). Product needs an offline-first native iOS 26+ stack without React Native packages, data/settings/cache migration, extra Swift packages, or platform schedulers. Settings already include `AI_CUSTOM_HEADERS` as user-entered JSON that must remain usable without a special credential store.

## Decision

Use the native Swift stack — Foundation + system frameworks only. No React Native data to read or migrate. Canonical paths and DDL live in `../contracts/local-data.md`.

- **Local Book Repository:** `Foundation.FileManager` + `Codable`.
- **ProcessedChapter cache (single cache, `UNIQUE(bookId,chapterNumber,mode)`):** system `libsqlite3` (no Swift package) behind a protocol.
- **Settings / Session / Typography:** `Foundation.UserDefaults` + `Observation.@Observable` (no `Keychain`).
- **ZIP extraction:** `Foundation.FileManager.unzipItem(at:to:)` with strict archive-root validation.
- **Chapter rendering:** `Foundation` parses `div`, `h*`, `p`, `br`, `b`, `strong`, `i`, `em`, `span` into spans for `SwiftUI.Text` (no WebKit).
- **Network:** `Foundation.URLSession` with `async/await`, `actor` de-duplication, and `Task` cancellation.
- **Security:** `NSAppTransportSecurity` allows `http://localhost:8317` only.

Official references:

- FileManager / Application Support / unzipItem: https://developer.apple.com/documentation/foundation/filemanager
- Codable: https://developer.apple.com/documentation/swift/codable
- UserDefaults: https://developer.apple.com/documentation/foundation/userdefaults
- Observation: https://developer.apple.com/documentation/observation
- SwiftUI Text: https://developer.apple.com/documentation/swiftui/text
- URLSession: https://developer.apple.com/documentation/foundation/urlsession
- App Sandbox / File System / ATS: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox and https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity

## Alternatives

| Option | Reason not chosen |
|---|---|
| `SwiftData` for books or cache | Requires model container and migration; overkill for file + single table |
| `Core Data` for cache | Heavy stack for one table with `UNIQUE(bookId,chapterNumber,mode)` |
| `Keychain` for `AI_CUSTOM_HEADERS` | Adds access policy and sync complexity; user-entered JSON stays in `UserDefaults` per scope |
| `BGTaskScheduler` for prefetch | Prefetch is foreground and task-scoped; background scheduling not required |
| React Native package or SQLite wrapper package | No React Native and no extra Swift package; use system `libsqlite3` |

## Consequences

- App writes only to `Application Support` and `UserDefaults`; bundle is read-only.
- Single cache keyed by `bookId + chapterNumber + mode`; canonical DDL and queries live in `../contracts/local-data.md`.
- Settings sanitize on launch for current keys only; unknown keys are ignored and defaults apply.
- `AI_CUSTOM_HEADERS` stays as normal settings; no `Keychain`, encryption, or redaction log.
- No extra capabilities beyond `localhost` ATS exception.

## Links

- Canonical: `../contracts/local-data.md` · `../contracts/settings-schema.md` · `../contracts/book-package.md` · `../contracts/ai-service.md` · `../../SECURITY.md` · `../../ARCHITECTURE.md` · `book-identity.md`

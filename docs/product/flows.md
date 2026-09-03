# UX Flows — Novels

> **Scope owner:** Canonical UX flows. For entities see [domain-model.md](./domain-model.md), terms [glossary.md](./glossary.md), rules [business-rules.md](./business-rules.md), integrations [integrations.md](./integrations.md), navigation [navigation.md](../design/navigation.md).

## Flow

### 1 — Startup and Resume

Request → System restores session and settings from persistent settings store → Checks `onScreen`.
- `true` → Open Reader for saved `bookId`, restore offset.
- `false` / no session → Show Library.
- No network. Missing values use defaults.

### 2 — Discover and Import Book

Request → User opens Add Book → System fetches catalog from remote catalog.
- Success → Show list (name, author, size).
- Empty → "No books available."
- Error (no network / server) → "Cannot load catalog, try again" + pull to retry.
- Request → User picks book → System downloads ZIP to file storage → Extracts to local book repository (`book.json` + `chapters/chapter-N.html`) → Deletes ZIP → Updates Library → Success.
- Failure → Error, no partial book listed, retry.

### 3 — Library Browse and Manage

Request → User views Library → System lists books from local book repository.
- Empty → Prompt to add via +.
- Request → Tap Info → Show sheet with metadata and chapter index.
- Request → Swipe Delete → Confirm → Remove folder from file storage + entry (cache unreachable). Cancel → No change.

### 4 — Reading and Navigation

Request → User opens book → System marks `onScreen=true` → Loads current chapter (1-based, default 1, clamp 1..total) from file storage → Parses HTML to text spans per local-persistence.md → Renders with SwiftUI.Text → Restores offset or top.
- Request → Next/Previous → Step within bounds. Button is disabled at ends.
- Scroll → Saves offset per book. New chapter starts at top.
- Request → Scroll to bottom or open index → Jump to chapter.
- Missing file → "Failed to load chapter."

### 5 — AI Mode with Cache

Request → User switches `none` ("Không") | `rewrite` ("Rewrite").
- `none` → Raw text parsed from HTML in file storage → Render with SwiftUI.Text.
- `rewrite` → Check processed chapter cache by `bookId + chapterNumber + "rewrite"` → Hit → Render cached text with SwiftUI.Text.
- Miss → Read raw text → Split ~1300 chars (short = one) → Call AI processing service per chunk with system `AI_PROMPT`. Retry three times (1000 ms / 2000 ms) per ai-service.md. Then join, clean, and save to cache as text. Then render with SwiftUI.Text.
- Failure or empty → Show error. Do not write cache.

### 6 — Prefetch Background

Runs only when current chapter ready, book exists, mode != `none`.
- Request → System takes next N (default 3, 1..10 else 3) → Batch-check cache → Skip cached → Process missing one by one via Flow 5 → Update `isRunning`/`total`/`processed`/`errors`.
- At end or all cached → No work.
- Request → Change chapter/mode → Cancel run, start new.
- Per-chapter error → Log and continue.

### 7 — Settings

Request → User opens Settings → System shows groups: catalog, AI, download, prefetch, typography.
- Request → Edit → Validate and persist to persistent settings store.
- On launch → Sanitize. If values are invalid or missing, use defaults (catalog URL, AI `gpt-4o`, N=3, chunk 1300, provider `openai`).

## Cases

| Case | Result |
|---|---|
| ZIP missing `book.json` or chapters | Fail import |
| No network on catalog or AI | Show error. AI retries three times. No cache write |
| Empty AI response | "No response from AI service" |
| Invalid N | Use default 3 |
| Invalid chunk | Use default 1300 |
| Invalid JSON headers | Ignore |
| Book deleted during prefetch | Cancel |
| Chapter out of bounds | Clamp 1..total |

## Acceptance

- [ ] Launch resumes Reader if `onScreen=true`, else Library.
- [ ] Catalog loading, empty, and error are visible. Import creates folder and deletes ZIP.
- [ ] Delete needs confirm and removes folder.
- [ ] Reader parses HTML to text and renders with SwiftUI.Text. Navigation stays bounded and offset is per book.
- [ ] AI uses cache on hit and service on miss, then saves result.
- [ ] Prefetch skips cached, runs sequential, and cancels on change.
- [ ] Settings persist. Invalid values fall back to defaults.

## Links

- Model: [domain-model.md](./domain-model.md) · Glossary: [glossary.md](./glossary.md) · Rules: [business-rules.md](./business-rules.md) · Integrations: [integrations.md](./integrations.md)
- Specs: `./functional-specs/book-import.md` · `./functional-specs/book-library.md` · `./functional-specs/book-reader.md` · `./functional-specs/ai-reading.md` · `./functional-specs/chapter-prefetch.md` · `./functional-specs/settings-management.md`

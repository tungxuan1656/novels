# Novels

![iOS 26.5](https://img.shields.io/badge/iOS-26.5-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS26-lightgrey)
![SwiftLint](https://img.shields.io/badge/SwiftLint-0.65.1-green)
![SwiftFormat](https://img.shields.io/badge/SwiftFormat-0.62.1-green)
![License MIT](https://img.shields.io/badge/license-MIT-green)

> Offline-first reader for iPhone. Download once, read without a network. Optional AI translate and summary with a single cache.

## Overview

Novels is an offline-first reader for iPhone.
It runs on iOS 26 and later (project builds against iOS 26.5) and shows text in Vietnamese.
You download a book package once and then read the book without a network.
The app keeps one copy of each book on the device.
It also keeps typography and scroll position for each book.

The app has seven screens that share one navigation flow.
Library lists local books and shows `Info` and `Delete` by swipe.
Reader shows chapters (parsed HTML → native Text) and saves the offset per book.
Add Book fetches the remote catalog and imports the selected ZIP package.
Settings edits all persistent keys and restores them on launch.

Optional AI modes transform the current chapter before you read it.
Mode `none` shows the original text (parsed from HTML) without a network request.
Mode `translate` produces natural Vietnamese and keeps honorifics unchanged.
Mode `summary` reduces length to 50 to 60 percent and keeps plot and dialogue.
The app caches each result by `bookId`, `chapterNumber`, and `mode`.
When the mode is not `none`, prefetch loads the next three chapters in the background.

## Features

The app provides these features:

- **Import** — Import downloads a ZIP package from the catalog and extracts `book.json` and `chapters/chapter-N.html` to the local repository.
- **Library** — Library scans the local repository and shows each book with name, author, and chapter count.
- **Reader** — Reader parses chapter HTML to text spans and shows with SwiftUI.Text, provides Previous and Next, and restores scroll offset per book.
- **AI Reading** — AI Reading runs translate or summary on chunks of about 1300 characters and caches the result.
- **Prefetch** — When eligible, prefetch queries the cache and then processes the next three chapters in sequence.
- **Settings** — When the value is missing or invalid, settings sanitizes the value and restores the default in `UserDefaults`.

For rules that govern these features, read `docs/product/business-rules.md`.

## Screens

The app has seven screens and three overlays.

| Screen | Purpose | Key elements |
|---|---|---|
| **Home Library** | Browse books | Header with add and settings, row with name, author, and count |
| **Add Book** | Import book | Header back, remote list, download overlay |
| **Reading** | Read and navigate | Header index and title, native Text body (parsed from HTML), Previous and Next, scroll save |
| **References** | Jump chapter | Header back, title list, current item in bold |
| **Settings** | Edit settings | Header, grouped list, data card for cache |
| **Cache Manager** | Clear AI cache | Header, count card, clear button, note |
| **Setting Editor** | Edit one value | Header, description, input, Clear and Save |

Shared overlays are Bottom Sheet, Toast, and Loading.
Bottom Sheet on Reader holds font, mode switch, reprocess, and typography controls.
Toast shows at the top and disappears after 3 to 5 seconds by length.
Loading shows a spinner for lists and a blocking overlay for download and AI.

For navigation, read `docs/design/navigation.md`.
For screen details, read `docs/design/screens.md`.

## Architecture

The app uses SwiftUI and a single Xcode project at `apps/novels.xcodeproj`.
The scheme is `novels` and the target is iOS 26.5.
Presentation depends on domain, and domain depends on contract protocols.
Data and integrations implement contracts and do not import SwiftUI.
The local repository uses `FileManager` at `Application Support/novels/books/<slug>/`.
The cache uses `SQLite3` at `Application Support/novels/cache/processed_chapters.sqlite`.

Startup restores the session and routes to Library or Reader.
Catalog fetch uses `POST` without a body and lists exported books with download links.
AI requests use `URLSession` with `async` and `await` and retry three times with backoff (1000 ms, 2000 ms).
When the JSON is valid, the app merges `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` and ignores invalid JSON.
Full topology is in `ARCHITECTURE.md` and the contracts are in `docs/contracts/`.

Allowed flow is Presentation to Domain to Data and Integrations.
Domain does not import SwiftUI, UIKit, or WebKit.
Data does not import Presentation.
Integrations do not mutate UI state.
For dependency rules, read `ARCHITECTURE.md` section 3.

## Book Package

A valid package is a ZIP file with a fixed layout.
The archive root must contain `book.json` and a folder `chapters` with `chapter-N.html` files.
Numbering starts at one and ends at the count that `book.json` declares.
The app rejects any package that wraps the payload in an outer folder or `__MACOSX` data.
Import downloads the ZIP to a temp folder, extracts it with `FileManager.unzipItem`, and then removes the ZIP on success.
If the package is invalid, the app shows an error and creates no book entry.

Minimal `book.json` contains `id`, `name`, `author`, `count`, and `references`.
The field `id` is the slug that names the local folder and the cache key.
The field `count` must equal the length of `references`.
For the full contract, read `docs/contracts/book-package.md`.

The repo includes a tracked sample at `docs/samples/van-gioi-chi-rut-thuong-he-thong.zip`.
This sample has an outer folder and `__MACOSX` data and is not a valid fixture.
Do not use this file as a test fixture.

## Settings

The app stores settings in `UserDefaults` and wraps them with an `@Observable` store.
When a value is missing or invalid, the app restores the default on the next launch.
Unknown keys are ignored and do not change stored values.
The app sanitizes all keys on launch and applies defaults where needed.

Full canonical: docs/contracts/settings-schema.md

| Key | Type | Default | Notes |
|---|---|---|---|
| `BOOKS_API_URL` | string | `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books` | Catalog endpoint |
| `OPENAI_API_URL` | string | `http://localhost:8317/v1/chat/completions` | Single AI endpoint |
| `OPENAI_MODEL` | string | `gpt-4o` | Model name |
| `AI_PROVIDER` | string | `openai` | Only `openai` is accepted |
| `AI_CUSTOM_HEADERS` | string (JSON object) | empty | Holds `Authorization` header for auth, normal storage, invalid JSON is ignored |
| `AI_EXTRA_BODY` | string (JSON object) | empty | Merged into AI body, invalid JSON is ignored |
| `AI_PROCESS_ACTIONS` | string (JSON array) | `translate` and `summary` | Each item has `key`, `name`, and `prompt`, invalid list resets to defaults |
| `AI_MIN_CHUNK_SIZE` | number (string) | `1300` | Chunk hint in characters |
| `PREFETCH_COUNT` | number (string) | `3` | Allowed 1 to 10, else 3 |
| `font`, `fontSize`, `lineHeight`, `letterSpacing` | mixed | defaults per design | Typography for Reader, 12 to 24, 1.2 to 2.0, 0 to 1.0 |

When the value is invalid, edit validation blocks save and shows an error.
Invalid JSON for headers or body is treated as empty and the request continues.
For the full schema, read `docs/contracts/settings-schema.md`.
For security notes, read `SECURITY.md`.

## Getting Started

Follow these steps to run the app on a simulator.

1. Install Xcode 16 or later from the App Store.
2. If Homebrew is not present, install it from `https://brew.sh`.
3. Run `bash scripts/setup.sh` to install `swiftlint`, `swiftformat`, and git hooks.
4. Make sure that the command shows `swiftlint` and `swiftformat` versions.
5. Open `apps/novels.xcodeproj` in Xcode.
6. Select the scheme `novels` and the destination `iPhone 17 Pro (iOS 26.5)`.
7. Run the app on the simulator.
8. If the build fails, read the log in the Report navigator.
9. Run `./init.sh` to repeat the same steps that CI runs.

Note: The app runs without a network after you import at least one book.
Catalog and AI requests need a network, but Library and Reader work offline.

## Development

The repo uses `swiftformat` and `swiftlint` on every commit.
The pre-commit hook formats changed files and blocks commits that violate lint rules.
The script `scripts/setup.sh` installs the tools and sets `core.hooksPath` to `.githooks`.

Before you commit, run `swiftformat --lint apps --verbose` to check format.
If lint reports a problem, run `swiftformat .` or `swiftlint --fix` and review the changes.
Run `./init.sh` to repeat the same steps that CI runs.

Branch from `main` and keep changes focused on one feature.
Write commits with a clear scope and a short summary.
Open a pull request and make sure that CI passes before merge.

## Verification

The script `./init.sh` is the source of truth for verification.
It runs `swiftformat --lint apps --verbose` for format and `swiftlint lint --strict` for lint.
It then builds the scheme `novels` for `iPhone 17 Pro` on iOS 26.5.
There is no test target yet, so the test step is skipped.

Run the script locally before you push:

```
./init.sh
```

The script prints `PASS` for each phase and `Verification passed` at the end.
If a phase prints `FAIL`, correct the fault and run the script again.

## Project Structure

The repo has one Xcode project and one app module.
Product docs are in `docs/product/` and contracts are in `docs/contracts/`.
Decisions are in `docs/decisions/` and design notes are in `docs/design/`.
Work state is in `feature_index.json`, `features/`, and `progress.md`.

```
.
├── apps/
│   ├── novels.xcodeproj   # single project, scheme novels, iOS 26.5
│   └── novels/            # app module, SwiftUI, Assets, ContentView
├── docs/
│   ├── product/           # overview, domain-model, business-rules, flows, integrations
│   ├── contracts/         # catalog-api, ai-service, book-package, settings-schema, local-data
│   ├── decisions/         # ios-scope, local-persistence, book-identity, and more
│   ├── design/            # navigation, screens, design-system
│   └── samples/           # tracked sample, not a valid fixture
├── scripts/
│   └── setup.sh           # installs swiftlint, swiftformat, git hooks
├── .githooks/
│   └── pre-commit         # format and lint on commit
├── .swiftlint.yml
├── .swiftformat
├── init.sh                # format, lint, build
├── feature_index.json
├── ARCHITECTURE.md
└── SECURITY.md
```

For feature workflow, read `AGENTS.md`.

## Security

The app is single-user and single-device and has no account or cloud sync.
Library and Reader work offline after import, while catalog and AI need a network.
Auth for AI is not a separate key.
When auth is needed, it lives in `AI_CUSTOM_HEADERS`.
The app stores `AI_CUSTOM_HEADERS` with normal settings in `UserDefaults` and does not use `Keychain`.

CAUTION: Do not commit real keys, tokens, or headers.
The repo history exposes them.

Use redacted placeholders such as `{"Authorization":"Bearer ..."}` in docs and examples.
Keep values for `AI_CUSTOM_HEADERS` and `AI_EXTRA_BODY` out of docs.
For full guidance, read `SECURITY.md`.

## Troubleshooting

Reader shows blank chapter:

1. Make sure that `chapters/chapter-N.html` exists at the archive root before import.
2. If the file is missing, the import is invalid and the app creates no entry.
3. Recreate the ZIP with the correct layout and import again.

Catalog does not load:

1. Make sure that `BOOKS_API_URL` is reachable and returns a valid JSON body.
2. If the network is slow, wait and retry from the UI.
3. If the catalog reports an error, read its message and retry.

AI returns no content:

1. Make sure that `OPENAI_API_URL` and `OPENAI_MODEL` are correct in settings.
2. When the JSON for `AI_CUSTOM_HEADERS` is invalid, the app ignores it and sends no extra headers.
3. If a chunk fails, the app retries three times with backoff (1000 ms, 2000 ms) and then shows an error.

## Roadmap

Backlog & status: see feature_index.json and progress.md. Next: select next todo per feature_index.json (at most one active).

## Repository Details

**Description:** Novels — offline-first iOS reader with AI translate and summary. One ZIP import, offline read, single cache, and sequential prefetch.

**Topics:** `ios`, `swiftui`, `swift`, `offline-first`, `reader`, `novels`, `ai-translate`, `ai-summary`, `xcode`, `vietnamese`

**License:** MIT — see `LICENSE`.

**Stack:** SwiftUI, Xcode 16, iOS 26.5, Swift 5, `FileManager`, `SQLite3`, `SwiftUI.Text` (HTML→text), `URLSession`

**Language:** Vietnamese UI, English docs.

**Status:** Early docs and tooling are done. Features 001 to 008 are todo.

## License

The full text is in `LICENSE`.

Copyright 2026 Tung Doan.
The project uses the MIT License.

## Links

- Topology is in `ARCHITECTURE.md`.
- Product docs are in `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/flows.md`, `docs/product/business-rules.md`, `docs/product/glossary.md`, and `docs/product/integrations.md`.
- Design docs are in `docs/design/navigation.md`, `docs/design/screens.md`, and `docs/design/design-system.md`.
- Contracts are in `docs/contracts/index.md`, `docs/contracts/catalog-api.md`, `docs/contracts/ai-service.md`, `docs/contracts/book-package.md`, `docs/contracts/settings-schema.md`, and `docs/contracts/local-data.md`.
- Decisions are in `docs/decisions/index.md`, `docs/decisions/local-persistence.md`, `docs/decisions/book-identity.md`, and `docs/decisions/ios-scope.md`.
- Security is in `SECURITY.md`.
- Workflow is in `AGENTS.md`, `feature_index.json`, `progress.md`, and `init.sh`.

---

Written with ASD-STE100 Simplified Technical English, pragmatic mode.
For full STE rules, see the standard at `https://asd-ste100.org`.

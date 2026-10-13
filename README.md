# Novels

![iOS 26.0+](https://img.shields.io/badge/iOS-26.0%2B-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-lightgrey)
![SwiftLint](https://img.shields.io/badge/SwiftLint-required-green)
![SwiftFormat](https://img.shields.io/badge/SwiftFormat-required-green)
![License MIT](https://img.shields.io/badge/license-MIT-green)

> Offline-first reader for iPhone. Download ZIP once and read offline. Optional AI processing uses one cache (`bookId+chapterNumber+mode`).

Novels runs on iPhone only, iOS 26.0+, with Vietnamese UI. App device family is `1`. Product scope → `docs/decisions/ios-scope.md`.

## Start here

| Need | Route |
|---|---|
| Topology, layers, flows, boundaries | `ARCHITECTURE.md` |
| Product scope, entities, rules, flows | `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md`, `docs/product/flows.md` |
| Design, navigation, screens | `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md` |
| Contracts (wire and storage) | `docs/contracts/index.md` → `catalog-api.md`, `ai-service.md`, `book-package.md`, `settings-schema.md`, `local-data.md` |
| Decisions (tech + business) | `docs/decisions/index.md` + `docs/product/decisions.md`, `SECURITY.md` |
| Agent workflow, verification | `AGENTS.md`, `init.sh` |
| Roadmap and task records | [tasks/index.md](tasks/index.md); each task owns its execution state |

Use the linked document as canonical source. Do not copy its facts here.

## Repository map

```
apps/novels.xcodeproj + apps/novels/ → app (see ARCHITECTURE.md §1); docs/ → product, contracts, design, decisions; init.sh → verification
```

Details live in `ARCHITECTURE.md` §1 and §2. Verification lives in `init.sh`.

## Getting started

Prerequisite: Xcode 26+ with a Swift 6.2-capable compiler, Homebrew, and iPhone 17 Pro simulator (iOS 26.5).
The simulator version is not the minimum supported iOS version.

1. Run `bash scripts/setup.sh` to install SwiftLint, SwiftFormat, and hooks. Homebrew versions are not pinned; existing installations are retained.
2. Open `apps/novels.xcodeproj`.
3. Select scheme `novels` and destination `iPhone 17 Pro (iOS 26.5)`.
4. Run on simulator.

## Development

- Edit app Swift in `apps/novels/` and focused unit tests in `apps/novelsTests/`. No UI tests.
- Run `./init.sh --quick` during local iterations and full `./init.sh` before commit/push.
- Use task-local scope and ownership; independent tasks can run concurrently. See `AGENTS.md` and [tasks/index.md](tasks/index.md).

## Verification

- Full: `./init.sh` — format + lint + build + focused unit tests (source of truth before task completion, commit or push)
- Quick: `./init.sh --quick` (alias `-q`) — format + lint; skips build and unit tests
- Help: `./init.sh --help`

Missing SwiftFormat or SwiftLint fails verification. Checks run sequentially, report `RUN`/`PASS`/`FAIL`, and stop at the first failure.
Verification resolves the repository directory; it never fixes source or installs dependencies.
The staged-Swift hook checks format/lint only. Docs-only commits must still run full verification before commit/push.
Test scope and runtime limits → `docs/decisions/verification.md`.

## Security

Single-user, single-device, no account or sync. Do not commit real keys or headers. Use `{"Authorization":"Bearer ..."}` placeholders. Full rules → `SECURITY.md` and `docs/contracts/settings-schema.md`.

## License

MIT — see `LICENSE`. Copyright 2026 Tung Doan.

## Links

Topology → `ARCHITECTURE.md` · Product → `docs/product/overview.md` · Contracts → `docs/contracts/index.md` · Decisions → `docs/decisions/index.md` · Security → `SECURITY.md` · Workflow → `AGENTS.md`

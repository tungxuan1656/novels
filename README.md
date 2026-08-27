# Novels

![iOS 26.5](https://img.shields.io/badge/iOS-26.5-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS26-lightgrey)
![SwiftLint 0.65.1](https://img.shields.io/badge/SwiftLint-0.65.1-green)
![SwiftFormat 0.62.1](https://img.shields.io/badge/SwiftFormat-0.62.1-green)
![License MIT](https://img.shields.io/badge/license-MIT-green)

> Offline-first reader for iPhone. Download ZIP once and read offline. Optional AI translate and summary use one cache (`bookId+chapterNumber+mode`).

Novels runs on iPhone only, iOS 26+ (builds against 26.5), Vietnamese UI. Product scope → `docs/decisions/ios-scope.md`. Project still declares family `1,2`.

## Start here

| Need | Route |
|---|---|
| Topology, layers, flows, boundaries | `ARCHITECTURE.md` |
| Product scope, entities, rules, flows | `docs/product/overview.md`, `docs/product/domain-model.md`, `docs/product/business-rules.md`, `docs/product/flows.md` |
| Design, navigation, screens | `docs/design/navigation.md`, `docs/design/screens.md`, `docs/design/design-system.md` |
| Contracts (wire and storage) | `docs/contracts/index.md` → `catalog-api.md`, `ai-service.md`, `book-package.md`, `settings-schema.md`, `local-data.md` |
| Decisions (tech + business) | `docs/decisions/index.md` + `docs/product/decisions.md`, `SECURITY.md` |
| Agent workflow, verification | `AGENTS.md`, `init.sh` |
| Work state | `feature_index.json`, `features/`, `progress.md` |

Use the linked document as canonical source. Do not copy its facts here.

## Repository map

```
apps/novels.xcodeproj + apps/novels/ → app (see ARCHITECTURE.md §1); docs/ → product, contracts, design, decisions; init.sh → verification
```

Details live in `ARCHITECTURE.md` §1 and §2. Verification lives in `init.sh`.

## Getting started

Prerequisite: Xcode 16+ and iPhone 17 Pro simulator (iOS 26.5).

1. Run `bash scripts/setup.sh` to install `swiftlint 0.65.1`, `swiftformat 0.62.1`, and hooks.
2. Open `apps/novels.xcodeproj`.
3. Select scheme `novels` and destination `iPhone 17 Pro (iOS 26.5)`.
4. Run on simulator.

## Development

- Edit Swift in `apps/novels/`.
- Run `./init.sh --quick` trong lúc lặp nhanh, và `./init.sh` (full) trước khi commit.
- Keep at most one feature `active`. See `AGENTS.md` and `feature_index.json`.

## Verification

- Full: `./init.sh` — format + lint + build + test + drift (source of truth, dùng cho CI / pre-push / feature done)
- Quick: `./init.sh --quick` (alias `-q`) — chỉ format + lint + drift, skip build/test (dùng cho loop local nhanh)
- Help: `./init.sh --help`

Run `./init.sh --quick` cho feedback nhanh (vài giây). Chạy `./init.sh` full trước khi commit/push. Script in `PASS`/`SKIP`/`FAIL` per phase và `Verification passed` ở cuối. Nếu phase báo `FAIL`, fix và chạy lại.

## Security

Single-user, single-device, no account or sync. Do not commit real keys or headers. Use `{"Authorization":"Bearer ..."}` placeholders. Full rules → `SECURITY.md` and `docs/contracts/settings-schema.md`.

## License

MIT — see `LICENSE`. Copyright 2026 Tung Doan.

## Links

Topology → `ARCHITECTURE.md` · Product → `docs/product/overview.md` · Contracts → `docs/contracts/index.md` · Decisions → `docs/decisions/index.md` · Security → `SECURITY.md` · Workflow → `AGENTS.md`

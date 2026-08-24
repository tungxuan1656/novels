# ADR — iPhone-Only, iOS 26+, Vietnamese UI

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Product targets a single offline reader on iPhone; Vietnamese is the UI and AI translate target. Existing Xcode project still declares family `1,2` (iPhone+iPad) and iOS 26.5. Scope needs explicit product intent before code changes.

## Decision

- **Product scope:** iPhone only, iOS 26+; UI language Vietnamese. Design and product docs reflect this.
- **Project config:** `apps/novels.xcodeproj` family `1,2` and iOS 26.5 are **not** changed in this docs-only task (as directed). Future code task may align target to iPhone-only when needed.
- **Docs:** `docs/product/overview.md`, `docs/design/navigation.md`/`screens.md`/`design-system.md` reflect iPhone-only/Vietnamese where useful; `ARCHITECTURE.md` §1 labels observed vs. intended.

## Consequence

- No iPad layouts or multitasking variants in design scope.
- Verification stays on iPhone simulator (`iPhone 17 Pro, iOS 26.5`) per `init.sh`.

## Links

- `ARCHITECTURE.md` §1 · `docs/product/overview.md` · `docs/design/navigation.md` · `docs/design/design-system.md`

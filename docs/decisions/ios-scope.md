# ADR — iPhone-Only, iOS 26+, Vietnamese UI

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Product targets a single offline reader on iPhone. Vietnamese is the UI and AI translate target. The Xcode project still declares family `1,2` (iPhone+iPad) and iOS 26.5. Scope needs explicit product intent before code changes.

## Decision

- **Product scope:** iPhone only, iOS 26+; UI language Vietnamese. Design and product docs reflect this.
- **Project config:** `apps/novels.xcodeproj` family `1,2` and iOS 26.5 are **not** changed in this docs-only task. A future code task CAN align the target to iPhone-only when needed.
- **Docs:** `../product/overview.md`, `../design/navigation.md`/`screens.md`/`design-system.md` reflect iPhone-only/Vietnamese where useful; `../../ARCHITECTURE.md` §1 labels observed vs intended.

## Alternatives

| Option | Reason not chosen |
|---|---|
| Support iPad (`1,2`) in product scope | Requires adaptive layouts and multitasking; reader targets single-column iPhone |
| Lower iOS target to 18 | iOS 26 APIs drive the stack; backport adds testing cost |
| English UI | Product scope is Vietnamese; AI translate target is Vietnamese |

## Consequences

- No iPad layouts or multitasking variants in design scope.
- Verification stays on iPhone simulator (`iPhone 17 Pro, iOS 26.5`) per `../../init.sh`.

## Links

- `../../ARCHITECTURE.md` §1 · `../product/overview.md` · `../design/navigation.md` · `../design/design-system.md`

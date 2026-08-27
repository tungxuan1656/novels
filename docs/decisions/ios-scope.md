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

## Implementation note (feat-008)

- `TARGETED_DEVICE_FAMILY` aligned to `1` (iPhone-only) on all 6 configurations (novels / novelsTests / novelsUITests × Debug/Release); `IPHONEOS_DEPLOYMENT_TARGET 26.5` and `LSRequiresIPhoneOS=true` retained.
- `GENERATE_INFOPLIST_FILE=NO` per `ARCHITECTURE.md` — `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` / `_iPhone` build settings have no effect when generation is disabled. The authoritative gate is `apps/novels/Info.plist`: only `UISupportedInterfaceOrientations` (`Portrait`, `LandscapeLeft`, `LandscapeRight`) is kept; both `UISupportedInterfaceOrientations~iphone` (redundant when `TARGETED_DEVICE_FAMILY=1`) and `UISupportedInterfaceOrientations~ipad` are removed. This avoids divergence where one key is edited and the other is not.
- `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` count is `0` in `project.pbxproj` — correct because Tests never had it; only 2 novels configs were pruned (Debug/Release).

## Consequences

- No iPad layouts or multitasking variants in design scope.
- Verification stays on iPhone simulator (`iPhone 17 Pro, iOS 26.5`) per `../../init.sh`.

## Links

- `../../ARCHITECTURE.md` §1 · `../product/overview.md` · `../design/navigation.md` · `../design/design-system.md`

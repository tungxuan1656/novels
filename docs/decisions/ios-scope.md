# ADR — iPhone-Only, iOS 26.0+, Vietnamese UI

- **Date:** 2026-08-24
- **Status:** Accepted; current scope amended in feat-031.

## Current Scope — feat-031 Revision

The user restored the iOS 26+ scope and selected 26.0 as the minimum, superseding the earlier 18.6 amendment.

- Project, app, and unit-test Debug/Release use `IPHONEOS_DEPLOYMENT_TARGET=26.0`; app device family remains `1`.
- No current API requires a 26.5 minimum. Supporting 26.0 avoids excluding earlier iOS 26 releases without a technical reason.
- Verification stays on iPhone 17 Pro/iOS 26.5; that simulator version does not define the deployment floor.
- iOS 26.0 runtime QA remains unverified locally. Newer APIs must respect the 26.0 floor.
- Toolchain requirements and the focused unit-only policy are unchanged: [verification.md](./verification.md).

## Previous feat-031 Amendment — Historical

The user approved iPhone-only support on iOS 18.6+, with Vietnamese UI. This supersedes the original iOS 26+ floor below.

- App and project Debug/Release use `IPHONEOS_DEPLOYMENT_TARGET=18.6`; app device family is `1`.
- The app target already used 18.6. This amendment aligns product intent and project defaults; it does not lower the app target.
- The source uses a Swift 6.2-capable compiler, normally Xcode 26+. SDK/toolchain versions do not define the minimum runtime version.
- Static API review found no unguarded API above iOS 18.6. The reader's scroll APIs require iOS 18.0.
- Verification uses iPhone 17 Pro/iOS 26.5. Runtime QA on iOS 18.6 remains unverified; do not claim certification from build/API review.
- Test policy is now focused unit tests only: [verification.md](./verification.md).

## Original Decision — Historical

The remaining sections retain the original decision and feat-008 evidence. They do not define the current deployment floor or test policy.

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

- `TARGETED_DEVICE_FAMILY` aligned to `1` (iPhone-only) on the novels app configs (Debug/Release); `IPHONEOS_DEPLOYMENT_TARGET 26.5` and `LSRequiresIPhoneOS=true` retained.
- `GENERATE_INFOPLIST_FILE=NO` per `ARCHITECTURE.md` — `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` / `_iPhone` build settings have no effect when generation is disabled. The authoritative gate is `apps/novels/Info.plist`: only `UISupportedInterfaceOrientations` (`Portrait`, `LandscapeLeft`, `LandscapeRight`) is kept; both `UISupportedInterfaceOrientations~iphone` (redundant when `TARGETED_DEVICE_FAMILY=1`) and `UISupportedInterfaceOrientations~ipad` are removed. This avoids divergence where one key is edited and the other is not.
- `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` count is `0` in `project.pbxproj` — no test targets exist by decision; only the 2 novels app configs (Debug/Release) were pruned.

## Consequences

- No iPad layouts or multitasking variants in design scope.
- Verification stays on iPhone simulator (`iPhone 17 Pro, iOS 26.5`) per `../../init.sh`.

## Links

- `../../ARCHITECTURE.md` §1 · `../product/overview.md` · `../design/navigation.md` · `../design/design-system.md`

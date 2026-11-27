# macOS and iCloud Reading Progress

- Status: blocked (signed iCloud verification)
- Owner: Coding agent
- Required to start: none
- Required to integrate/release: shared CloudKit container, signed builds, and two-device verification

## Scope and acceptance

- Build the shared native SwiftUI app for iPhone and macOS.
- Open the same locally installed book on the other device and resume its latest chapter and paragraph when compatible.
- Keep local reading usable without iCloud. Never move an already open reader when remote progress changes.
- Do not sync books, caches, settings, or credentials.

## Plan

1. Enable macOS in the existing target and isolate iOS-only APIs.
2. Capture portable reading anchors and reconcile them in the shared private CloudKit database.
3. Update the platform and reader documentation. Run both builds, focused tests, and the signed-device smoke test if available.

## Verification and handoff

- Baseline: `./init.sh --quick` passes on Xcode 26.6.
- Passed `./init.sh` with Xcode 26.6: format, strict lint, iPhone 17 Pro (iOS 26.5) simulator build, unsigned native macOS build on macOS 26.5.1, and 170 unit tests (0 failures, 0 skipped).
- Release build settings resolve to macOS 26.0 and iOS 26.0; iOS stays iPhone-only (`TARGETED_DEVICE_FAMILY = 1`). These checks do not cover runtime behavior on 26.0.
- Blocker: Xcode found no Mac App Development provisioning profile for `com.tungxuan.novels`. No Apple developer account or CloudKit schema changes were made.
- Next: authorize the shared `iCloud.com.tungxuan.novels` container for both signed builds and run the [two-device smoke test](../docs/decisions/reading-progress-sync.md#provisioning-and-smoke-test). Deploy the production schema before production distribution.
- Handoff: implementation is on `feat/macos-reading-sync`, based on `bbbb985`.

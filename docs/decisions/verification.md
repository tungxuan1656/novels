# ADR — Focused Unit Verification

- **Date:** 2026-10-12
- **Status:** Accepted (feat-031; user-approved)

## Context

The previous policy deliberately removed test targets and used build-only verification. Build success cannot validate ZIP rejection, SQLite cache isolation, or AI response parsing.

Missing formatter/linter tools also produced successful SKIP tasks. Required gates must not report success without running.

## Decision

- Require SwiftFormat and SwiftLint. Missing tools fail `init.sh` and the staged-Swift pre-commit gate.
- Full `../../init.sh` runs format, lint, build, unit tests, and drift. Quick mode skips build and tests explicitly.
- Use one hosted `novelsTests` target in the shared `novels` scheme, with separate files under `apps/novelsTests/`.
- Add tests only for difficult or high-risk logic. Current suites cover ZIP ingestion/rejection, SQLite cache semantics/migration, and AI response extraction.
- Keep unit fixtures local and temporary. Tests must not depend on live services or user data.
- Detect the hosted XCTest process through `XCTestConfigurationFilePath` and bypass `AppRoot` before stores or session restoration. Check that startup guard in a separate unit file.
- Do not add UI tests, XCUITest targets, a blanket coverage requirement, CI, or a state validator in this change.

## Consequences

This supersedes the no-test/build-only policy in previous feature evidence and decisions. Historical plans and progress remain unchanged.

Full verification now requires the iPhone 17 Pro/iOS 26.5 simulator. Unit tests are not UI automation and do not certify all app behavior.

The app minimum is iOS 26.0; that runtime is not installed locally. Static availability review and newer-simulator tests do not replace runtime QA on 26.0.

The pre-commit hook applies to staged Swift files only. It is a fast gate, not a substitute for full verification before commit/push.

## Links

- [iOS scope](./ios-scope.md)
- [Architecture](../../ARCHITECTURE.md)
- [Agent rules](../../AGENTS.md)

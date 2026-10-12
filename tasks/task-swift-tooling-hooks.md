# Lint / Format Tooling & Git Hooks

- Status: done
- Owner: Tung Doan
- Required to start: none recorded.
- Required to integrate/release: none
- Previous ID: feat-009

## Scope and non-goals

Establish automatic Swift code style enforcement with SwiftLint, SwiftFormat, and a native Git pre-commit hook wired into `./init.sh` without Node or npm dependencies:
- Add `.swiftlint.yml` (rules configured for Swift 5 / iOS 26, line length 120, excluding build and DerivedData directories).
- Add `.swiftformat` configuration (`--swiftversion 5.0`, indent 4 spaces).
- Add executable versioned hook at `.githooks/pre-commit` running `swiftformat --lint` and `swiftlint lint --strict` to block non-compliant commits.
- Add `scripts/setup.sh` to install Homebrew dependencies (`swiftlint`, `swiftformat`) and configure `git config core.hooksPath .githooks`.
- Activate format and lint tasks in `./init.sh` so full verification enforces code formatting and linting rules.

Non-goals: No Node, npm, husky, or `package.json` dependencies; no SwiftPM build tool plugins; no Xcode target restructuring.

## Acceptance

- [x] `.swiftlint.yml` exists at repo root, `swiftlint lint --strict` passes on `apps/novels` (excludes Pods/build if present)
- [x] `.swiftformat` exists at repo root, `swiftformat --lint --verbose apps/novels` (or `swiftformat --lint .`) reports 0 violations after formatting
- [x] `.githooks/pre-commit` is executable, blocks commit on `swiftformat --lint` or `swiftlint` failure, auto-fixes where configured or instructs fix
- [x] `git config core.hooksPath` is documented and `scripts/setup.sh` configures it; `scripts/setup.sh` also checks/installs `swiftlint`/`swiftformat` via brew
- [x] `init.sh` `FORMAT_TASKS` and `LINT_TASKS` are uncommented/active (no SKIP) and `./init.sh` passes with lint+format+build
- [x] Existing Swift sources in `apps/novels` are formatted to the new config (no diff after `swiftformat .`)
- [x] No Node artifacts (`package.json`, `husky`, `node_modules`) added

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [init.sh](../init.sh)
- [scripts/setup.sh](../scripts/setup.sh)
- [.swiftlint.yml](../.swiftlint.yml)
- [.swiftformat](../.swiftformat)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `swiftlint lint --strict` (0 violations found); `swiftformat --lint . --verbose` (0 files require formatting); `bash scripts/setup.sh` verified hook configuration; `.githooks/pre-commit` verified blocking commits on violations; `./init.sh` completed with format PASS, lint PASS, build PASS.
- Blockers: None.
- Next: HISTORICAL: Run `bash scripts/setup.sh` for local environment setup; formatting and linting enforced via Git hooks and `./init.sh`.

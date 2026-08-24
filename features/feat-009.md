# feat-009 — Lint / Format Tooling & Git Hooks

## Goal

Establish automatic Swift convention enforcement with SwiftLint + SwiftFormat + git pre-commit hook, wired into `init.sh` and local setup, so every commit is linted/formatted consistently without Node/husky.

## Scope

- Add `.swiftlint.yml` (rules tuned for Swift 5 / iOS 26, single module `apps/novels`) and `.swiftformat` config
- Add versioned hooks at `.githooks/pre-commit` (swiftformat --lint + swiftlint lint --strict, fail on violation) and enable via `core.hooksPath`
- Add `scripts/setup.sh` to install brew deps (`swiftlint`, `swiftformat`) and configure `core.hooksPath`
- Update `init.sh` to run real `FORMAT_TASKS` (`swiftformat --lint`) and `LINT_TASKS` (`swiftlint`) when tools exist (remove SKIP placeholders)
- Optionally wire Xcode Run Script phase or document manual Xcode formatting; ensure existing sources pass after auto-format
- Update `AGENTS.md` / harness if verification commands change (no Node/husky)

## Non-goals

- No husky / Node / `package.json` / `node_modules`
- No change to `apps/novels.xcodeproj` target membership or deployment target, except optional Run Script phase
- No SwiftPM dependencies, no SwiftLint/SwiftFormat plugins as build plugins
- No large-scale refactor beyond auto-format fixes required to make lint pass

## Acceptance

- [x] `.swiftlint.yml` exists at repo root, `swiftlint lint --strict` passes on `apps/novels` (excludes Pods/build if present)
- [x] `.swiftformat` exists at repo root, `swiftformat --lint --verbose apps/novels` (or `swiftformat --lint .`) reports 0 violations after formatting
- [x] `.githooks/pre-commit` is executable, blocks commit on `swiftformat --lint` or `swiftlint` failure, auto-fixes where configured or instructs fix
- [x] `git config core.hooksPath` is documented and `scripts/setup.sh` configures it; `scripts/setup.sh` also checks/installs `swiftlint`/`swiftformat` via brew
- [x] `init.sh` `FORMAT_TASKS` and `LINT_TASKS` are uncommented/active (no SKIP) and `./init.sh` passes with lint+format+build
- [x] Existing Swift sources in `apps/novels` are formatted to the new config (no diff after `swiftformat .`)
- [x] No Node artifacts (`package.json`, `husky`, `node_modules`) added

## Relevant docs

- `AGENTS.md`
- `ARCHITECTURE.md`
- `init.sh`
- `apps/novels.xcodeproj/project.pbxproj`
- `docs/decisions/index.md`

## Plan

1. Add `.swiftlint.yml` (opt-in rules, line_length 120, disabled `todo`, `force_cast` warning, exclude `DerivedData`/`build`) and `.swiftformat` (`--swiftversion 5.0`, `--indent 4`, `--wrapself consistent`, `--stripunusedargs closure-only`)
2. Create `.githooks/pre-commit` bash hook: run `swiftformat --lint` (fail if diff) + `swiftlint lint --strict` scoped to `apps/novels`; make executable; set `git config core.hooksPath .githooks`
3. Add `scripts/setup.sh` (idempotent): `brew list swiftlint/swiftformat || brew install`, `git config core.hooksPath .githooks`, echo instructions
4. Update `init.sh`: replace SKIP with `swiftformat --lint .` and `swiftlint lint --strict --quiet` (guard with `which` or allow skip if tool missing in CI with warning); verify `MAX_JOBS` unchanged
5. Run `swiftformat .` to format repo, run `swiftlint --fix` if needed, verify `./init.sh` passes, then stage all

## Verify

- `which swiftlint && swiftlint lint --strict`
- `which swiftformat && swiftformat --lint .`
- `ls -l .githooks/pre-commit && cat .githooks/pre-commit`
- `git config --get core.hooksPath`
- `bash scripts/setup.sh`
- `./init.sh`

## Handoff

- State: done
- Evidence:
  - `.swiftlint.yml` exists; `swiftlint lint --strict` → Done linting! Found 0 violations (0.65.1)
  - `.swiftformat` exists; `swiftformat --lint . --verbose` → 0/2 files require formatting (0.62.1), `swiftformat .` → 0/2 formatted
  - `.githooks/pre-commit` executable (-rwxr-xr-x), blocks on violation (tested with BadTest.swift → format + lint errors, commit blocked; clean staged files → passed)
  - `git config --get core.hooksPath` → `.githooks` (configured via `scripts/setup.sh` and `git config core.hooksPath .githooks`)
  - `bash scripts/setup.sh` → brew swiftlint 0.65.1 / swiftformat 0.62.1 detected, hooks configured, PASS
  - `init.sh` updated: FORMAT_TASKS `swiftformat --lint . --verbose`, LINT_TASKS `swiftlint lint --strict`; `./init.sh` → format PASS, lint PASS, build PASS (xcodebuild iPhone 17 Pro iOS 26.5 quiet, warning MT IDERunDestination empty), overall Verification passed
  - `apps/novels/novelsApp.swift` renamed `novelsApp` → `NovelsApp` to satisfy `type_name`; `swiftformat .` no diff thereafter; no Node artifacts
- Blockers: none
- Next: Ready for review / merge to main; developers run `bash scripts/setup.sh` once, then `swiftformat .` and `swiftlint --fix` as needed; CI will enforce `./init.sh` lint+format+build

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->

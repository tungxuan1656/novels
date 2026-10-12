# Fastlane iOS Diawi Distribution

- Status: done
- Owner: Tung Doan
- Required to start: none recorded.
- Required to integrate/release: none
- Previous ID: feat-020

## Scope and non-goals

Configure Fastlane for automated iOS IPA builds and distribution via Diawi:
- Add `Gemfile` and `Gemfile.lock` containing the `fastlane` gem for reproducible toolchain execution.
- Create `fastlane/Appfile` specifying app identifier `com.tungxuan.novels` and Apple Team ID `M5U4E4H84J`.
- Create `fastlane/Fastfile` with iOS lanes (`prepare`, `build`, `upload`, `distribute`), targeting Xcode project `apps/novels.xcodeproj` with scheme `novels`.
- Integrate Diawi upload and polling using `curl`, reading credentials exclusively from `ENV["DIAWI_TOKEN"]` in compliance with `SECURITY.md`.
- Append Fastlane build and report output paths to `.gitignore`.

Non-goals: No Android lanes (repository is strictly iPhone-only per `docs/decisions/ios-scope.md`); no hardcoded tokens; no CI/CD pipeline automation; no App Store Connect or TestFlight publishing.

## Acceptance

- [x] `ruby -c fastlane/Fastfile` PASS.
- [x] `bundle exec fastlane lanes` lists `ios prepare`/`build`/`upload`/`distribute`.
- [x] No hardcoded token in repo (`grep DIAWI_TOKEN` only `ENV[...]`, old `5As7ju0u` 0 hits).
- [x] No android references in `fastlane/` (grep case-insensitive 0 hits).
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [SECURITY.md](../SECURITY.md)
- [docs/decisions/ios-scope.md](../docs/decisions/ios-scope.md)
- [fastlane/Fastfile](../fastlane/Fastfile)
- [fastlane/Appfile](../fastlane/Appfile)
- [Gemfile](../Gemfile)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `ruby -c fastlane/Fastfile` (Syntax OK); `bundle exec fastlane lanes` confirmed all 4 iOS lanes; grep verified zero hardcoded tokens and zero Android references; `./init.sh` full PASS.
- Blockers: None.
- Next: HISTORICAL: Export `DIAWI_TOKEN` in environment and run `bundle exec fastlane ios distribute` to distribute test builds.

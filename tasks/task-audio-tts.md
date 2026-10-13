# Configurable Sentence Audio

- Status: done
- Owner: Codex (settings slice delegated to audio-settings)
- Required to start: none; existing bilingual learning is delivered.
- Required to integrate/release: full verification and device/provider checks below.

## Scope and Non-goals

Add exactly three persistent settings: Apple/API source, separate audio API key, and audio model. Apple remains the default. API speech uses the supplied HTTPS endpoint and returns audio for the selected English sentence. Reuse the learning sheet and existing stop lifecycle. No endpoint/voice/speed settings, audio cache, background playback, whole-chapter synthesis, new dependency, or implicit Apple fallback on API failure. Preserve the user's Xcode project formatting edit.

## Acceptance

- [x] Source, key and model survive restart; invalid source defaults to Apple, blank model to the supplied model. AI settings remain independent.
- [x] API fields appear only for API; key is masked and edited securely.
- [x] Explicit sentence playback sends only model/input with Bearer auth; no credential or sentence diagnostic logging.
- [x] Apple speech stays local; API audio plays with loading/error feedback and cancels on stop, replacement, dismissal, background or reader-context change.
- [x] Errors and stale results never start unwanted playback; no automatic retries or charged live verification.
- [x] Focused settings/request/response/cancellation tests and full verification pass.

## Plan and Ownership

1. Settings worker owns AudioSource, DefaultsKeys, SettingsStore, SettingsViewModel, SettingsView, SettingEditorView and AudioSettingsTests. Parent owns all other paths; no concurrent overlap.
2. Parent adds AudioSpeechClient and request/response tests, then extends ReaderSpeech and the existing learning sheet for configurable playback and cancellation tests.
3. Update canonical speech/settings/security contracts, inspect the integrated diff, obtain an independent bounded review, and run `./init.sh` before completion/commit.

## Sources

- [Bilingual learning](../docs/product/functional-specs/bilingual-learning.md)
- [Settings](../docs/contracts/settings-schema.md)
- [Audio service](../docs/contracts/audio-service.md)
- [Security](../SECURITY.md)

## Verification and Handoff

- Evidence: `./init.sh` passed 2026-10-13: SwiftFormat, strict SwiftLint (0 violations), build and 84/84 focused tests (0 failures/skips) on iPhone 17 Pro iOS 26.5. Log: `/tmp/novels-audio-final-check.log`. Independent bounded audio/settings review: PASS, no actionable findings.
- Coverage limits: no successful decodable-audio playback test, explicit Apple/no-API transport test, or deliberately late successful response test; cancellation/replacement and undecodable audio are covered. File-only SourceKit lacks Xcode target context; integrated build is the compilation evidence.
- Blockers: none. No production credential is available; no live/paid request is planned.
- Release checks: real-device audio quality/offline Apple voice, iOS 26.0 behavior, actual provider/model response and playback.
- Next: device/provider release checks; implementation is ready for commit on `feat/bilingual-reading`. User-owned `apps/novels.xcodeproj/project.pbxproj` formatting remains uncommitted and excluded.

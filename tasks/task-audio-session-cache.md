# Sentence Audio Replay and Inline Loading

- Status: done
- Owner: Codex
- Required to start: none; configurable sentence audio is delivered.
- Required to integrate: full verification (passed).
- Required to release: device UI/audio checks remain unrun.

## Scope and Non-goals

Replace global API loading text with a spinner at the tapped Nghe speaker icon. Reuse successful API sentence audio in the running app session. Use RAM rather than temporary files so process termination drops audio without cleanup. No persistent audio, new settings, preloading, background work, retry or dependency.

## Acceptance

- [x] Only the tapped loading button spins and is disabled; other sentences remain selectable (code inspection; device appearance remains a release check).
- [x] Repeated listening and reopening the reader reuse retained audio without loading or transport.
- [x] Exact sentence and normalized model/key identify entries; stop retains them. Failed/cancelled loads are not cached.
- [x] App-session cache targets 20 MiB, allows eviction and resets on process termination.
- [x] Focused tests, canonical behavior/contracts and full verification pass.

## Sources

- [Audio contract](../docs/contracts/audio-service.md)
- [Learning behavior](../docs/product/functional-specs/bilingual-learning.md)
- [Security](../SECURITY.md)

## Plan

1. Inspect speech callers/lifecycle and existing transport tests.
2. Add inline loading and shared session RAM cache; extend focused tests for reuse, isolation, failures and eviction.
3. Review the diff, update canonical docs, run `./init.sh` and commit the bounded slice.

## Verification and Handoff

- Evidence: `./init.sh` passed format, strict lint, build and 90/90 focused unit tests on iPhone 17 Pro iOS 26.5 (2026-10-13); `/tmp/novels-audio-cache-final-check.log`. The focused AudioSpeechTests gate passed 12/12, including three new replay/cache tests. Independent bounded review passed without actionable findings.
- Diagnostics: standalone SourceKit lacks the Xcode test-module context and two probes timed out; integrated Xcode build/tests are the compilation evidence.
- Blockers: none. No live or paid API request.
- Coverage limits: actual UI/VoiceOver, real MP3/provider playback, memory pressure and iOS 26.0 device behavior remain unverified.
- Handoff: committed on `feat/bilingual-reading`; not pushed. The existing user-owned Xcode project edit is preserved and excluded.
- Next: validate inline loading, replay and audio routes on the device before release.

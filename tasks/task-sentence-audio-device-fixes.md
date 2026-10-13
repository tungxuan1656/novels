# Sentence Audio Device Fixes

- Status: done
- Owner: Codex
- Required to start: none; configurable sentence audio is delivered.
- Required to integrate/release: full verification; real-device Silent-mode and route checks remain release gates.

## Scope and Non-goals

Fix Silent-mode playback for both Apple and API speech. Clarify the learning sheet Stop control, shorten its notice, and rename Google lookup to `Tra cứu`. No background audio, new settings, dependency, provider request or unrelated reader changes. Preserve the existing local commit.

## Acceptance

- [x] Apple/API listening uses the Silent-compatible playback session; stop, completion and failures release it.
- [x] `Dừng` is visibly labelled and disabled while idle; loading remains cancellable and completed playback resets it.
- [x] Lookup says `Tra cứu`; short notices retain selected-sentence disclosure and API cost guidance.
- [x] Regression and existing focused tests, format, strict lint and build pass.

## Plan

1. Reproduce session category/mode failure with a decodable WAV fixture.
2. Fix shared session lifecycle and observable Stop state; simplify sheet labels.
3. Update contracts, obtain bounded review and run `./init.sh` before handoff.

## Sources

- [Audio contract](../docs/contracts/audio-service.md)
- [Learning behavior](../docs/product/functional-specs/bilingual-learning.md)

## Verification and Handoff

- Evidence: session regression fails before the fix (`/tmp/novels-silent-mode-red.log`). Review found stale callback address reuse; retention assertions fail before its repair (`/tmp/novels-audio-callback-red.log`). Fresh `./init.sh` passes format, strict lint, build and 87/87 tests with no failures/skips on iPhone 17 Pro iOS 26.5 (`/tmp/novels-device-audio-final-check.log`). Bounded review and focused re-review: PASS. Markdown links and `git diff --check`: PASS.
- Blockers: none.
- Coverage limits: no real-device Silent-switch audibility, Apple voice quality, audio-route or interruption check; no live/paid API request.
- Next: install the updated build and verify Apple/API listening with Silent mode enabled, then verify audio routes.

# Bilingual Reader and English Learning

- Status: done
- Owner: Codex
- Required to start: [processing](task-bilingual-processing.md)
- Required to integrate/release: manual device/provider checks in plan

## Scope and Non-goals

Typed VI/EN rendering, derived English style, sentence sheet with local speech and explicit Google lookup; stale speech/content stopped.
No word dictionary/tooltips, language-detection migration, second cache, MP3 API, separate English appearance settings or automated Google extraction.

## Acceptance

- [x] Typed VI/EN rendering, derived English style, sentence sheet with local speech and explicit Google lookup; stale speech/content stopped.
- [x] Focused tests and canonical documents updated; full verification passes.
- [x] Hardware/provider coverage limits and remaining gates disclosed.

## Sources and Plan

- [Approved feature](../docs/product/functional-specs/bilingual-learning.md).
- [Detailed implementation plan](plans/bilingual-reading.md).

## Verification and Handoff

- Evidence: `./init.sh` passes (format, strict lint, build, focused unit suites) on iPhone 17 Pro / iOS 26.5 simulator; log `/tmp/novels-bilingual-reader-check.log`. Focused suites cover font clamp, sentence segmentation, encoded Google query including literal plus, typed publication, rapid mode changes, chapter identity, corrupt cache and failed refresh fallback.
- Corrected new test fixture compile failures (settings property name and nested main-actor isolation); fresh full verification passes. Existing app isolation warnings are outside this scope.
- Independent reader review passes: no confirmed actionable issues. The pre-existing cancellation gap from data review is repaired and verified by the processing task.
- Blockers: none for implementation. Unrun release gates: real iPhone/iOS 26.0, offline voices/audio routes, five-theme typography/VoiceOver/large chapters, Google runtime and live paid providers; see plan.
- Delivery: reader implementation on `feat/bilingual-reading`; preserve unrelated project file edit and do not push.
- Final integration: `./init.sh` passes with 73/73 tests, zero failures/skips; log `/tmp/novels-bilingual-final-check.log`. Reader commit `518465e`; no push.
- Next: device/provider release gates in the plan.

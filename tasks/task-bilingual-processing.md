# Validated Bilingual Processing

- Status: done
- Owner: Codex
- Required to start: none
- Required to integrate/release: manual device/provider checks in plan

## Scope and Non-goals

Independent mode/prompt persistence, versioned ordered pairs in existing cache, atomic rejection of malformed output and legacy rewrite preservation.
No word dictionary/tooltips, language-detection migration, second cache, MP3 API, separate English appearance settings or automated Google extraction.

## Acceptance

- [x] Independent mode/prompt persistence, versioned ordered pairs in existing cache, atomic rejection of malformed output and legacy rewrite preservation.
- [x] Focused tests and canonical documents updated; full verification passes.
- [x] Hardware/provider coverage limits and remaining gates disclosed.

## Sources and Plan

- [Approved feature](../docs/product/functional-specs/bilingual-learning.md).
- [Detailed implementation plan](plans/bilingual-reading.md).

## Verification and Handoff

- Evidence: full `./init.sh` passes on 2026-10-13 (format, strict lint, app build and hosted unit tests), iPhone 17 Pro / iOS 26.5 simulator. Log: `/tmp/novels-bilingual-processing-check.log`. New payload, packing, pipeline and settings tests pass; baseline actor-isolation warnings remain.
- SourceKit standalone probes lack Xcode target context; missing-module-type findings are false positives confirmed by integrated build/tests.
- Limits: no live paid provider calls; structural validation cannot prove meaning. iOS 26.0/device behavior is not verified.
- Review repair: reproduced the pre-existing unstructured-task cancellation gap with failing delayed tests (`/tmp/novels-bilingual-cancellation-red.log`). Waiter ownership now cancels the last-consumer pipeline without cancelling live shared work; token guards protect replacement flights. Delayed miss/refresh/shared-consumer tests pass. Independent data, cancellation and reader reviews pass after repair.
- Final evidence: `./init.sh` passes all gates; 73/73 tests, zero failures/skips on iPhone 17 Pro / iOS 26.5. Log `/tmp/novels-bilingual-final-check.log`.
- Delivery: processing `d987b7b`, reader `518465e`, cancellation repair on `feat/bilingual-reading`; no push. User-owned project formatting remains uncommitted.
- Blockers: none for implementation; manual release gates remain.
- Next: device/offline-voice/accessibility/performance and live-provider gates in the plan.

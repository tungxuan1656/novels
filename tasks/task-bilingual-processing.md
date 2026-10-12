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
- Blockers: none for this task; manual release gates remain in plan.
- Next: integrate reader task; preserve old rewrite cache and user-owned project formatting.

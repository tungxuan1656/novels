# Validated Bilingual Processing

- Status: todo
- Owner: Codex
- Required to start: none
- Required to integrate/release: manual device/provider checks in plan

## Scope and Non-goals

Independent mode/prompt persistence, versioned ordered pairs in existing cache, atomic rejection of malformed output and legacy rewrite preservation.
No word dictionary/tooltips, language-detection migration, second cache, MP3 API, separate English appearance settings or automated Google extraction.

## Acceptance

- [ ] Independent mode/prompt persistence, versioned ordered pairs in existing cache, atomic rejection of malformed output and legacy rewrite preservation.
- [ ] Focused tests and canonical documents updated; full verification passes.
- [ ] Hardware/provider coverage limits and remaining gates disclosed.

## Sources and Plan

- [Approved feature](../docs/product/functional-specs/bilingual-learning.md).
- [Detailed implementation plan](plans/bilingual-reading.md).

## Verification and Handoff

- Evidence: baseline `./init.sh` passes on iPhone 17 Pro / iOS 26.5 simulator; existing actor-isolation warnings remain.
- Blockers: none for implementation; manual release gates remain.
- Next: implement models, settings and pipeline.

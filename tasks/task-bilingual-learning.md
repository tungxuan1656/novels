# Bilingual Reader and English Learning

- Status: todo
- Owner: Codex
- Required to start: [processing](task-bilingual-processing.md)
- Required to integrate/release: manual device/provider checks in plan

## Scope and Non-goals

Typed VI/EN rendering, derived English style, sentence sheet with local speech and explicit Google lookup; stale speech/content stopped.
No word dictionary/tooltips, language-detection migration, second cache, MP3 API, separate English appearance settings or automated Google extraction.

## Acceptance

- [ ] Typed VI/EN rendering, derived English style, sentence sheet with local speech and explicit Google lookup; stale speech/content stopped.
- [ ] Focused tests and canonical documents updated; full verification passes.
- [ ] Hardware/provider coverage limits and remaining gates disclosed.

## Sources and Plan

- [Approved feature](../docs/product/functional-specs/bilingual-learning.md).
- [Detailed implementation plan](plans/bilingual-reading.md).

## Verification and Handoff

- Evidence: baseline `./init.sh` passes on iPhone 17 Pro / iOS 26.5 simulator; existing actor-isolation warnings remain.
- Blockers: none for implementation; manual release gates remain.
- Next: integrate paired reader after processing task.

# AI Reading

- Status: done
- Owner: Tung Doan
- Required to start: [feat-004](task-offline-reader.md), [feat-005](task-settings-cache-manager.md)
- Required to integrate/release: none
- Previous ID: feat-006

## Scope and non-goals

Deliver cache-first AI chapter processing via an OpenAI-compatible service:
- Modes `none` (raw), `translate`, and `summary`; cache-first lookup by `(bookId, chapterNumber, mode)` in SQLite `processed_chapters.sqlite`. Note: AI modes `translate` and `summary` were later simplified to `.none` and `.rewrite` with a single prompt in [task-ai-prompt-rewrite](task-ai-prompt-rewrite.md).
- On cache miss: chunk text (~1300 characters), send `URLSession` POST requests to `OPENAI_API_URL` per chunk merging custom headers and extra body JSON.
- 3 retries (1000ms / 2000ms backoff), actor de-duplication, chunk joining, and caching result under slug identity. Note: 3 auto-retries were later superseded by bounded per-chunk retry consolidation in [task-rewrite-prefetch-correctness](task-rewrite-prefetch-correctness.md).
- Mode selection and reprocess button in the Reading bottom sheet; Vietnamese natural translation keeping honorifics, summary keeping 50-60% plot and dialogue per contract.
- Localhost ATS exception for `http://localhost:8317`.

Non-goals: No prefetch batch runner, no reader navigation changes beyond mode controls, and no settings editing UI (consumed from settings store).

## Acceptance

- [x] Cache hit returns without network; miss chunks, retries, merges, and caches under slug identity.
- [x] De-duplication prevents parallel duplicate requests for same `(bookId, chapter, mode)`.
- [x] Reprocess overwrites cache; mode switch shows cached content or triggers processing.
- [x] `AI_CUSTOM_HEADERS`/`AI_EXTRA_BODY` invalid JSON headers/body ignored at merge per `docs/contracts/ai-service.md:17`, localhost ATS `http://localhost:8317` only.
- [x] `mode == "none"` never cached.
- [x] Unit test asserts prompts contain BR-03/04 constraints (keep honorifics ta/ngươi/huynh..., natural Vietnamese 100%) and BR-05/06 (summary 50-60% keep plot/dialogue, no hallucination).

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/contracts/local-data.md](../docs/contracts/local-data.md)
- [docs/product/functional-specs/ai-reading.md](../docs/product/functional-specs/ai-reading.md)
- [docs/product/business-rules.md](../docs/product/business-rules.md)
- [apps/novels/Services/](../apps/novels/Services/)
- [apps/novels/Features/Reading/](../apps/novels/Features/Reading/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `swiftformat --lint` 0/82, `swiftlint` 0 violations, `xcodebuild test` passed 80+ tests (AIChunkerTests 4, AIPromptTests 5, AIClientTests 4, AIReadingServiceTests 6, AIReadingViewModelTests 4, AIIntegrationTests 3). `./init.sh` passed. Superseded behavior note: Multi-mode translation/summary was replaced by `.rewrite` in [task-ai-prompt-rewrite](task-ai-prompt-rewrite.md); 3 retries were replaced by bounded retry in [task-rewrite-prefetch-correctness](task-rewrite-prefetch-correctness.md). Canonical contracts route to `docs/contracts/ai-service.md` and `docs/product/functional-specs/ai-reading.md`.
- Blockers: None.
- Next: HISTORICAL: feat-007 Chapter Prefetch ready to activate.

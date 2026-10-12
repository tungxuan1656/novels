# AI Reading

Independent chapter modes: Bản gốc (`none`), Dịch (`rewrite`) and Song ngữ (`bilingual`). Detailed paired rendering/learning: [bilingual learning](bilingual-learning.md).

## Flow

1. Original renders HTML-parsed title/body without AI or cache. Other modes check `bookId + chapterNumber + mode` in the single processed-chapter cache.
2. Cache hit reuses only that mode. Rewrite reads plain text; bilingual validates/decode versioned pairs. Invalid bilingual cache fails explicitly rather than exposing JSON or borrowing rewrite.
3. On miss, process body only (first heading remains raw title). Use independent `AI_PROMPT` or `AI_BILINGUAL_PROMPT`. Chunk calls run in parallel; collect in source order. Rewrite joins text; bilingual validates exact app-assigned IDs and nonempty vi/en, then serializes one chapter JSON.
4. Save only after every chunk succeeds and cancellation check passes. Transport/envelope/final-JSON failures retry the failed chunk once; semantic pairing failures do not trigger another paid retry loop. No partial cache.
5. Reading sheet offers Chế độ đọc with the three labels and Xử lý lại for the selected non-original mode. Switching reloads cache first. Prefetch processes only the selected mode.
6. Failure toasts once and displays raw fallback, never another mode. Failed refresh leaves previous cache intact. Concurrent same-key work shares a single flight. Cancellation is silent and releases only that consumer; cancel the pipeline when no live consumer remains. A live shared consumer may still complete/cache. Generation guards prevent stale publication and old-flight cleanup.

## Rules

- Preserve `none`/`rewrite` raw values and existing rewrite cache/settings. `bilingual` adds a mode, not a database migration. Cache version remains 2; historical version-1 invalidation is unchanged.
- Prompts/results are independent. Changing prompts does not invalidate cache; manual reprocess applies only to the selected mode.
- `AI_MODE` persists app-wide, default `none`. Unknown value falls back to original.
- Structural validation does not guarantee meaning, factual accuracy or exact preservation of honorifics. No automatic language-detection repair or source mutation.

## Acceptance

- [ ] Three modes use the correct independent source and survive restart.
- [ ] Cached content requires zero current-chapter AI calls; original bypasses all AI/cache.
- [ ] Uncached paired output has exactly one vi/en pair per source ID in source order, saved atomically.
- [ ] Invalid output/version never renders as raw JSON, writes partial data or borrows another mode.
- [ ] Reprocess/prefetch respect selected mode; failed reprocess preserves prior cache.

## Links

- [Domain](../domain-model.md), [rules](../business-rules.md) BR-03..07, [flows](../flows.md) §5.
- [Wire contract](../../contracts/ai-service.md), [settings](../../contracts/settings-schema.md), [local data](../../contracts/local-data.md).
- [Local persistence](../../decisions/local-persistence.md), [book identity](../../decisions/book-identity.md).

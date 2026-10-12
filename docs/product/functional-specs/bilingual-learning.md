# Bilingual Reading and English Learning

## Modes

- The reading sheet shows `Chế độ đọc`: `Bản gốc` (`none`), `Dịch` (`rewrite`), `Song ngữ` (`bilingual`). Switching reloads the current chapter.
- Original reads source HTML without AI/cache. Translation retains `AI_PROMPT`, plain text, and existing cache entries. Bilingual has independent `AI_BILINGUAL_PROMPT` and results; neither AI mode borrows the other result.
- Reprocess replaces only the selected mode after full success. Prefetch processes only the selected mode using the same pipeline. Changing prompts does not automatically invalidate cache.
- The original chapter title stays outside AI input. Failure shows a toast and original-body fallback, never raw JSON or another mode.

## Paired Content

- The app splits source paragraphs, bounds oversized units at sentence/word boundaries, assigns chapter-wide stable IDs before packing chunks, and sends `{paragraphs:[{id,text}]}`.
- Output is `{paragraphs:[{id,vi,en}]}`: exactly one pair per source ID, without merging/splitting IDs or adding commentary. VI preserves forms of address, names, places, martial-arts terms and content. EN uses simple grammar without simplifying away details; names and designated terms retain Vietnamese spelling.
- Validate exact ID set, uniqueness and nonempty VI/EN; restore source order if the model reorders items. Missing/unknown/duplicate IDs, invalid JSON, or empty language fields fail the chapter without partial write. Structural validation cannot prove translation fidelity.
- Persist one versioned object `{version:1,paragraphs:[{id,vi,en}]}` in existing SQLite `content` under mode `bilingual`. Unknown versions/invalid cached payload fail visibly with manual reprocess available. No migration or old rewrite-cache deletion.

## Rendering and Learning

- Each VI paragraph precedes its EN counterpart. VI uses current typography. EN uses system regular, size `max(12, viSize - 2)`, the same added point line spacing, and theme muted color at full opacity. No separate English typography settings or VI-only filter within bilingual mode.
- Reading settings explain: `Tiếng Anh dùng font hệ thống, cỡ chữ nhỏ hơn và màu nhẹ hơn.` Appearance changes stay local without AI calls.
- Tap an English paragraph to open a learning sheet. Split sentences locally only on opening; each offers local speech and `Tra cứu Google · Online`. No per-word views, dictionary, automatic lookup or generated audio files. Tokenization is heuristic.
- Speech uses AVSpeechSynthesizer and an available English voice. New speech stops old speech. Stop on chapter/mode/content change, reader disappearance, sheet dismissal or backgrounding. No English voice shows an actionable unavailable message, not another-language fallback. Quality/offline availability require device verification.
- Google opens encoded HTTPS Search in SFSafariViewController in a sheet, sending only the selected sentence plus a Vietnamese explanation request. Explain that tapping sends that sentence to Google and needs internet. No scraping, guaranteed AI Overview, whole-chapter upload or custom browser session.

## Acceptance

- Modes and independent prompts survive restart; existing rewrite settings/cache still work.
- Out-of-order chunk responses yield one ordered chapter; malformed/missing pairs never yield partial cache.
- Switching/reprocessing never publishes stale content from another chapter/mode.
- Content stays readable in five themes at typography bounds; learning preserves reading gestures.
- Cached reading and available speech work offline; explicit Google lookup is online.

## Sources

- [AI reading](ai-reading.md), [reader](book-reader.md), [prefetch](chapter-prefetch.md).
- [AI contract](../../contracts/ai-service.md), [local data](../../contracts/local-data.md), [settings](../../contracts/settings-schema.md).
- [Design](../../design/design-system.md), [security](../../../SECURITY.md).

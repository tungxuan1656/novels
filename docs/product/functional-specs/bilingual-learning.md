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
- Tap an English paragraph to open a learning sheet. Split sentences locally only on opening; each offers configured Apple/API speech and `Tra cứu`. No per-word views, dictionary, automatic lookup or saved audio files. Tokenization is heuristic.
- Speech defaults to AVSpeechSynthesizer and an available English voice. Settings can select API audio with its own key/model; only tapping Nghe sends the chosen sentence, with online/cost notice, loading and error feedback. No automatic retries, audio cache or implicit Apple fallback. Explicit listening plays even in Silent mode. The visible `Dừng` text button is disabled when neither loading nor playing. Completion releases playback state and the audio session. New speech stops old speech; stop also cancels pending API work on chapter/mode/content change, reader disappearance, sheet dismissal, Google lookup, source change or backgrounding. Missing English voices show a download hint. See [audio contract](../../contracts/audio-service.md); device/provider playback remains a release check.
- Google opens encoded HTTPS Search in SFSafariViewController in a sheet, sending only the selected sentence plus a Vietnamese explanation request. Keep the privacy notice short: `Tra cứu gửi câu đến Google.` for Apple; `API/Google nhận câu; API có thể tính phí.` for API. Lookup requires internet; VoiceOver announces that requirement. No scraping, guaranteed AI Overview, whole-chapter upload or custom browser session.

## Acceptance

- Modes and independent prompts survive restart; existing rewrite settings/cache still work.
- Out-of-order chunk responses yield one ordered chapter; malformed/missing pairs never yield partial cache.
- Switching/reprocessing never publishes stale content from another chapter/mode.
- Content stays readable in five themes at typography bounds; learning preserves reading gestures.
- Cached reading and installed Apple speech work offline; API audio and explicit Google lookup are online.

## Sources

- [AI reading](ai-reading.md), [reader](book-reader.md), [prefetch](chapter-prefetch.md).
- [AI contract](../../contracts/ai-service.md), [local data](../../contracts/local-data.md), [settings](../../contracts/settings-schema.md).
- [Design](../../design/design-system.md), [security](../../../SECURITY.md).

# Bilingual Reading Implementation Plan

Approved scope: [bilingual learning](../../docs/product/functional-specs/bilingual-learning.md). Task status/evidence live only in the linked tasks.

## Delivery and Ownership

1. Planning commit: canonical feature spec, two tasks, this plan and roadmap links.
2. Data commit: [processing task](../task-bilingual-processing.md), focused tests and affected contracts/settings UI.
3. Reader commit: [learning task](../task-bilingual-learning.md), focused tests and reader/design/security docs.
4. Final bounded review/repair commit if needed. Run `./init.sh` before each commit. Do not push without a request.

Parent owns integration, pipeline, reader and canonical docs. A worker may own settings/model changes with explicit file ownership; never edit shared files concurrently. Reader integration depends on data types; settings work can proceed independently of pipeline work. Serialize verification runs.

## Compatibility and Baseline

- Branch `feat/bilingual-reading`, based on `d3ac6ae`. Preserve user-owned formatting edits in `apps/novels.xcodeproj/project.pbxproj`; exclude from commits. Filesystem-synchronized source/test groups discover new files without project changes.
- Baseline `./init.sh` passes on iPhone 17 Pro / iOS 26.5 simulator. Existing actor-isolation warnings in AIClient/AIResponse/AIRequestOptions are outside scope unless feature work depends on them.
- Keep raw keys `none` and `rewrite`; add `bilingual`. Keep SQLite user_version=2 and one cache keyed by book/chapter/mode. No migration/clear, settings reset or source-book mutation.

## Part 1: Independent Modes and Validated Pipeline

### Models and Settings

- Extend Domain/AIMode.swift with Vietnamese labels; keep Codable compatibility and default original.
- Add Sendable/Codable BilingualChapter and BilingualParagraph, version=1 and validation at decode boundary.
- Add AI_BILINGUAL_PROMPT to DefaultsKeys and SettingsStore load/sanitize/value/set/save, SettingsDefaults, SettingsViewModel editor metadata and SettingsView row. Preserve existing AI_PROMPT. Empty bilingual prompt falls back only to its own default.
- AIPromptBuilder chooses independent prompt and appends noneditable bilingual ID/pairing protocol. No configurable JSON schema setting.

### Input and Output

- Separate bilingual source packing from rewrite behavior. Reuse existing sentence/word-safe chunking for oversized units; assign IDs after splitting and before packing. Normalize source line endings and preserve order. Chunk size is a source-character hint; JSON overhead and paired output increase tokens.
- Send JSON units plus strict object schema requiring paragraphs and id/vi/en for every item. Existing provider routing selects strict schema, JSON-only or prompt-only support.
- Extend AIReadingService without duplicating cache/dedup/logging pipeline: structured request for bilingual only; validate each chunk against requested IDs, reorder, flatten by chunk order and serialize ONE versioned chapter. Rewrite still joins plain text with double newlines.
- Validate before chunk.success/cache.save. Retain existing bounded transport/JSON retry; no second retry loop or paid repair requests. Semantic ID failure may require manual reprocess. Cancellation of the last live consumer cancels the inner pipeline and prevents its write; one cancelled consumer must not cancel another live shared consumer. Failed/cancelled reprocess retains old cache.
- Validate version/fields/IDs on bilingual cache read; reject corrupt content rather than expose JSON. Cache-status/prefetch stays mode-keyed.

### Focused Tests and Checks

- Payload round trip; unknown version; empty/missing languages; duplicate/missing/extra IDs; wrong types; reordered items and exact source order across chunks.
- Source normalization; short/long paragraphs; sentence/word boundaries; globally unique IDs; whitespace-only input.
- URLProtocol fake AI: schema used for bilingual only; reverse completion order; no partial write; cache-first zero network; raw bypass; cache coexistence; failed/cancelled reprocess retains old entry; delayed cancelled miss writes nothing and cancellation preserves live-consumer deduplication. Isolated UserDefaults and in-memory SQLite.
- Settings persistence/fallback, legacy rewrite unchanged and mode restoration.
- Update ai-service/local-data/settings-schema, rules/domain/AI-reading routes, without unrelated cleanup. Run full verification; inspect/stage owned files only; commit.

## Part 2: Reader and English Learning

### Publication and Rendering

- ReaderViewModel decodes once on current-generation publication and retains typed paragraphs; reset on identity change/raw/error. Preserve generation guards for navigation/mode/reprocess. Expose pairs only for current bilingual chapter; never decode JSON in SwiftUI body.
- ReaderView selects typed pair renderer for bilingual; raw/rewrite unchanged. Keep title raw, paragraph spacing and bounded Text layers. No language guessing.
- One plain accessible Button per English paragraph opens item-driven sentence sheet; no word Buttons. Derive EN regular system font, size, added point spacing and muted color locally.
- Reading sheet shows Chế độ đọc; reprocess disabled for original/in-flight; hint explains English appearance. Adjust sheet sizing only as needed, including Dynamic Type. Preserve edge gestures and offset behavior.

### Local Speech and Online Lookup

- NaturalLanguage sentence tokenizer runs only when sheet opens. Preserve names/quotes/punctuation; fallback to full nonempty paragraph. Each sentence has accessible 44pt speech/Google controls and an explicit online/privacy note.
- Reader owns one AVSpeechSynthesizer. Use available English voice, stop previous utterance before new speech; no MP3 endpoint/files. Show voice-unavailable guidance rather than silently using another language.
- Stop speech/dismiss learning state on chapter/mode/content change, disappearance or background; stop on learning-sheet dismissal. Browser dismissal returns to learning sheet then reader.
- Google URLComponents/URLQueryItem uses https://www.google.com/search, hl=vi, chosen sentence and fixed explanation request. SFSafariViewController wrapper only; no scraping/JS/intercept/cache.

### Focused Tests and Checks

- EN font-size clamp at min/normal/max; sentence extraction with quotes/newlines/abbreviations/names and empty input.
- Google URL query round-trip with Vietnamese diacritics, quotes, ampersand, plus/newline; no whole chapter.
- Typed publication/reset and raw fallback on mode/chapter/error; stale content never shows as current.
- Update reader, screens/design system (correct point-based spacing), navigation/network/security and directly affected stale mode references.
- Full verification; independent read-only connected-code review; fix actual findings and repeat checks; commit reader slice with truthful task evidence.

## Manual Release Gates and Limits

- Simulator checks do not prove iOS 26.0 runtime or offline voices. On iPhone: cached reading/TTS in airplane mode, downloaded/missing voices, audio route/silent switch, start/stop/dismiss/background/navigation races.
- On device: min/max typography across five themes, large Dynamic Type sheet, VoiceOver, long chapter scrolling and edge-swipe coexistence.
- With selected provider: real bilingual request, low max_tokens truncation, malformed structured output and retry/cost visibility. No live billable requests or credential handling without approval.
- Google needs internet and may show normal results rather than AI Overview. Structural checks cannot verify meaning or translation accuracy.

## Recovery

- Stop at conflicting product decisions, unexpected unrelated changes or persistent failing checks; record blocker/next action in affected task.
- Before commits: full checks passed, only owned paths staged, evidence accurate. On interruption resume the selected task's next action, not completed work.
- Rollback is mode-local: choose original/rewrite. No destructive cache reset or schema downgrade required.

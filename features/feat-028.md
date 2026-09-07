# feat-028 — Title + Single Body String Reader (amended)

## Goal

Each HTML chapter becomes one optional title + one plain body string. Both raw and AI modes render the raw title on top (body font + 8, bold) plus a single body `Text`. No bold/italic emphasis anywhere. The body string IS the AI input and the AI output is a single string.

## Scope

- `apps/novels/Domain/HtmlParser.swift`: `parseChapter(html:) -> (title: String?, body: String)` replaces the blocks/spans machinery (Tasks 0–2 `parse`/`joinedBodyText` superseded).
- Delete: `apps/novels/Domain/TextSpan.swift`, `apps/novels/Features/Reading/ReaderContentView.swift` (Task 3 renderer superseded).
- `apps/novels/Features/Reading/ReaderViewModel.swift`: `blocks` → `chapterTitle`/`chapterBody`; AI input is the body directly.
- `apps/novels/Features/Reading/ReaderView.swift`: title + single `Text` per mode; sticky `【num】` + title-or-fallback chain kept.
- `apps/novels/Services/PrefetchManager.swift`: body string direct to AI.
- `apps/novels/Persistence/ProcessedChapterCache.swift`: `user_version` 1→2 one-time clear already landed (same unmerged branch — no new migration).
- Docs: `book-reader.md`, `flows.md`, `ai-reading.md`, `ai-service.md`, `local-persistence.md`, `screens.md` (spans/blocks → title + string).

## Non-goals

- No change to `br → "\n\n"` paragraph breaks, whitespace collapse, `AIChunker` budget (default 1300), or retry policy.
- No new cache migration (same branch as the v2 clear).
- Mid-chapter headings merge their text into the body (no styling, no text loss); title takes the first heading only.
- No commit/PR unless user requests.

## Acceptance

- [x] `parseChapter` returns first-heading title (nil when absent) + plain body; heading-free bodies byte-identical to the old join output.
- [x] Raw and AI modes render title (body + 8, bold, never translated) + single body `Text`; no emphasis anywhere.
- [x] No `TextBlock`/`TextSpan`/`ReaderContentView`/`fontFor`/`joinedBodyText`/`firstHeadingText` remains in Swift sources.
- [x] AI input is the body string by construction; pre-migration entries never served (v2 clear).
- [x] Docs describe title + string (no spans language); `./init.sh` full PASS; Simulator walk recorded (owner-verified on Simulator 2026-09-07).

## Relevant docs

- `docs/contracts/ai-service.md`
- `docs/product/functional-specs/ai-reading.md`
- `docs/product/functional-specs/book-reader.md`
- `ARCHITECTURE.md` §1/§5

## Plan

Separate plan: `docs/plans/feat-028.md` (Tasks 0–5 landed the exclusion + migration; Tasks 6–7 simplify to title + string per owner ruling 2026-09-07).

File ownership: single sequential writer; no parallel writers.

## Verify

- Baseline `./init.sh --quick`: PASS (2026-09-07; format PASS, lint PASS, drift PASS, build skipped)
- Full `./init.sh` (Tasks 0–5 scope): PASS (2026-09-07, single run, no flake)
- Amended scope: Tasks 6–7 re-verify (quick per task, full + walk to close)
- Task 7 pipeline-remnant grep (2026-09-07): `rg "TextBlock|TextSpan|ReaderContentView|fontFor|firstHeadingText|joinedBodyText|aiHeading" apps/novels --glob '*.swift'` → zero matches
- Task 7 docs grep (2026-09-07): no `joinedBodyText`/`firstHeadingText`/spans/blocks/helper references remain in the six updated docs (`book-reader.md`, `flows.md`, `ai-reading.md`, `ai-service.md`, `local-persistence.md`, `screens.md`)
- Task 7 full `./init.sh` (2026-09-07): PASS twice in a row, no flakes — run 1 full (format PASS, lint PASS, build PASS on iPhone 17 Pro iOS 26.5, test SKIP by decision, drift PASS 21/21); run 2 summary-confirmed identical. No re-run for infra flakes needed.
- Task 7 Simulator walk (2026-09-07): NOT PERFORMED — headless agent environment with no interactive UI driver (no test targets by decision, no tap-through harness). A booted iPhone 17 Pro (iOS 26.5) simulator exists but importing a book, driving Rewrite mode, and observing rendering/prefetch Log is impossible headless. Box 5 left unchecked pending a manual walk.

## Handoff

- State: done (owner-verified Simulator walk 2026-09-07; all acceptance boxes checked)
- Evidence: SDD Tasks 0–8 + final fix wave, all reviews clean; full `./init.sh` PASS on final HEAD (format 0/57, lint 0, build PASS iPhone 17 Pro iOS 26.5, drift PASS); owner commit `d950a72` (pbxproj ref cleanup + 32pt body bottom padding) covered by the same verify run; walk covered heading/heading-free/heading-only chapters, Rewrite + raw modes, prefetch clean
- Blockers: none
- Next: merge PR to main.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->

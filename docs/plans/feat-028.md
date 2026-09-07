# Exclude First Heading from AI Translation Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The first chapter heading is never sent to AI translation; it renders as its own raw text while the remaining body keeps the exact current join logic.

**Architecture:** Add one shared helper on `HtmlParser` that reproduces the current join+normalize bytes verbatim with an option to drop the first heading block. Both AI entry points (foreground rewrite, background prefetch) call it. The Reader AI branch prepends the raw heading above the translated body. A SQLite `user_version` bump with a one-time table clear invalidates stale header-included cache entries.

**Tech Stack:** Swift 5, SwiftUI, SQLite (`processed_chapters` via `ProcessedChapterCache`), `AIReadingService` chunk pipeline.

## Global Constraints

- iPhone only, iOS 26+, Vietnamese UI strings stay Vietnamese.
- All docs, code, and comments in English (UI strings and quoted examples excepted).
- No WebKit, no CoreData, no Keychain; `SwiftUI.Text` renders spans.
- Repo has no test targets — do NOT add XCTest/XCUITest targets or suites.
- No commit/PR unless the user explicitly requests it; leave the tree dirty for review.
- `br` stays `"\n\n"`; whitespace collapse and `AIChunker` (default 1300, range 500...10000) unchanged.
- Every task's requirements implicitly include this section.

---

## File structure

- `apps/novels/Domain/HtmlParser.swift` — owns the new shared helpers; single source of join truth.
- `apps/novels/Features/Reading/ReaderViewModel.swift` — `readRawTextForAI()` becomes a parse + helper call.
- `apps/novels/Services/PrefetchManager.swift` — prefetch join block becomes a parse + helper call (same helper, no drift).
- `apps/novels/Features/Reading/ReaderView.swift` — AI branch renders raw heading `Text` + translated body `Text`; raw mode untouched.
- `apps/novels/Persistence/ProcessedChapterCache.swift` (plus `SQLiteSupport` if it owns `user_version`) — version bump 1→2 with one-time clear.
- `docs/contracts/ai-service.md`, `docs/product/functional-specs/ai-reading.md` — input-shape and cache paragraphs updated.

Ownership: single sequential writer for all tasks (helper first, callers share its interface; no parallel writers).

---

### Task 0: Baseline

**Files:**
- Modify: none

**Interfaces:**
- Consumes: nothing
- Produces: recorded baseline result for `features/feat-028.md`

- [ ] **Step 1: Run quick verification for a baseline**

Run: `./init.sh --quick`
Expected: PASS (format PASS, lint PASS, drift PASS)

- [ ] **Step 2: Record the baseline**

Write the PASS/FAIL line into `features/feat-028.md` under `## Verify`. If FAIL, stop and report to the user instead of continuing.

---

### Task 1: Shared join helper on HtmlParser

**Files:**
- Modify: `apps/novels/Domain/HtmlParser.swift` (append at file scope, after the `HtmlParser` enum)

**Interfaces:**
- Consumes: `TextBlock` / `TextSpan` from `apps/novels/Domain/TextSpan.swift`
- Produces: `HtmlParser.joinedBodyText(from:excludingFirstHeading:) -> String?`, `HtmlParser.firstHeadingText(from:) -> String?` for Tasks 2 and 3

- [ ] **Step 1: Append the helpers verbatim**

```swift
extension HtmlParser {
    /// Raw text of the first heading block, or nil when there is none.
    /// Used to render the title separately; never sent to AI.
    static func firstHeadingText(from blocks: [TextBlock]) -> String? {
        guard let heading = blocks.first(where: { $0.isHeading }) else { return nil }
        let text = heading.spans.map { $0.text }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Body text for AI input. Byte-identical to the previous inline join
    /// when `excludingFirstHeading` is false or no heading exists.
    /// Drops ONLY the first heading block when true; mid-chapter headings stay.
    static func joinedBodyText(from blocks: [TextBlock], excludingFirstHeading: Bool = true) -> String? {
        var source = blocks
        if excludingFirstHeading, let index = source.firstIndex(where: { $0.isHeading }) {
            source.remove(at: index)
        }
        let joined = source.map { $0.spans.map { $0.text }.joined() }.joined(separator: "\n\n")
        var normalized = joined.replacingOccurrences(of: "[ \\t]*\\n[ \\t]*", with: "\n", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
```

Notes: the two `replacingOccurrences` lines are copied verbatim from `ReaderViewModel.readRawTextForAI()` — do not "simplify" them. A heading-only chapter returns nil, which makes both callers fall back to raw display (the desired outcome: heading shown untranslated).

- [ ] **Step 2: Run quick verification**

Run: `./init.sh --quick`
Expected: PASS (new code formatted and lint-clean)

---

### Task 2: Switch both AI entry points to the helper

**Files:**
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift` (`readRawTextForAI()`, ~line 358)
- Modify: `apps/novels/Services/PrefetchManager.swift` (prefetch join block, ~line 254)

**Interfaces:**
- Consumes: `HtmlParser.joinedBodyText(from:excludingFirstHeading:)` from Task 1
- Produces: heading-free `rawText` for `AIReadingService` (Task 4 relies on the new bytes)

- [ ] **Step 1: Replace `readRawTextForAI` body**

```swift
private func readRawTextForAI() -> String? {
    guard let html = readChapterHTML(number: chapterNumber) else { return nil }
    let parsed = HtmlParser.parse(html: html)
    return HtmlParser.joinedBodyText(from: parsed, excludingFirstHeading: true)
}
```

Delete the old inline `joined` / `normalized` / `trimmed` lines entirely.

- [ ] **Step 2: Replace the PrefetchManager join block**

Replace these lines:

```swift
let parsed: [TextBlock] = HtmlParser.parse(html: html)
let joined = parsed.map { $0.spans.map { $0.text }.joined() }.joined(separator: "\n\n")
var normalized = joined.replacingOccurrences(
    of: "[ \\t]*\\n[ \\t]*",
    with: "\n",
    options: .regularExpression
)
normalized = normalized.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
let raw = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
```

with:

```swift
let parsed: [TextBlock] = HtmlParser.parse(html: html)
let raw = HtmlParser.joinedBodyText(from: parsed, excludingFirstHeading: true) ?? ""
```

Keep the existing `guard !raw.isEmpty` block below it unchanged.

- [ ] **Step 3: Prove no duplicated join logic remains**

Run: `rg -n "joined\(separator: \"\\\\n\\\\n\"\)" apps/novels --glob '*.swift'`
Expected: zero matches (the only `joined(separator: "\n\n")` left is the chunk-output join in `AIReadingService.processChunks` plus the one inside the new helper)

Run: `./init.sh --quick`
Expected: PASS

---

### Task 3: Unify heading+body rendering and extract content view (amended per owner ruling 2026-09-07)

Owner ruling: the AI branch must NOT build a parallel heading+body structure — raw mode already renders heading+body through one shared path, so both modes unify on a single extracted block renderer. And the `file_length` ceiling (ReaderView 495 lines vs 500) is fixed properly by moving code OUT of `ReaderView.swift`, never by raising the lint limit.

**Files:**
- Create: `apps/novels/Features/Reading/ReaderContentView.swift` (single-block renderer shared by raw and AI modes)
- Modify: `apps/novels/Features/Reading/ReaderView.swift` (use the shared view in `content` and in the AI branch; delete the moved `fontFor`; net line count must drop)
- Modify: `apps/novels/Domain/HtmlParser.swift` (delete `firstHeadingText`, now unused after unification — the AI branch renders the heading *block*, not a string)

**Interfaces:**
- Consumes: `TextBlock`/`TextSpan` shapes; `ReaderFontMapper.font(name:size:)` and `ReaderFontMapper.font(name:size:weight:)` exactly as used today
- Produces: `ReaderContentView(block:fontName:fontSize:lineHeight:textPrimary:)` used by raw `content` and the AI branch

- [ ] **Step 1: Discard the superseded staged change**

Run: `git restore --source=HEAD --staged --worktree apps/novels/Features/Reading/ReaderView.swift`
Expected: `git status --short` shows a clean tree (the +17/−3 heading-prepend change is gone; this amended design replaces it)

- [ ] **Step 2: Create the shared block renderer moved verbatim from ReaderView**

Create `apps/novels/Features/Reading/ReaderContentView.swift`:

```swift
import SwiftUI

/// Renders one TextBlock to Text. Shared by raw mode and AI mode so a
/// heading looks identical in both. Pure view of its inputs: no store access.
struct ReaderContentView: View {
    let block: TextBlock
    let fontName: String
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let textPrimary: Color

    var body: some View {
        combined
            .lineSpacing(lineHeight)
            .multilineTextAlignment(.leading)
    }

    private var combined: Text {
        block.spans.reduce(Text("")) { accumulator, span in
            if span.isLineBreak {
                return accumulator + Text(span.text)
            }
            var piece = Text(span.text)
                .font(fontFor(block: block, span: span))
                .foregroundStyle(textPrimary)
            if span.kind == .bold || span.kind == .boldItalic {
                piece = piece.bold()
            }
            if span.kind == .italic || span.kind == .boldItalic {
                piece = piece.italic()
            }
            return accumulator + piece
        }
    }

    private func fontFor(block: TextBlock, span: TextSpan) -> Font {
        if block.isHeading {
            let level = CGFloat(block.headingLevel ?? 3)
            let size = fontSize + CGFloat(7 - level) * 2
            return ReaderFontMapper.font(name: fontName, size: size, weight: .bold)
        }
        return ReaderFontMapper.font(name: fontName, size: fontSize)
    }
}
```

The `combined`/`fontFor` bodies are moved verbatim from ReaderView's `content`/`fontFor`; only the `settingsStore`/`theme` reads become the four init params.

- [ ] **Step 3: Rewire ReaderView to the shared view and delete the moved code**

In `content`, replace the inline reduce with:

```swift
ForEach(Array(viewModel.blocks.enumerated()), id: \.offset) { _, block in
    ReaderContentView(
        block: block,
        fontName: settingsStore.typography.font,
        fontSize: CGFloat(settingsStore.typography.fontSize),
        lineHeight: CGFloat(settingsStore.typography.lineHeight),
        textPrimary: theme.textPrimary
    )
}
```

Delete ReaderView's private `fontFor(block:span:)` (it now lives in the new file).

In the AI branch that currently renders `aiProcessedContent(processed)`, render:

```swift
if let heading = viewModel.blocks.first(where: { $0.isHeading }) {
    ReaderContentView(
        block: heading,
        fontName: settingsStore.typography.font,
        fontSize: CGFloat(settingsStore.typography.fontSize),
        lineHeight: CGFloat(settingsStore.typography.lineHeight),
        textPrimary: theme.textPrimary
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityIdentifier("aiHeading")
}
aiProcessedContent(processed)
```

When there is no heading, output is exactly one `Text` as before. The heading is never passed into the translated string.

- [ ] **Step 4: Delete the now-unused `firstHeadingText` helper**

Delete `HtmlParser.firstHeadingText(from:)` from the Task 1 extension, keeping `joinedBodyText` untouched.

- [ ] **Step 5: Prove unification, size, and cleanliness**

Run: `rg -n "firstHeadingText" apps/novels --glob '*.swift'`
Expected: zero matches

Run: `wc -l apps/novels/Features/Reading/ReaderView.swift`
Expected: at most 500 lines (must drop from 495, not grow)

Run: `rg -n "private func fontFor" apps/novels --glob '*.swift'`
Expected: exactly one match, in `ReaderContentView.swift`

Run: `./init.sh --quick`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add apps/novels/Features/Reading/ReaderContentView.swift apps/novels/Features/Reading/ReaderView.swift apps/novels/Domain/HtmlParser.swift
git commit -m "feat(feat-028): unify heading render via extracted content view"
```

---

### Task 4: Invalidate stale header-included cache entries

**Files:**
- Modify: `apps/novels/Persistence/ProcessedChapterCache.swift` (and `SQLiteSupport` only if it owns the `PRAGMA user_version` open path)

**Interfaces:**
- Consumes: heading-free bytes from Task 2 (same `(book_id, chapter_number, mode)` key now maps to new content)
- Produces: guarantee that pre-migration rows are never served

- [ ] **Step 1: Read the open/migrate path**

Open `ProcessedChapterCache.swift` and find where `user_version` is read/created (currently version 1, table `processed_chapters`).

- [ ] **Step 2: Bump to version 2 with a one-time clear**

On open, when `PRAGMA user_version` is 1, execute exactly:

```sql
DELETE FROM processed_chapters;
```

then set `PRAGMA user_version = 2;`. Fresh installs create the schema at version 2 directly with no delete. Do not change the table schema, the key format, or the `mode == .none` never-cache rule.

- [ ] **Step 3: Prove the migration hook exists**

Run: `rg -n "user_version" apps/novels --glob '*.swift'`
Expected: matches showing the version-1→2 branch with the `DELETE FROM processed_chapters` statement

Run: `./init.sh --quick`
Expected: PASS

---

### Task 5: Docs, full verification, and feature record

**Files:**
- Modify: `docs/contracts/ai-service.md` (input-shape paragraph: AI input is heading-free body; cache paragraph: entries invalidated by the version-2 migration)
- Modify: `docs/product/functional-specs/ai-reading.md` (same two facts in product language)
- Modify: `features/feat-028.md` (`## Verify` evidence, `## Handoff` state)

**Interfaces:**
- Consumes: finished behavior from Tasks 1–4
- Produces: closed feature record with evidence

- [ ] **Step 1: Update the two docs**

Keep each change to 2–4 sentences next to the existing join/cache paragraphs. English prose, sentence length within repo doc style. No other doc touched.

- [ ] **Step 2: Run full verification**

Run: `./init.sh`
Expected: PASS (format + lint + build + drift). If the run flakes on Simulator load (known `RequestDenied`/bundle-instance flakes in this repo's history), re-run once and record both runs.

- [ ] **Step 3: Simulator walk**

On a chapter WITH a heading, in Rewrite mode: heading shows raw above the body, body contains no heading text, sticky title unchanged. On a heading-free chapter: single translated body exactly as before. Trigger prefetch over both chapters and confirm the Log shows no new errors. Record the walk outcome in `features/feat-028.md`.

- [ ] **Step 4: Close the feature record**

Set all acceptance boxes, write evidence (init run, greps, walk), set handoff state to done with one next action. Do not touch `progress.md` here — the session-closing flow owns it.

---

### Task 6: Simplify to title + single body string (amended per owner ruling 2026-09-07)

Owner ruling: drop the blocks/spans pipeline entirely. Each HTML chapter becomes one optional title + one plain body string; raw and AI modes both render title + single `Text`; no bold/italic anywhere. This supersedes the Task 3 block renderer (deleted here). Title size = body font size + 8, bold. Mid-chapter heading text merges into the body (no styling, no text loss per BR-04).

**Files:**
- Modify: `apps/novels/Domain/HtmlParser.swift` (replace block machinery with `parseChapter`)
- Delete: `apps/novels/Domain/TextSpan.swift`, `apps/novels/Features/Reading/ReaderContentView.swift`
- Modify: `apps/novels/Features/Reading/ReaderViewModel.swift` (`blocks` → `chapterTitle`/`chapterBody`)
- Modify: `apps/novels/Features/Reading/ReaderView.swift` (title + single `Text` per mode)
- Modify: `apps/novels/Services/PrefetchManager.swift` (body string direct to AI)

**Interfaces:**
- Consumes: `Chapter` HTML via existing `readChapterHTML` paths
- Produces: `HtmlParser.parseChapter(html:) -> (title: String?, body: String)`; VM publishes `chapterTitle: String?`, `chapterBody: String`; AI input IS the body string (no join step remains)

- [ ] **Step 1: Rewrite the parser to emit title + body**

Replace `parse(html:)`, `joinedBodyText`, and all span/block accumulators with:

```swift
static func parseChapter(html: String) -> (title: String?, body: String) {
    // Single pass over the existing char loop: first h1-h6 text run wins the
    // title (trimmed, nil when empty); every text run — including mid-chapter
    // headings and b/i content as plain text — appends to the body.
    // Keep verbatim: collapseWhitespace, decodeEntities, script/style skip,
    // br and p/div/h-close emitting "\n\n" with line-break dedup and no
    // leading/trailing breaks, final "\n{3,}" -> "\n\n" normalize + trim.
}
```

Reuse the two `replacingOccurrences` normalize lines verbatim from the deleted helper. For heading-free chapters the body is byte-identical to the old `joinedBodyText` output. Delete `apps/novels/Domain/TextSpan.swift` (whole file).

- [ ] **Step 2: ViewModel holds strings, not blocks**

Replace `blocks: [TextBlock]` storage and all three parse sites (`load()`, `setAIMode(.none)`, `readRawTextForAI()`) with `chapterTitle: String?` + `chapterBody: String` from `parseChapter`. `readRawTextForAI()` returns the body, nil when empty (same empty contract as before).

- [ ] **Step 3: Render title + single Text per mode**

Sticky header keeps the existing `【num】` + title-or-fallback chain, title font = `ReaderFontMapper` body font at `fontSize + 8`, bold. One shared modifier set for body text in both modes:

```swift
private func bodyText(_ text: String) -> some View {
    Text(text)
        .font(ReaderFontMapper.font(name: settingsStore.typography.font, size: CGFloat(settingsStore.typography.fontSize)))
        .foregroundStyle(theme.textPrimary)
        .lineSpacing(CGFloat(settingsStore.typography.lineHeight))
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

Raw body = `bodyText(viewModel.chapterBody)`; AI body = `bodyText(viewModel.processedContent ?? viewModel.chapterBody)` keeping `.accessibilityIdentifier("aiContent")` on the AI call site only. Delete the old `content` reduce, `aiProcessedContent`, and any remaining `fontFor`.

- [ ] **Step 4: Prefetch uses the body directly**

Replace the `HtmlParser.parse` + `joinedBodyText` block with `let chapter = HtmlParser.parseChapter(html: html)` and `let raw = chapter.body`, keeping the existing empty-content message flow and everything below it unchanged.

- [ ] **Step 5: Prove the pipeline is gone and the tree is clean**

Run: `rg -n "TextBlock|TextSpan|ReaderContentView|fontFor|firstHeadingText|joinedBodyText|aiHeading" apps/novels --glob '*.swift'`
Expected: zero matches (unrelated `combined` in `AIResponse.swift`/`ToastView.swift` is out of scope and stays)

Run: `wc -l apps/novels/Features/Reading/ReaderView.swift`
Expected: at most 500 lines

Run: `./init.sh --quick`
Expected: PASS

- [ ] **Step 6: Commit (explicit paths only — never `git add -A`)**

```bash
git add apps/novels/Domain/HtmlParser.swift apps/novels/Domain/TextSpan.swift apps/novels/Features/Reading/ReaderContentView.swift apps/novels/Features/Reading/ReaderView.swift apps/novels/Features/Reading/ReaderViewModel.swift apps/novels/Services/PrefetchManager.swift
git commit -m "feat(feat-028): simplify reader to title plus single body string"
```

Verify with `git status` that `project.pbxproj` is NOT staged.

---

### Task 7: Docs delta, full verification, walk, close

**Files:**
- Modify: `docs/product/functional-specs/book-reader.md`, `docs/product/flows.md`, `docs/product/functional-specs/ai-reading.md`, `docs/contracts/ai-service.md`, `docs/decisions/local-persistence.md`, `docs/design/screens.md` (spans/blocks/helper language → title + single body string)
- Modify: `features/feat-028.md` (new acceptance evidence, handoff done)

**Interfaces:**
- Consumes: finished behavior from Task 6
- Produces: closed feature record with full evidence

- [ ] **Step 1: Update the six docs**

Rewrite the spans/blocks/join paragraphs to title + single body string (2–4 sentences each, beside existing paragraphs). Remove references to `joinedBodyText`/`firstHeadingText`/spans; state that AI input is the body string by construction and the title is never translated. English prose.

- [ ] **Step 2: Run full verification**

Run: `./init.sh`
Expected: PASS (format + lint + build + drift). On known Simulator-load flakes, re-run once and record both runs.

- [ ] **Step 3: Simulator walk**

Chapter WITH heading in Rewrite mode: sticky shows `【num】` + raw title at body+8 bold, body is one translated text block with no heading text; heading-free chapter: single translated body as before; raw mode: title + one body text, no emphasis anywhere. Trigger prefetch over both chapters, Log shows no new errors. Record outcome in `features/feat-028.md`.

- [ ] **Step 4: Close the feature record**

Set all acceptance boxes per the amended scope, write evidence, set handoff state to done with one next action. Do not touch `progress.md` here.

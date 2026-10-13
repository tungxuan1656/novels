# Screens — Novels

> **Scope owner:** This file owns the screen inventory and per-screen behavior. For graph see [navigation.md](./navigation.md), flows see [../product/flows.md](../product/flows.md), overview see [../product/overview.md](../product/overview.md). iPhone only, Vietnamese UI — see [ARCHITECTURE.md](../../ARCHITECTURE.md).

## 1. Screen Map

Map → [navigation.md](./navigation.md) §1. Shared container with safe area, header, divider, and content. Footer only on Setting Editor.

## 2. Screen Inventory

| Screen | Purpose | Key Elements | States | Transitions |
|---|---|---|---|---|
| **Home Library** | Browse books | Header with add and settings; row with name, author, count | Empty (add prompt), Content, Refreshing | Tap → Reading; swipe Info/Delete; add → Add Book |
| **Add Book** | Import book | Header back; remote list; download overlay | Loading, Empty, Error (retry), Downloading | Pick → download → unzip → back |
| **Reading** | Read and navigate | Header index+title+status; raw title (body + 8, bold) above native paragraph text or ordered VI/EN pairs; English paragraph opens sentence learning; back; prev/next; to-bottom; sheet button | Loading, Content, Error | Prev/Next in place; scroll saves offset; index → References |
| **References** | Jump chapter | Header back; title list; current bold | Content at current index, Empty | Tap → set chapter → back |
| **Settings** | Edit config | Header; grouped list, Audio source with API-only key/model; cards for data | Content | Row → Editor; Data → Cache |
| **Cache Manager** | Inspect and clear saved AI versions | Saved-version/distinct-chapter counts; expandable book → chapter/mode/update time; existing clear actions | Loading, Content, Empty, Error | Clear → confirm → toast |
| **Setting Editor** | Edit one value | Header; description; input; Clear/Save | Content, Error, Success | Save → validate → back |
| **Log** | Diagnose AI-processing runs | Book/chapter/mode rows; source/duration/progress/cause; status/mode filters; request attempts and RAM-only JSON | Content, Empty, No-match | Reading sheet → Log; Log → Cache Manager; back |

## 3. Shared Patterns

**Bottom Sheet.** Overlay on Home and Reading. Sheet slides up and backdrop dims. Drag down or tap backdrop to close. Reading sheet includes:
- Font picker
- Inline "Chế độ đọc" picker: Bản gốc / Dịch / Song ngữ; "Xử lý lại" applies to the selected processed mode only
- In Song ngữ, show primary/secondary language status and a full-width `Đổi ngôn ngữ chính` button with swap icon. A hint explains secondary styling and tapping English for learning; see [bilingual learning](../product/functional-specs/bilingual-learning.md).
- Steppers for size and line height
- Log button ("Nhật ký") below AI section → push Log timeline for the current book. "Xem lỗi" selects failed runs when errors are present. Filters select whole runs and never strip sibling requests or retries.
Gear opens Settings.

**English Learning Sheet.** Tap an English paragraph to choose a sentence. "Nghe" uses configured Apple speech or "Nghe · Online" uses API audio with privacy/cost notice and loading/error feedback; the text-only "Dừng" button cancels loading and stops playback, and is disabled when idle. "Tra cứu" opens Google in a nested system browser sheet only after a tap. Keep the privacy/cost notice to one short sentence; do not truncate it at accessibility text sizes. See [bilingual-learning](../product/functional-specs/bilingual-learning.md).

**Diagnostic Log.** One row per AI-processing run, newest first: book/chapter/mode, reader/prefetch/manual source, duration, chunk progress and outcome. Cache-only reads and general queue events are omitted. Cancelled is separate from failed; a short cause includes chunk and attempt when available. Expand for one outcome per API attempt, validation failures and shared-request context; retries remain visible. Technical codes, sanitized endpoint and model are available in detail. Search matches whole runs by safe labels/codes, never raw bodies. JSON remains RAM-only. HTTP 200 alone does not mean valid bilingual output.

**Cache Inventory.** The existing Cache Manager reads SQLite metadata, not diagnostics history. Counts distinguish saved chapter/mode versions from distinct chapters. Expand each book title/slug for ordered chapter, mode and update time. Pull to refresh; opening/query/deletion errors are explicit. Existing per-book/all deletes require confirmation and do not delete the original book.

**Swipe Row.** Home only. Swipe left shows Info (blue, external link) and Delete (red, confirm then remove). Actions close swipe on tap. Cancel keeps data.

**Toast.** Top and global. Colors:
- Success uses green
- Error uses red
- Info uses blue
- Warning uses orange
Duration is 3s for <60 chars, 4s for <150 chars, and 5s for long text. Tap to dismiss. Toast shows import, delete, validation, and network errors.

**Loading.** Inline spinner for lists; blocking overlay for download and clear. Reading rules:
- No loading indicator inside the Reading content body and none inside the Reading bottom sheet.
- The only Reading rewrite indicator is a small spinner in the top header, left of the prev/next cluster, visible only while the current chapter itself is being rewritten — never for background prefetch chapters.
- Chapter failure toasts once and renders the raw fallback; prefetch failure is silent in Reading (badge + timeline in Log only).

## 4. Rules

- Chapter is 1-based, clamp 1..total.
- Offset per book, restore only for same `bookId`. New chapter starts at top.
- Delete needs confirm.
- Mode switch reloads in place.
- Prefetch status is read-only.

## 5. Cases

| Case | Result |
|---|---|
| ZIP missing files | Fail, no entry, error |
| Invalid AI headers/body JSON | Ignored, request proceeds without merge |
| Empty Prompt | Fallback to default prompt (BR-12) |
| No network on Add Book | Error, pull to retry |
| Empty chapters | Empty state, nav disabled |

## Links

- Navigation: [navigation.md](./navigation.md) · Design System: [design-system.md](./design-system.md) · Flows: [../product/flows.md](../product/flows.md) · Overview: [../product/overview.md](../product/overview.md)

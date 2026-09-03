# Screens — Novels

> **Scope owner:** This file owns the screen inventory and per-screen behavior. For graph see [navigation.md](./navigation.md), flows see [../product/flows.md](../product/flows.md), overview see [../product/overview.md](../product/overview.md). iPhone only, Vietnamese UI — see [ARCHITECTURE.md](../../ARCHITECTURE.md).

## 1. Screen Map

Map → [navigation.md](./navigation.md) §1. Shared container with safe area, header, divider, and content. Footer only on Setting Editor.

## 2. Screen Inventory

| Screen | Purpose | Key Elements | States | Transitions |
|---|---|---|---|---|
| **Home Library** | Browse books | Header with add and settings; row with name, author, count | Empty (add prompt), Content, Refreshing | Tap → Reading; swipe Info/Delete; add → Add Book |
| **Add Book** | Import book | Header back; remote list; download overlay | Loading, Empty, Error (retry), Downloading | Pick → download → unzip → back |
| **Reading** | Read and navigate | Header index+title+status; native Text body (parsed from HTML); back; prev/next; to-bottom; sheet button | Loading, Content, Error | Prev/Next in place; scroll saves offset; index → References |
| **References** | Jump chapter | Header back; title list; current bold | Content at current index, Empty | Tap → set chapter → back |
| **Settings** | Edit config | Header; grouped list; cards for data | Content | Row → Editor; Data → Cache |
| **Cache Manager** | Clear AI cache | Header; count card; clear button; note | Content, Processing | Clear → confirm → toast |
| **Setting Editor** | Edit one value | Header; description; input; Clear/Save | Content, Error, Success | Save → validate → back |
| **Log** | Diagnose AI/prefetch timeline | Header; filter chips; group toggle; expandable rows | Content, Empty, No-match | Reading sheet → Log → back |

## 3. Shared Patterns

**Bottom Sheet.** Overlay on Home and Reading. Sheet slides up and backdrop dims. Drag down or tap backdrop to close. Reading sheet includes:
- Font picker
- Inline AI Rewrite picker ("AI Rewrite": Không / Rewrite) with Reprocess button ("Xử lý lại") positioned right beside it in the same row
- Steppers for size, line height, and letter spacing
- Log button ("Nhật ký") below AI section → push Log timeline
Gear opens Settings.

**Swipe Row.** Home only. Swipe left shows Info (blue, external link) and Delete (red, confirm then remove). Actions close swipe on tap. Cancel keeps data.

**Toast.** Top and global. Colors:
- Success uses green
- Error uses red
- Info uses blue
- Warning uses orange
Duration is 3s for <60 chars, 4s for <150 chars, and 5s for long text. Tap to dismiss. Toast shows import, delete, validation, and network errors.

**Loading.** Inline spinner for lists; blocking overlay for download, AI, and clear.

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

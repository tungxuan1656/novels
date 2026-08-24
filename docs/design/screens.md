# Screens — rn-read-books

> **Scope owner:** This file owns the screen inventory and per-screen behavior. For graph see [navigation.md](./navigation.md), flows see [../product/flows.md](../product/flows.md), overview see [../product/overview.md](../product/overview.md).

## 1. Screen Map

Seven screens plus overlays. Shared container with safe area, header, divider, content. Footer only on Setting Editor.

```
Home Library -> Add Book, Reading, Settings
Reading -> References, Settings (via sheet)
Settings -> Cache Manager, Network Logger, Setting Editor
Overlays: Bottom Sheet, Toast, Loading
```

## 2. Screen Inventory

| Screen | Purpose | Key Elements | States | Transitions |
|---|---|---|---|---|
| **Home Library** | Browse books | Header with add and settings; row with name, author, count | Empty (add prompt), Content, Refreshing | Tap → Reading; swipe Info/Delete; add → Add Book |
| **Add Book** | Import book | Header back; remote list; download overlay | Loading, Empty, Error (retry), Downloading | Pick → download → unzip → back |
| **Reading** | Read and navigate | Header index+title+status; HTML body; back; prev/next; to-bottom; sheet button | Loading, Content, Error | Prev/Next in place; scroll saves offset; index → References |
| **References** | Jump chapter | Header back; title list; current bold | Content at current index, Empty | Tap → set chapter → back |
| **Settings** | Edit config | Header; grouped list; cards for data/logger | Content | Row → Editor; Data → Cache; Logger → Logger |
| **Cache Manager** | Clear AI cache | Header; count card; clear button; note | Content, Processing | Clear → confirm → toast |
| **Setting Editor** | Edit one value | Header; description; input; Clear/Save | Content, Error, Success | Save → validate → back |

## 3. Shared Patterns

**Bottom Sheet.** Overlay on Home and Reading. Slides up, backdrop dims, drag down or tap backdrop to close. Reading sheet has font picker, mode switch (none/translate/summary), reprocess (disabled if none), and steppers for size, line height, letter spacing. Gear opens Settings.

**Swipe Row.** Home only. Swipe left shows Info (blue, external link) and Delete (red, confirm then remove). Actions close swipe on tap. Cancel keeps data.

**Toast.** Top, global. Success green, error red, info blue, warning orange. Duration 3s (<60 chars), 4s (<150), 5s (long). Tap to dismiss. For import, delete, validation, network errors.

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
| Bad JSON for AI Actions | Block save, error |
| No network on Add Book | Error, pull to retry |
| Empty chapters | Empty state, nav disabled |

## Links

- Navigation: [navigation.md](./navigation.md) · Design System: [design-system.md](./design-system.md) · Flows: [../product/flows.md](../product/flows.md) · Overview: [../product/overview.md](../product/overview.md)

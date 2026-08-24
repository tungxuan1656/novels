# Navigation — Novels

> **Scope owner:** This file owns the screen graph and navigation rules. For screen details see [screens.md](./screens.md), flows see [../product/flows.md](../product/flows.md), overview see [../product/overview.md](../product/overview.md). iPhone only, Vietnamese UI — see [ARCHITECTURE.md](../../ARCHITECTURE.md) and [../decisions/ios-scope.md](../decisions/ios-scope.md).

## 1. Navigation Map

Single stack, no tabs. Home Library is root. Reading can be first screen on resume. Overlays (toast, bottom sheet, loading) sit above stack.

```
[Startup] --> Home Library
Home Library --> Add Book
Home Library --> Reading (bookId)
Home Library --> Settings
Reading --> References
Reading --> Settings (via sheet shortcut)
Settings --> Cache Manager
Settings --> Setting Editor (settingKey)
Add Book --back--> Home Library
References --select--> Reading
```

## 2. Entry and Startup Resume

Startup restores session and settings from local store. Show splash while fonts load.

- If `onScreen = true` and `bookId` is valid → push Reading with that `bookId`, restore saved scroll offset after content loads.
- If `onScreen = false` or no session → show Home Library.
- No network at startup. Invalid or missing values use defaults.

## 3. Stack Structure

Abstract stack:

- Root: Home Library. Back at root exits app.
- Push: Add Book, Reading, References, Settings, Cache Manager, Setting Editor.
- Pop: header back or system back goes one level up. Reading back clears `onScreen`.
- Reading disables swipe-back to avoid loss of position. Others allow it.
- Bottom sheet is not a route; it is an overlay that expands over Home or Reading.

## 4. Route Params

- **Reading:** requires `bookId: string`. Chapter comes from book state, not URL. Offset is per book.
- **References:** reads `bookId` from active session. No param.
- **Setting Editor:** requires `settingKey`, `label`, `placeholder`. Optional `description`, `multiple=true` for multi-line.
- Others have no params. Missing required param shows toast and stays on current screen.

## 5. Navigation Rules

- Home tap row → Reading, sets `onScreen=true` and saves `bookId`.
- Reading back → Home, sets `onScreen=false` and saves offset.
- Chapter change stays in Reading; scroll resets to top; new chapter uses its own offset.
- References tap → update current chapter for that `bookId` → pop to Reading.
- Add Book success → pop to Home and refresh list.
- Settings edit → persist at once. Invalid input blocks save and shows error.
- Swipe on Home reveals actions but does not navigate.

## 6. Cases

| Case | Result |
|---|---|
| Killed on Reading | Next launch resumes same book |
| Invalid `bookId` | Error toast, return to Home |
| Rapid double push | Ignore second until first done |
| Missing param | Reject, toast, no navigation |
| Deep link to unknown route | Stay on current, toast |

## Links

- Screens: [screens.md](./screens.md) · Flows: [../product/flows.md](../product/flows.md) · Overview: [../product/overview.md](../product/overview.md) · Domain: [../product/domain-model.md](../product/domain-model.md)

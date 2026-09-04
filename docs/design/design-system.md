# Design System — Novels

> **Scope owner:** This file owns visual and interaction invariants. For screens see [screens.md](./screens.md), navigation see [navigation.md](./navigation.md), overview see [../product/overview.md](../product/overview.md). UI language is Vietnamese (iPhone only) — see [ARCHITECTURE.md](../../ARCHITECTURE.md) and [../decisions/ios-scope.md](../decisions/ios-scope.md).

## 1. Token Map

Abstract tokens, not code classes.

```
Colors: background / surface / text / muted / accent / success / warning / error / border
Type: family / size / weight / lineHeight / letterSpacing
Space: 4 / 8 / 12 / 16 / 24 / 32
Radius: 8 / 12 / 16 / 24 pill
Elevation: flat / raised / overlay
```

## 2. Color Semantics

Tokens map to values and uses.

- **background (reading)** — trio theo `ReadingTheme` (feat-021, code canonical): Vàng giấy `#F5F1E5` (mặc định), Trắng `#FFFFFF`, Đen `#171512`. Drift `#FDFCF8` trong docs cũ đã resolved về `#F5F1E5` theo code `DesignTokens.swift`. `headerBg` trùng `background` để liền mạch khi cuộn.
- **background (non-reading)** — #FFFFFF white for Library and Settings, #F5F5F5 light gray for grouped sections
- **surface** — #FFFFFF for cards and sheets (non-reading; reading sheet dùng `ultraThinMaterial` + forced scheme theo theme)
- **text (reading)** — theo theme: Vàng/Trắng `#111111`, Đen `#ECE7DF` (trắng ấm, không dùng `#FFFFFF` để đỡ lóa). Body contrast AAA (~12–19:1).
- **text (non-reading)** — #111111 near-black for titles
- **muted/icon (reading)** — theo theme: Vàng/Trắng `#6B7280`, Đen `#A8A29E` (`#6B7280` trên nền đen chỉ ~3.2:1 nên bắt buộc sáng lên để đạt AA ~6:1)
- **muted (non-reading)** — #6B7280 for meta and hints
- **chip (reading)** — Vàng `#E8DDC0`, Trắng `#EFEFF1`, Đen `#2A2724`
- **border (reading)** — Vàng `#DCD2B6`, Trắng `#E5E7EB`, Đen `#3B3732`; divider trong sheet dùng theme border
- **accent (reading)** — Vàng/Trắng `#2563EB`, Đen `#60A5FA` (`#2563EB` trên nền đen chỉ ~3.3:1 nên đổi riêng để đạt AA)
- **accent (non-reading)** — #2563EB blue for active states and info
- **success** — #16A34A green for confirm and enabled
- **warning** — #EA580C orange for warnings
- **error** — #DC2626 red for delete and errors
- **border (non-reading)** — #E5E7EB light neutral, 1px for dividers

Reading trio (approved feat-021, giữ nguyên từng số):

| Theme | bg/header | text | muted/icon | chip | border | accent |
|---|---|---|---|---|---|---|
| Vàng giấy (default) | `#F5F1E5` | `#111111` | `#6B7280` | `#E8DDC0` | `#DCD2B6` | `#2563EB` |
| Trắng | `#FFFFFF` | `#111111` | `#6B7280` | `#EFEFF1` | `#E5E7EB` | `#2563EB` |
| Đen | `#171512` | `#ECE7DF` | `#A8A29E` | `#2A2724` | `#3B3732` | `#60A5FA` |

Nguyên tắc: theme đọc override system dark mode chỉ trong Reader stack (`preferredColorScheme` .light cho Vàng/Trắng, .dark cho Đen); disabled icon opacity 0.35 (sáng) / 0.42 (tối), giữ `.disabled`; sheet force scheme theo theme để `ultraThinMaterial` không chói.

Icons use muted/iconTint for idle and surface for on-color. Contrast is 4.5:1 for text and 3:1 for icons.

## 3. Typography Scale

One UI family, plus choices for reading content.

UI scale: Title large bold (header), Heading medium (book name), Body 14-16 regular, Footnote 11-13 (meta), Mini for badges.

Reading content user set:

- Family: curated serif/sans set
- Size: 12-24 step 1
- Line height: 1.2-2.0 step 0.1 (size × factor)
- Letter spacing: 0-1.0 step 0.1

Weights: regular body, medium for name, semi-bold for header, bold for count. Max three per screen.

## 4. Spacing and Layout

Base 4. Gaps: 8 icon-text, 12-16 card padding, 24 section gap. Row min 56 tall. Side padding 16. Reading body adds top/bottom for floating buttons. Respect safe area.

Radius: card 12-16, pill 24, sheet 24 top only. Elevation: flat for lists, raised for cards, overlay for sheet and toast with dim.

## 5. Gestures and Motion

- **Swipe left:** reveals Info and Delete. Short threshold, no auto-delete.
- **Bottom sheet:** handle on top, drag down or tap backdrop to close, height fits content.
- **Pull to refresh:** Home and Add Book.
- **Scroll:** Reading saves offset at 300ms. New chapter starts at top.
- **Tap:** min 44×44, steppers +10 hit slop. Simple slide/fade only.

## 6. Accessibility

- Scale: UI follows system scale; reading size separate.
- Contrast: 4.5:1 text, 3:1 icons.
- Targets: 44 min, swipe reachable.
- Labels: rows read name, author, count; buttons label role.
- Keyboard: editor lifts content, no auto-cap for keys and URLs.

## 7. Cases

| Case | Rule |
|---|---|
| Long title | List 2 lines, header 1 line |
| Very large size | Scroll, never clip |
| Empty/error | Centered low emphasis message |

## Links

- Screens: [screens.md](./screens.md) · Navigation: [navigation.md](./navigation.md) · Flows: [../product/flows.md](../product/flows.md) · Overview: [../product/overview.md](../product/overview.md)

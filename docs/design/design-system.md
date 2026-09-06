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

- **background (reading)** — Full 5 theo `ReadingTheme` (feat-026, code canonical): Sách `#F7F1E3` (mặc định), Xanh dịu `#EEF3F0`, Xanh lam `#EEF4F8`, Đêm `#1C1C1E`, AMOLED `#000000`. `headerBg` trùng `background` để liền mạch khi cuộn. Không dùng nền vàng đậm / xanh đậm / tím đậm cho nền đọc chính (chỉ làm accent).
- **background (non-reading)** — #FFFFFF white for Library and Settings, #F5F5F5 light gray for grouped sections
- **surface** — #FFFFFF for cards and sheets (non-reading; reading sheet dùng `ultraThinMaterial` + forced scheme theo theme)
- **text (reading)** — theo theme: Sách `#38342E`, Xanh dịu `#29332F`, Xanh lam `#29343B`, Đêm `#D2D2D2`, AMOLED `#C8C8C8` (trắng thuần không dùng cho Đêm để đỡ lóa). Body contrast AAA (~11–13:1).
- **text (non-reading)** — #111111 near-black for titles
- **muted/icon (reading)** — theo theme: Sách `#655C4E`, Xanh dịu `#55645D`, Xanh lam `#55636E`, Đêm `#A8A8A8`, AMOLED `#A0A0A0` (muted giữ cùng họ hue với text để hài hòa; tất cả đạt AA ≥4.5:1 trên nền tương ứng, vượt 3:1 cho icon)
- **muted (non-reading)** — #6B7280 for meta and hints
- **chip (reading)** — Sách `#E7DEC7`, Xanh dịu `#DCE5DF`, Xanh lam `#DCE6EE`, Đêm `#2C2C2E`, AMOLED `#1C1C1E` (nút pill/icon nổi nhẹ trên nền; icon trên chip vẫn ≥4.5:1)
- **border (reading)** — Sách `#D8CCAC`, Xanh dịu `#C2CFC8`, Xanh lam `#BFD0DC`, Đêm `#3A3A3C`, AMOLED `#2E2E30`; divider trong sheet dùng theme border
- **accent (reading)** — Sáng `#2563EB` (cả 3 theme sáng, ~4.6:1 trên nền), Tối `#7AB8FF` (Đêm ~8.2:1, AMOLED ~10.1:1; dịu mắt khi đọc đêm)
- **accent (non-reading)** — #2563EB blue for active states and info
- **success** — #16A34A green for confirm and enabled
- **warning** — #EA580C orange for warnings
- **error** — #DC2626 red for delete and errors
- **border (non-reading)** — #E5E7EB light neutral, 1px for dividers

Reading Full 5 (approved feat-026, giữ nguyên từng số bg/text):

| Theme | bg/header | text | muted/icon | chip | border | accent |
|---|---|---|---|---|---|---|
| Sách (default) | `#F7F1E3` | `#38342E` | `#655C4E` | `#E7DEC7` | `#D8CCAC` | `#2563EB` |
| Xanh dịu | `#EEF3F0` | `#29332F` | `#55645D` | `#DCE5DF` | `#C2CFC8` | `#2563EB` |
| Xanh lam | `#EEF4F8` | `#29343B` | `#55636E` | `#DCE6EE` | `#BFD0DC` | `#2563EB` |
| Đêm | `#1C1C1E` | `#D2D2D2` | `#A8A8A8` | `#2C2C2E` | `#3A3A3C` | `#7AB8FF` |
| AMOLED | `#000000` | `#C8C8C8` | `#A0A0A0` | `#1C1C1E` | `#2E2E30` | `#7AB8FF` |

Nguyên tắc: theme đọc override system dark mode chỉ trong Reader stack (`preferredColorScheme` .light cho Sách/Xanh dịu/Xanh lam, .dark cho Đêm/AMOLED); disabled icon opacity 0.35 (sáng) / 0.42 (tối), giữ `.disabled`; sheet force scheme theo theme để `ultraThinMaterial` không chói. Picker `Màu nền` 5-across một hàng (swatch 42pt + nhãn 12pt, ring accent 2.5pt + check + semibold khi chọn).

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

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

- **background** — #FDFCF8 paper for Reading, #FFFFFF white for Library and Settings, #F5F5F5 light gray for grouped sections
- **surface** — #FFFFFF for cards and sheets
- **text** — #111111 near-black for titles
- **muted** — #6B7280 for meta and hints
- **accent** — #2563EB blue for active states and info
- **success** — #16A34A green for confirm and enabled
- **warning** — #EA580C orange for warnings
- **error** — #DC2626 red for delete and errors
- **border** — #E5E7EB light neutral, 1px for dividers

Icons use muted for idle and surface for on-color. Contrast is 4.5:1 for text and 3:1 for icons.

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

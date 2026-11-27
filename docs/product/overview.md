# Product Overview — Novels

> Vision, personas, and scope only. Entities → [domain-model.md](./domain-model.md), terms → [glossary.md](./glossary.md), flows → [flows.md](./flows.md), rules → [business-rules.md](./business-rules.md). Topology → [ARCHITECTURE.md](../../ARCHITECTURE.md).

> Target: iPhone (iOS 26.0+) and Mac (macOS 26.0+), Vietnamese UI. iOS device family is `1` — see [ios-scope](../decisions/ios-scope.md).

## Purpose

Novels lets one reader download books once and read offline. Optional AI provides independent Vietnamese translation and aligned Vietnamese/English reading through configurable providers. Cached reading stays offline; catalog, uncached AI, optional API sentence audio and explicit Google sentence lookup need network. English pronunciation defaults to installed system voices, with configurable API audio.

## Personas

- **Primary — Offline Reader.** Downloads once, reads many sessions offline. Wants fast open, progress that follows them between devices, and instant repeat AI results.
- **Secondary — Catalog Browser.** Browses remote catalog and imports chosen titles. The library is installed separately on each device.

## Scope

**In:** discover via catalog, import ZIP, browse library, read HTML with navigation and position, sync reading progress via iCloud, switch Bản gốc / Dịch / Song ngữ with independent processed cache entries, learn English sentences with Apple/API speech and explicit Google lookup, prefetch next chapters, keep settings and typography.

**Out:** no multi-user, no app account, no sync of books/settings/cache, no online reading without import, no second AI cache.

## Features

- **Import** — fetch catalog → ZIP → extract → delete ZIP. [book-import](./functional-specs/book-import.md)
- **Library** — list local books, swipe Info/Delete. [book-library](./functional-specs/book-library.md)
- **Reader** — parses HTML → one optional title + one plain body string, Previous/Next, and device-independent resume per book. [book-reader](./functional-specs/book-reader.md)
- **AI Reading** — Bản gốc (`none`) bypasses AI; Dịch (`rewrite`) and Song ngữ (`bilingual`) use independent prompts/results and check cache first. [ai-reading](./functional-specs/ai-reading.md)
- **English Learning** — paired paragraphs, sentence speech and explicit online Google lookup. [bilingual-learning](./functional-specs/bilingual-learning.md)
- **Prefetch** — next N=3 sequential, cancellable. [chapter-prefetch](./functional-specs/chapter-prefetch.md)
- **Settings** — catalog, AI, sentence audio, prefetch, typography; sanitize on launch. [settings-management](./functional-specs/settings-management.md)

## Flows

Flows → [flows.md](./flows.md). Graph → [navigation.md](../design/navigation.md).

## Rules

Rules → [business-rules.md](./business-rules.md) (BR-01..12).

## Glossary

Terms → [glossary.md](./glossary.md): Book, Chapter, Reference, Book Package, Local Repository, Processed Chapter, AI Mode, Reading Session.

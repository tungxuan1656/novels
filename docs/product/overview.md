# Product Overview — Novels

> Vision, personas, and scope only. Entities → [domain-model.md](./domain-model.md), terms → [glossary.md](./glossary.md), flows → [flows.md](./flows.md), rules → [business-rules.md](./business-rules.md). Topology → [ARCHITECTURE.md](../../ARCHITECTURE.md).

> Target: iPhone only, iOS 26+, Vietnamese UI. Project still declares family 1,2 — see [ios-scope](../decisions/ios-scope.md).

## Purpose

Novels lets one reader download books once and read offline. Optional AI — translate to natural Vietnamese and faithful summary — uses a configurable OpenAI-compatible service. Catalog and AI need network; reading needs none.

## Personas

- **Primary — Offline Reader.** Downloads once, reads many sessions offline. Wants fast open, saved offset per book, instant repeat AI results.
- **Secondary — Catalog Browser.** Browses remote catalog and imports chosen titles. Single-device, single-user, no sync.

## Scope

**In:** discover via catalog, import ZIP, browse library, read HTML with navigation and offset, switch modes `none`/`translate`/`summary` with cache, prefetch next chapters, keep settings and typography.

**Out:** no multi-user, no cloud sync, no account, no online reading without import, no second AI cache.

## Features

- **Import** — fetch catalog → ZIP → extract → delete ZIP. [book-import](./functional-specs/book-import.md)
- **Library** — list local books, swipe Info/Delete. [book-library](./functional-specs/book-library.md)
- **Reader** — parses HTML → text spans and renders with SwiftUI.Text, Previous/Next, offset per book. [book-reader](./functional-specs/book-reader.md)
- **AI Reading** — `none` is original; `translate`/`summary` check cache first. [ai-reading](./functional-specs/ai-reading.md)
- **Prefetch** — next N=3 sequential, cancellable. [chapter-prefetch](./functional-specs/chapter-prefetch.md)
- **Settings** — catalog, AI, prefetch, typography; sanitize on launch. [settings-management](./functional-specs/settings-management.md)

## Flows

Flows → [flows.md](./flows.md). Graph → [navigation.md](../design/navigation.md).

## Rules

Rules → [business-rules.md](./business-rules.md) (BR-01..12).

## Glossary

Terms → [glossary.md](./glossary.md): Book, Chapter, Reference, Book Package, Local Repository, Processed Chapter, AI Mode, Reading Session.

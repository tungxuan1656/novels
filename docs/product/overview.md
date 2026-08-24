# Product Overview — Novels

> Vision, personas, and scope only. Entities → [domain-model.md](./domain-model.md), terms → [glossary.md](./glossary.md), flows → [flows.md](./flows.md), rules → [business-rules.md](./business-rules.md). Topology → [ARCHITECTURE.md](../../ARCHITECTURE.md).

> Target: iPhone only, iOS 26+, Vietnamese UI. Project still declares family 1,2 — see [ios-scope](../../docs/decisions/ios-scope.md).

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

Full flows → [flows.md](./flows.md); graph → [navigation.md](../design/navigation.md):

1. Startup restores session; `onScreen` → Reader else Library.
2. Add Book → fetch catalog → pick → download/extract/delete ZIP.
3. Library → info sheet or Delete.
4. Reader → parses HTML → text spans and renders with SwiftUI.Text → navigate → offset saved.
5. AI switch → hit renders; miss processes then caches.
6. Prefetch when ready and mode != `none` → batch-check → sequential.
7. Settings → edit → validate → persist.

## Rules

See [business-rules.md](./business-rules.md): offline after import (BR-01), ZIP delete on success (BR-02), translate keeps honorifics (BR-03/04), summary 50–60% (BR-05/06), one cache (BR-07), prefetch N=3 (BR-08), offset per book (BR-09), delete removes folder (BR-10), typography persists (BR-11), sanitize defaults (BR-12).

## Glossary

Terms → [glossary.md](./glossary.md): Book, Chapter, Reference, Book Package, Local Repository, Processed Chapter, AI Mode, Reading Session.

# Business Decisions — Novels

> **Append-only.** Add new entry at bottom. Do not rewrite history. Label reconstructed rationale. Tech ADRs → [../decisions/index.md](../decisions/index.md); topology → [ARCHITECTURE.md](../../ARCHITECTURE.md). Business decisions are canonical here.

## How to use

- One entry per decision. Business-focused and linked.
- Required: **Date**, **Context**, **Decision**, **Consequence**.
- If not in commit/spec, label `Reconstructed`.
- Links: [domain-model.md](./domain-model.md) · [integrations.md](./integrations.md) · [business-rules.md](./business-rules.md) · [flows.md](./flows.md)

---

### D1 — Offline-First Local Book Repository

- **Date:** 2025-11-15 — *Reconstructed from file layout and BR-01*
- **Status:** Accepted
- **Context:** Primary reader downloads once and reads offline many times. Catalog and AI need network, but open, navigate, and restore offset must work offline.
- **Decision:** On-device file storage is the single source for books. Each book lives in its own folder with `book.json` and `chapters/chapter-N.html` (1-based). No sync, no multi-user. See [domain-model.md](./domain-model.md) §3 and [business-rules.md](./business-rules.md) BR-01/02.
- **Consequence:** Reading is offline after import; Library shows only local books; delete removes folder and entry; ZIP is removed only on success; startup needs no network.

### D2 — Remote Book Catalog via ZIP Package

- **Date:** 2025-11-21 — *Reconstructed from import flow*
- **Status:** Accepted
- **Context:** App must offer discoverable books without bundling them. Users need name, author, size, synopsis and one-step import.
- **Decision:** Remote catalog returns exported entries with a download link to a ZIP package. Import is fixed: ensure folders → download ZIP to temp → extract to local repository → delete ZIP → refresh library. Valid ZIP has `book.json` and `chapters/chapter-N.html`. See [integrations.md](./integrations.md) §1.
- **Consequence:** Listing is read-only and safe to retry; re-import overwrites same folder; errors show message and create no entry; catalog address is configurable.

### D3 — Processed Chapter Cache as Only AI Cache

- **Date:** 2025-12-10 — *Reconstructed from BR-07 and Flow 5*
- **Status:** Accepted
- **Context:** AI is costly and repeated across sessions and prefetch. Cache must be simple and not duplicated.
- **Decision:** One persistent processed chapter cache keyed by `bookId + chapterNumber + mode` is the only AI cache. Check before calling AI; on miss read raw text, call service per chunk, join, convert to HTML, save. Mode `none` bypasses. See [business-rules.md](./business-rules.md) BR-07 and [flows.md](./flows.md) Flow 5.
- **Consequence:** Repeat reads in same mode are instant; duplicate requests de-duplicate; no second cache; deleted books' entries become unreachable; clear lives in Settings.

### D4 — N=3 Prefetch, Sequential and Cancellable

- **Date:** 2026-02-18 — *Reconstructed from BR-08 and Flow 6*
- **Status:** Accepted
- **Context:** Readers go forward chapter by chapter. Parallel AI wastes quota and can be stale if user changes chapter or mode.
- **Decision:** When chapter is ready and mode != `none`, prefetch next N (default 3, allowed 1..10, invalid → 3). Batch-check cache, skip cached, process missing one by one in order. Cancel if chapter or mode changes. See [business-rules.md](./business-rules.md) BR-08.
- **Consequence:** Next chapters are often ready; sequential work avoids stale writes; status is runtime-only; per-chapter errors are logged and do not stop batch.

### D5 — Translate Keeps Honorifics + Summary 50–60%

- **Date:** 2026-05-10 — *Reconstructed from BR-03–06*
- **Status:** Accepted
- **Context:** Vietnamese readers expect honorifics and names unchanged and a short but faithful summary. Earlier prompts mapped honorifics and lost dialogue.
- **Decision:** `translate` keeps all honorifics unchanged (ta, nguoi, han...), replaces Sino-Vietnamese syntax with natural Vietnamese, keeps 100% meaning and names. `summary` keeps plot order, key events and key dialogue, cuts only scenery and repeated emotion to 50–60% (short chapters → shortest faithful); never invents. See [business-rules.md](./business-rules.md) BR-03–06.
- **Consequence:** Output is predictable and reviewable; prompts are configurable actions `translate`/`summary` in settings, so edits need no release.

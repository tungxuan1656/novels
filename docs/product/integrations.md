# Integrations — rn-read-books

> **Scope owner:** Owns business view of external integrations. For entities see [domain-model.md](./domain-model.md), rules [business-rules.md](./business-rules.md). Technical payloads live in linked specs.

## 1. Remote Book Catalog (Import Source)

**Purpose:** Discover which books can be imported and provide the download link for each book package.

**Business request:** App asks for the current list of available books. No user data is sent.

**Business response:** Catalog returns a success flag, a list of exported books (id, source book id, download link, file size, format, export time, and metadata: name, author, chapter count, status, synopsis), and an optional message.

**Auth:** None.

**Idempotency:** Listing is read-only and safe to retry. Re-importing the same package overwrites the local copy with the same content.

**Failure mapping:** Network or server error → "cannot load catalog, try again." Catalog reports failure → show its message or generic load failure.

**Retry:** No auto-retry. User retries from the UI.

**Details:** See [book-import](../specs/book-import.md).

---

## 2. AI Processing Service (OpenAI-Compatible)

**Purpose:** Transform raw chapter text into natural Vietnamese (translate) or a shorter faithful version (summary) using a configurable prompt.

**Business request:** App sends the active prompt and one chunk of chapter text. Long chapters are split into chunks; each chunk is one request.

**Business response:** Service returns processed text for that chunk. App joins chunks, cleans output, converts to HTML, and saves to the processed chapter cache.

**Auth:** Configured in the persistent settings store. Extra headers/body merge into the request when present. No secret is hard-coded in business rules.

**Idempotency:** Same `bookId + chapterNumber + mode` yields the same cached result after first success. Concurrent calls for the same key are de-duplicated.

**Failure mapping:** No content → "no response from AI service." Network/server error → show provider error or "AI processing failed." Invalid header/body settings are ignored.

**Retry:** Up to 3 attempts per chunk with exponential backoff 2^attempt × 1000 ms. After final failure, cache is not written. Prefetch logs the error and continues.

**Details:** See [ai-reading](../specs/ai-reading.md).

---

## Contract Separation

Business meaning is above. Technical shapes (URLs, headers, JSON, storage) live in [ai-reading](../specs/ai-reading.md), [book-import](../specs/book-import.md), and [overview.md](./overview.md).

## Links

- Model: [domain-model.md](./domain-model.md) · Glossary: [glossary.md](./glossary.md) · Rules: [business-rules.md](./business-rules.md)
- Specs: [chapter-prefetch](../specs/chapter-prefetch.md) · [settings-management](../specs/settings-management.md)

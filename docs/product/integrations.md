# Integrations — Novels

> **Scope owner:** Owns business view of external integrations. For entities see [domain-model.md](./domain-model.md), rules [business-rules.md](./business-rules.md). Technical payloads live in linked specs.

## 1. Remote Book Catalog (Import Source)

**Purpose:** Discover which books can be imported and provide the download link for each book package.

**Business request:** App asks for the current list of available books. No user data is sent.

**Business response:** Catalog returns a success flag, a list of exported books, and an optional message. Technical shape → [catalog-api.md](../contracts/catalog-api.md).

**Auth:** None.

**Idempotency:** Listing is read-only and safe to retry. Re-importing the same package overwrites the local copy with the same content.

**Failure mapping:** Network or server error → "cannot load catalog, try again." Catalog reports failure → show its message or generic load failure.

**Retry:** No auto-retry. User retries from the UI.

**Details:** See [book-import](./functional-specs/book-import.md).

---

## 2. AI Processing Service (OpenAI-Compatible)

**Purpose:** Transform raw chapter text via single Prompt (`AI_PROMPT`, modes `none`/`rewrite` — the prompt text determines the transformation) using a configurable prompt, one chunk per request.

**Business request:** App sends the active prompt and one chunk of chapter text. Long chapters are split into chunks; each chunk is one request.

**Business response:** Service returns processed text for that chunk. App joins chunks, cleans output, and saves as text for SwiftUI.Text to the processed chapter cache.

**Auth:** Configured in the persistent settings store. Extra headers/body merge into the request when present. No secret is hard-coded in business rules.

**Idempotency:** Same `bookId + chapterNumber + mode` yields the same cached result after first success. Concurrent calls for the same key are de-duplicated.

**Failure mapping:** No content → "no response from AI service." Network/server error → show provider error or "AI processing failed." Invalid header/body settings are ignored.

**Retry:** Retry 3× (1000 ms / 2000 ms) per ai-service.md. After final failure, cache is not written. Prefetch logs the error and continues.

**Details:** See [ai-reading](./functional-specs/ai-reading.md).

---

## Contract Separation

Business meaning is above. Technical shapes live in [catalog-api](../contracts/catalog-api.md) and [ai-service](../contracts/ai-service.md) (and [book-package](../contracts/book-package.md), [settings-schema](../contracts/settings-schema.md), [local-data](../contracts/local-data.md)); specs link to those contracts.

## Links

- Model: [domain-model.md](./domain-model.md) · Glossary: [glossary.md](./glossary.md) · Rules: [business-rules.md](./business-rules.md)
- Specs: [chapter-prefetch](./functional-specs/chapter-prefetch.md) · [settings-management](./functional-specs/settings-management.md)

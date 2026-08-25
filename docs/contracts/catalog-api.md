# Contract — Remote Book Catalog

> Canonical wire contract for the catalog. Business view: `../../docs/product/integrations.md` §1. Consumer: `../../docs/product/functional-specs/book-import.md`.

## Endpoint

- **Default URL:** `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books` [Intended — configurable via `BOOKS_API_URL` in `settings-schema.md`]
- **Method:** `POST` [Intended — supplied TypeScript contract]
- **Request headers:** `Content-Type: application/json` [Intended]
- **Request body:** none — supplied implementation sends no body; do not add user data.
- **Auth:** None. [Observed]

## Response

```json
{
  "success": true,
  "data": [ { "id": 1, "bookId": 1, "exportUrl": "https://...", "fileSize": 12345, "exportFormat": "zip", "exportedAt": "2024-12-03T...", "updatedAt": "2024-12-03T...", "book": { "id": 1, "name": "...", "slug": "...", "author": "...", "chapterCount": 743, "status": "...", "synopsis": "...", "lastUpdated": "2024-12-03T..." } } ],
  "message": "optional"
}
```

- **Shape:** `{ success: boolean, data: ExportedBook[], message?: string }` [Intended]
- **On `success: false`:** show `message` if present else generic load failure. See `../../docs/product/integrations.md` §1 failure mapping.
- **Transport failures:** network/server error → "cannot load catalog, try again" with retry from UI. No auto-retry.

## Entities

### ExportedBook

Exactly the supplied TypeScript interface — do not add nullability not present there. IDs are numbers.

| Field | Type | Notes |
|---|---|---|
| `id` | `number` | Export record id |
| `bookId` | `number` | Source book id from the catalog |
| `exportUrl` | `string` | ZIP download link |
| `fileSize` | `number` | Bytes |
| `exportFormat` | `string` | e.g. `"zip"` |
| `exportedAt` | `string` | ISO-8601 |
| `updatedAt` | `string` | ISO-8601 |
| `book` | `BookMeta` | Embedded metadata per interface |

### BookMeta (`book`)

Exactly the supplied interface. Only the four fields marked nullable are nullable.

| Field | Type | Notes |
|---|---|---|
| `id` | `number` | |
| `name` | `string` | Display title |
| `slug` | `string` | |
| `author` | `string \| null` | |
| `chapterCount` | `number \| null` | Mirrors `Book.count` / `references.length` |
| `status` | `string \| null` | e.g. completed/ongoing |
| `synopsis` | `string \| null` | |
| `lastUpdated` | `string \| null` | |

Domain mapping: `ExportedBook 1—1 BookMeta` in `../../docs/product/domain-model.md`. Identity → `../decisions/book-identity.md`. Storage → `local-data.md`.

## Download

- `exportUrl` is the only client-used field for download. The client passes the URL as-is. The client does not reconstruct the URL from ids. The client does not coerce numeric ids to strings. See `book-package.md` for producer shape. Download via `URLSession` → temp → `FileManager.unzipItem` → delete ZIP on success (BR-02).

## Rules

- Use `POST` with no body; do not add user data.
- Use `exportUrl` as-is for download.
- Read `BookMeta` exactly as defined; only four nullable fields CAN be null.

## Avoid

- Do not map slug or folder logic here; see `../decisions/book-identity.md` and `local-data.md`.
- Do not reconstruct download URLs from ids.
- Do not add request body without updating this contract.

## Examples

- Canonical: `POST` `https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books` with `Content-Type: application/json` and no body.

## Verification

- Run `../../init.sh` (format → lint → build). Test is SKIP (no test target yet).

## Maintenance

- The current client sends no request body. Update this contract before adding one.

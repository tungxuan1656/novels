# ADR - Private iCloud Reading Progress

- Status: Accepted; signed device verification and production schema deployment pending.
- Scope: the shared native iPhone and Mac app, with the same Apple Account on both devices.

## Decision

- Book installation stays local. Key each per-book checkpoint in `iCloud.com.tungxuan.novels`'s private CloudKit database by the SHA-256 hash of the resolved `Book.id` slug.
- Use record type `ReadingProgress`, with one `checkpoint` Bytes field. The checkpoint holds a one-based chapter, an optional zero-based paragraph index and rendition fingerprint, and the edit timestamp. Pixel offsets, chapter text, book ZIPs, caches, settings, and credentials never enter the record.
- Save locally first, keep unsent checkpoints in UserDefaults, and attempt uploads on edit, foreground entry, and book open. The later edit timestamp wins (remote wins ties), so model conflict resolution depends on device clocks. Conditional CloudKit writes prevent overwriting a change that arrived after fetch.
- On open, wait at most two seconds for reconciliation, then render with the latest local checkpoint or the legacy session. Late results can affect the next open, not the current reader. A cloud chapter outside the installed package does not replace local progress. Use the paragraph only when the rendition matches; otherwise start at the saved chapter's top. Do not switch processing modes to match another device.

## Provisioning And Smoke Test

1. Enable CloudKit for the shared bundle ID and associate `iCloud.com.tungxuan.novels` in the Apple developer account. Sign the iPhone and native Mac builds with profiles authorized for that container.
2. Use signed development builds on an iPhone and a Mac signed into the same Apple Account. Import the same ZIP on both. Scroll into a later chapter on one, reopen the book on the other, and check the paragraph with different typography and window size. Repeat in the opposite direction.
3. Verify that local reading works offline, pending progress uploads when the app next activates online, and an open reader does not jump. Repeat with a book that has no checkpoint and with an incompatible rendition.
4. In CloudKit Console, verify the Development `ReadingProgress` record type and `checkpoint` field. Deploy the schema to Production before distributing builds that use the production CloudKit environment.

See [reader behavior](../product/functional-specs/book-reader.md) and [verification policy](verification.md).

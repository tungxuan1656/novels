# ADR - Private iCloud Reading Progress

- Status: Accepted; signed device verification and production schema deployment pending.
- Scope: the shared native iPhone and Mac app, with the same Apple Account on both devices.

## Decision

- Book installation stays local. Key each per-book checkpoint in `iCloud.com.tungxuan.novels`'s private CloudKit database by the SHA-256 hash of the resolved `Book.id` slug.
- Use record type `ReadingProgress`, with one `checkpoint` Bytes field. The checkpoint holds a one-based chapter, an optional zero-based paragraph index and rendition fingerprint, and the edit timestamp. Pixel offsets, chapter text, book ZIPs, caches, settings, and credentials never enter the record.
- Save each edit locally first. Queue uploads only under the verified CloudKit account, identified by a hash of its user record ID. Recheck the account before writing or retrying; do not transfer pending entries between accounts. An edit made while verification is pending can queue once the same local iCloud identity is verified. A previously verified token-to-account binding lets offline edits queue after restart. Legacy checkpoints and edits without enough account evidence remain local only. On a Mac build without CloudKit entitlements, reading progress stays on the device.
- Attempt reconciliation on edit, foreground entry, and book open. The later timestamp wins (remote wins ties), so conflict resolution depends on device clocks. Conditional CloudKit writes prevent overwriting a change that arrived after fetch. If a newer cloud chapter is not in the installed copy, keep local progress but stop retrying the superseded upload.
- On open, wait at most two seconds for reconciliation, then render with the latest local checkpoint or the legacy session. Late results can affect the next open, not the current reader. A cloud restore does not become part of the device session until the reader makes a local edit. A cloud chapter outside the installed package does not replace local progress. Use the paragraph only when the rendition matches; otherwise start at the saved chapter's top. Do not switch processing modes to match another device.

## Provisioning And Smoke Test

1. Enable CloudKit for the shared bundle ID and associate `iCloud.com.tungxuan.novels` in the Apple developer account. Sign the iPhone and native Mac builds with profiles authorized for that container.
2. Use signed development builds on an iPhone and a Mac signed into the same Apple Account. Import the same ZIP on both. Scroll into a later chapter on one, reopen the book on the other, and check the paragraph with different typography and window size. Repeat in the opposite direction.
3. Verify that local reading works offline and an open reader does not jump. Relaunch offline and make an edit; if the verified local identity is still available, confirm it uploads when the same account reconnects. With no usable identity, confirm the edit stays local. Repeat with a book that has no checkpoint, an incompatible chapter, and an incompatible rendition.
4. With two test accounts, queue progress for the first, switch to the second, and verify that the first account’s position is never uploaded to the second. Switch back and check that only the first account can resume its pending upload.
5. In CloudKit Console, verify the Development `ReadingProgress` record type and `checkpoint` field. Deploy the schema to Production before distributing builds that use the production CloudKit environment.

See [reader behavior](../product/functional-specs/book-reader.md) and [verification policy](verification.md).

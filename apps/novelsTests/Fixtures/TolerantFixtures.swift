// Compression for NSData.compressed(using: .zlib) raw deflate fixtures
import Compression
import Foundation

enum TolerantFixtures {
    static func makeWrapperWithMacOSXAndFlag08(at zipURL: URL, id: String, count: Int) throws {
        // Generate wrapper + __MACOSX + .DS_Store with DEFLATE + flag 0x08 (descriptor)
        // iOS target lacks Process; build ZIP natively via raw deflate + descriptor to ensure real flag 0x08
        let refs = (0 ..< count).map { _ in "\"C\"" }.joined(separator: ",")
        let bookJSON = "{\"id\":\"\(id)\",\"name\":\"Test\",\"count\":\(count),\"author\":\"A\",\"references\":[\(refs)]}"
        var entries: [(String, Data)] = []
        entries.append(("\(id)/book.json", Data(bookJSON.utf8)))
        for idx in 1 ... count {
            entries.append(("\(id)/chapters/chapter-\(idx).html", Data("<p>hi</p>".utf8)))
        }
        entries.append(("__MACOSX/._book.json", Data(repeating: 0x78, count: 163)))
        entries.append(("__MACOSX/\(id)/._chapter-1.html", Data(repeating: 0x78, count: 163)))
        entries.append((".DS_Store", Data("x".utf8)))
        try makeDeflateDescriptorZip(at: zipURL, entries: entries)
    }

    /// Raw ZIP writer for device-parity fixtures: explicit name bytes, flag and
    /// method per entry. Stored sizes/CRC live in the local header (no descriptor).
    struct RawZipEntry {
        let nameBytes: Data
        let content: Data
        /// Deflate payload bytes actually stored (raw deflate for method 8, content for method 0).
        let storedBytes: Data
        let method: UInt16
        let flag: UInt16
    }

    static func rawDeflateBytes(_ data: Data) -> Data? {
        // Hand-rolled raw deflate (RFC1951) using stored (uncompressed) blocks
        // only. NSData's `.zlib` output framing varies by platform (it is NOT
        // reliably header+payload+adler, so strip-first/strip-last truncation
        // silently corrupts the stream -> Z_BUF_ERROR in the reader).
        // Stored blocks are deterministic everywhere, always valid raw deflate,
        // and always bypass the reader's NSData fast path — so the test
        // genuinely exercises inflateInit2(-15).
        guard !data.isEmpty else { return Data() }
        var out = Data()
        var offset = 0
        while offset < data.count {
            let chunk = min(65535, data.count - offset)
            let isFinal = (offset + chunk) == data.count
            out.append(isFinal ? 0x01 : 0x00) // BFINAL + BTYPE=00, byte-aligned
            let len = UInt16(chunk)
            out.append(UInt8(len & 0xFF))
            out.append(UInt8(len >> 8))
            let nlen = ~len
            out.append(UInt8(nlen & 0xFF))
            out.append(UInt8(nlen >> 8))
            out.append(contentsOf: data[offset ..< offset + chunk])
            offset += chunk
        }
        return out
    }

    static func makeRawZip(at url: URL, entries: [RawZipEntry]) throws {
        var localData = Data()
        var centralData = Data()
        var offset: UInt32 = 0
        for entry in entries {
            let crc = tolerantCRC32(entry.content)
            let compSize = UInt32(entry.storedBytes.count)
            let uncompSize = UInt32(entry.content.count)
            var local = Data()
            tolerantAppend32(0x0403_4B50, to: &local)
            tolerantAppend16(20, to: &local)
            tolerantAppend16(entry.flag, to: &local)
            tolerantAppend16(entry.method, to: &local)
            tolerantAppend16(0, to: &local)
            tolerantAppend16(0, to: &local)
            tolerantAppend32(crc, to: &local)
            tolerantAppend32(compSize, to: &local)
            tolerantAppend32(uncompSize, to: &local)
            tolerantAppend16(UInt16(entry.nameBytes.count), to: &local)
            tolerantAppend16(0, to: &local)
            local.append(entry.nameBytes)
            local.append(entry.storedBytes)
            localData.append(local)
            var central = Data()
            tolerantAppend32(0x0201_4B50, to: &central)
            tolerantAppend16(20, to: &central)
            tolerantAppend16(20, to: &central)
            tolerantAppend16(entry.flag, to: &central)
            tolerantAppend16(entry.method, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend32(crc, to: &central)
            tolerantAppend32(compSize, to: &central)
            tolerantAppend32(uncompSize, to: &central)
            tolerantAppend16(UInt16(entry.nameBytes.count), to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend32(0, to: &central)
            tolerantAppend32(offset, to: &central)
            central.append(entry.nameBytes)
            centralData.append(central)
            offset += UInt32(local.count)
        }
        var eocd = Data()
        tolerantAppend32(0x0605_4B50, to: &eocd)
        tolerantAppend16(0, to: &eocd)
        tolerantAppend16(0, to: &eocd)
        tolerantAppend16(UInt16(entries.count), to: &eocd)
        tolerantAppend16(UInt16(entries.count), to: &eocd)
        tolerantAppend32(UInt32(centralData.count), to: &eocd)
        tolerantAppend32(offset, to: &eocd)
        tolerantAppend16(0, to: &eocd)
        var final = Data()
        final.append(localData)
        final.append(centralData)
        final.append(eocd)
        try final.write(to: url)
    }

    /// Valid package with TRUE raw-deflate (method 8) entries — exercises the
    /// inflateInit2(-15) path that Files/Windows producers emit and that failed
    /// on device via the hardcoded zlib version / dylib paths.
    static func makeRawDeflateZip(at zipURL: URL, id: String, count: Int) throws {
        let refs = (0 ..< count).map { _ in "\"C\"" }.joined(separator: ",")
        let bookJSON = "{\"id\":\"\(id)\",\"name\":\"Test\",\"count\":\(count),\"author\":\"A\",\"references\":[\(refs)]}"
        var entries: [RawZipEntry] = []
        func deflateEntry(name: String, content: Data) throws -> RawZipEntry {
            guard let raw = rawDeflateBytes(content) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return RawZipEntry(
                nameBytes: Data(name.utf8),
                content: content,
                storedBytes: raw,
                method: 8,
                flag: 0x0800
            )
        }
        try entries.append(deflateEntry(name: "book.json", content: Data(bookJSON.utf8)))
        for idx in 1 ... count {
            let html = "<html><body><p>Nội dung chương \(idx) with enough text to make deflate worthwhile. "
                + String(repeating: "lorem ipsum dolor sit amet. ", count: 20) + "</p></body></html>"
            try entries.append(deflateEntry(
                name: "chapters/chapter-\(idx).html",
                content: Data(html.utf8)
            ))
        }
        try makeRawZip(at: zipURL, entries: entries)
    }

    /// Wrapper whose folder name uses legacy 8-bit bytes with UTF8-flag=0
    /// (Files/Windows ZIPs with VI names). Old code threw on decode; fallback
    /// must preserve the entry and flatten by structure.
    static func makeLegacyFilenameWrapperZip(
        at zipURL: URL,
        id: String,
        outerNameBytes: Data,
        flag: UInt16
    ) throws {
        let bookJSON = "{\"id\":\"\(id)\",\"name\":\"Test\",\"count\":1,\"author\":\"A\",\"references\":[\"C1\"]}"
        func entry(suffix: String, content: Data) -> RawZipEntry {
            RawZipEntry(
                nameBytes: outerNameBytes + Data(suffix.utf8),
                content: content,
                storedBytes: content,
                method: 0,
                flag: flag
            )
        }
        var rawEntries: [RawZipEntry] = []
        rawEntries.append(entry(suffix: "book.json", content: Data(bookJSON.utf8)))
        rawEntries.append(entry(suffix: "chapters/chapter-1.html", content: Data("<p>hi</p>".utf8)))
        try makeRawZip(at: zipURL, entries: rawEntries)
    }

    /// Multi-level wrapper + device/Windows system strays. `depth` counts
    /// nested single folders above book.json.
    static func makeDeepWrapperWithStraysZip(at zipURL: URL, id: String, depth: Int) throws {
        let bookJSON = "{\"id\":\"\(id)\",\"name\":\"Test\",\"count\":1,\"author\":\"A\",\"references\":[\"C1\"]}"
        let prefix = (0 ..< depth).map { "level-\($0)/" }.joined()
        func stored(_ name: String, _ content: Data) -> RawZipEntry {
            RawZipEntry(
                nameBytes: Data(name.utf8),
                content: content,
                storedBytes: content,
                method: 0,
                flag: 0x0800
            )
        }
        var strayEntries: [RawZipEntry] = []
        strayEntries.append(stored("\(prefix)book.json", Data(bookJSON.utf8)))
        strayEntries.append(stored("\(prefix)chapters/chapter-1.html", Data("<p>hi</p>".utf8)))
        strayEntries.append(stored("__macosx/._book.json", Data("junk".utf8)))
        strayEntries.append(stored(".Spotlight-V100/Store-V2/abc", Data("junk".utf8)))
        strayEntries.append(stored(".Trashes/501/x", Data("junk".utf8)))
        strayEntries.append(stored("Thumbs.db", Data("junk".utf8)))
        strayEntries.append(stored(".LSOverride", Data("junk".utf8)))
        strayEntries.append(stored(".DS_Store", Data("junk".utf8)))
        try makeRawZip(at: zipURL, entries: strayEntries)
    }

    private static func deflateRaw(_ data: Data) -> Data {
        if data.isEmpty {
            return Data()
        }
        if let wrapped = try? (data as NSData).compressed(using: .zlib) as Data {
            return wrapped
        }
        return data
    }

    // swiftlint:disable:next function_body_length
    private static func makeDeflateDescriptorZip(at url: URL, entries: [(String, Data)]) throws {
        var localData = Data()
        var centralData = Data()
        var offset: UInt32 = 0
        for (name, content) in entries {
            let nameData = name.data(using: .utf8)!
            let crc = tolerantCRC32(content)
            let deflated = deflateRaw(content)
            let compSize = UInt32(deflated.count)
            let uncompSize = UInt32(content.count)
            var local = Data()
            tolerantAppend32(0x0403_4B50, to: &local)
            tolerantAppend16(20, to: &local)
            tolerantAppend16(0x08, to: &local)
            tolerantAppend16(8, to: &local)
            tolerantAppend16(0, to: &local)
            tolerantAppend16(0, to: &local)
            tolerantAppend32(0, to: &local)
            tolerantAppend32(0, to: &local)
            tolerantAppend32(0, to: &local)
            tolerantAppend16(UInt16(nameData.count), to: &local)
            tolerantAppend16(0, to: &local)
            local.append(nameData)
            local.append(deflated)
            tolerantAppend32(0x0807_4B50, to: &local)
            tolerantAppend32(crc, to: &local)
            tolerantAppend32(compSize, to: &local)
            tolerantAppend32(uncompSize, to: &local)
            localData.append(local)
            var central = Data()
            tolerantAppend32(0x0201_4B50, to: &central)
            tolerantAppend16(20, to: &central)
            tolerantAppend16(20, to: &central)
            tolerantAppend16(0x08, to: &central)
            tolerantAppend16(8, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend32(crc, to: &central)
            tolerantAppend32(compSize, to: &central)
            tolerantAppend32(uncompSize, to: &central)
            tolerantAppend16(UInt16(nameData.count), to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend16(0, to: &central)
            tolerantAppend32(0, to: &central)
            tolerantAppend32(offset, to: &central)
            central.append(nameData)
            centralData.append(central)
            offset += UInt32(local.count)
        }
        var eocd = Data()
        tolerantAppend32(0x0605_4B50, to: &eocd)
        tolerantAppend16(0, to: &eocd)
        tolerantAppend16(0, to: &eocd)
        tolerantAppend16(UInt16(entries.count), to: &eocd)
        tolerantAppend16(UInt16(entries.count), to: &eocd)
        tolerantAppend32(UInt32(centralData.count), to: &eocd)
        tolerantAppend32(offset, to: &eocd)
        tolerantAppend16(0, to: &eocd)
        var final = Data()
        final.append(localData)
        final.append(centralData)
        final.append(eocd)
        try final.write(to: url)
    }
}

private func tolerantCRC32(_ data: Data) -> UInt32 {
    let table: [UInt32] = (0 ..< 256).map { idx in
        var crcVal = UInt32(idx)
        for _ in 0 ..< 8 {
            crcVal = (crcVal & 1) != 0 ? (crcVal >> 1) ^ 0xEDB8_8320 : crcVal >> 1
        }
        return crcVal
    }
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)]
    }
    return crc ^ 0xFFFF_FFFF
}

private func tolerantAppend16(_ value: UInt16, to data: inout Data) {
    var little = value.littleEndian
    data.append(Data(bytes: &little, count: 2))
}

private func tolerantAppend32(_ value: UInt32, to data: inout Data) {
    var little = value.littleEndian
    data.append(Data(bytes: &little, count: 4))
}

// swiftlint:disable:next function_body_length
func makeDescriptorFlagStoreZip(at url: URL, files: [String: Data]) throws {
    // Build ZIP with flag 0x08 (data-descriptor) and STORE (0)
    // Local header sizes/crc zero, descriptor holds real values with signature
    var localData = Data()
    var centralData = Data()
    var offset: UInt32 = 0
    for (name, content) in files {
        let nameData = name.data(using: .utf8)!
        let crc = tolerantCRC32(content)
        let compSize = UInt32(content.count)
        let uncompSize = UInt32(content.count)
        var local = Data()
        tolerantAppend32(0x0403_4B50, to: &local)
        tolerantAppend16(20, to: &local)
        tolerantAppend16(0x08, to: &local)
        tolerantAppend16(0, to: &local)
        tolerantAppend16(0, to: &local)
        tolerantAppend16(0, to: &local)
        tolerantAppend32(0, to: &local)
        tolerantAppend32(0, to: &local)
        tolerantAppend32(0, to: &local)
        tolerantAppend16(UInt16(nameData.count), to: &local)
        tolerantAppend16(0, to: &local)
        local.append(nameData)
        local.append(content)
        tolerantAppend32(0x0807_4B50, to: &local)
        tolerantAppend32(crc, to: &local)
        tolerantAppend32(compSize, to: &local)
        tolerantAppend32(uncompSize, to: &local)
        localData.append(local)
        var central = Data()
        tolerantAppend32(0x0201_4B50, to: &central)
        tolerantAppend16(20, to: &central)
        tolerantAppend16(20, to: &central)
        tolerantAppend16(0x08, to: &central)
        tolerantAppend16(0, to: &central)
        tolerantAppend16(0, to: &central)
        tolerantAppend16(0, to: &central)
        tolerantAppend32(crc, to: &central)
        tolerantAppend32(compSize, to: &central)
        tolerantAppend32(uncompSize, to: &central)
        tolerantAppend16(UInt16(nameData.count), to: &central)
        tolerantAppend16(0, to: &central)
        tolerantAppend16(0, to: &central)
        tolerantAppend16(0, to: &central)
        tolerantAppend16(0, to: &central)
        tolerantAppend32(0, to: &central)
        tolerantAppend32(offset, to: &central)
        central.append(nameData)
        centralData.append(central)
        offset += UInt32(local.count)
    }
    var eocd = Data()
    tolerantAppend32(0x0605_4B50, to: &eocd)
    tolerantAppend16(0, to: &eocd)
    tolerantAppend16(0, to: &eocd)
    tolerantAppend16(UInt16(files.count), to: &eocd)
    tolerantAppend16(UInt16(files.count), to: &eocd)
    tolerantAppend32(UInt32(centralData.count), to: &eocd)
    tolerantAppend32(offset, to: &eocd)
    tolerantAppend16(0, to: &eocd)
    var final = Data()
    final.append(localData)
    final.append(centralData)
    final.append(eocd)
    try final.write(to: url)
}

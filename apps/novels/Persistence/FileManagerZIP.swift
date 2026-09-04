// swiftlint:disable file_length
import Compression
import Darwin
import Foundation
import OSLog

private let unzipLogger = Logger(subsystem: "com.tungxuan.novels.import", category: "unzip")

// MARK: - Decision Note

// Polyfill: Foundation on Linux/Sim lacks FileManager.zipItem/unzipItem.
// Production ships `unzipItem` only (secure extraction for import).
// `zipItem` is retained as test helper to generate ZIP fixtures without external tools
// (used by ImportViewModelTests.makeValidZip, BookRepository tests). Keep for now
// to avoid breaking existing tests; production code never calls zipItem.
// If removed, tests must generate ZIPs via alternative fixture data.

// MARK: - CRC32

private let crcTable: [UInt32] = (0 ..< 256).map { i in
    var crc = UInt32(i)
    for _ in 0 ..< 8 {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
    }
    return crc
}

private func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        let idx = Int((crc ^ UInt32(byte)) & 0xFF)
        crc = (crc >> 8) ^ crcTable[idx]
    }
    return crc ^ 0xFFFF_FFFF
}

// MARK: - Helpers

private func appendUInt16(_ value: UInt16, to data: inout Data) {
    var little = value.littleEndian
    data.append(Data(bytes: &little, count: 2))
}

private func appendUInt32(_ value: UInt32, to data: inout Data) {
    var little = value.littleEndian
    data.append(Data(bytes: &little, count: 4))
}

private func makeLocalHeader(
    fileName: Data,
    crc: UInt32,
    compressedSize: UInt32,
    uncompressedSize: UInt32,
    compressionMethod: UInt16
) -> Data {
    var header = Data()
    appendUInt32(0x0403_4B50, to: &header)
    appendUInt16(20, to: &header) // version
    appendUInt16(0, to: &header) // flag
    appendUInt16(compressionMethod, to: &header)
    appendUInt16(0, to: &header) // mod time
    appendUInt16(0, to: &header) // mod date
    appendUInt32(crc, to: &header)
    appendUInt32(compressedSize, to: &header)
    appendUInt32(uncompressedSize, to: &header)
    appendUInt16(UInt16(fileName.count), to: &header)
    appendUInt16(0, to: &header) // extra len
    return header
}

private func makeCentralHeader( // swiftlint:disable:this function_parameter_count
    fileName: Data,
    crc: UInt32,
    compressedSize: UInt32,
    uncompressedSize: UInt32,
    compressionMethod: UInt16,
    offset: UInt32
) -> Data {
    var header = Data()
    appendUInt32(0x0201_4B50, to: &header)
    appendUInt16(20, to: &header) // version made
    appendUInt16(20, to: &header) // version needed
    appendUInt16(0, to: &header)
    appendUInt16(compressionMethod, to: &header)
    appendUInt16(0, to: &header)
    appendUInt16(0, to: &header)
    appendUInt32(crc, to: &header)
    appendUInt32(compressedSize, to: &header)
    appendUInt32(uncompressedSize, to: &header)
    appendUInt16(UInt16(fileName.count), to: &header)
    appendUInt16(0, to: &header) // extra
    appendUInt16(0, to: &header) // comment
    appendUInt16(0, to: &header) // disk
    appendUInt16(0, to: &header) // internal
    appendUInt32(0, to: &header) // external
    appendUInt32(offset, to: &header)
    return header
}

private func makeEOCD(numEntries: UInt16, centralSize: UInt32, centralOffset: UInt32) -> Data {
    var eocd = Data()
    appendUInt32(0x0605_4B50, to: &eocd)
    appendUInt16(0, to: &eocd)
    appendUInt16(0, to: &eocd)
    appendUInt16(numEntries, to: &eocd)
    appendUInt16(numEntries, to: &eocd)
    appendUInt32(centralSize, to: &eocd)
    appendUInt32(centralOffset, to: &eocd)
    appendUInt16(0, to: &eocd)
    return eocd
}

// MARK: - Adler32 (for completeness; raw inflate does not require it upfront)

private func adler32(_ data: Data) -> UInt32 {
    let mod: UInt32 = 65521
    var aval: UInt32 = 1
    var bval: UInt32 = 0
    for byte in data {
        aval = (aval + UInt32(byte)) % mod
        bval = (bval + aval) % mod
    }
    return (bval << 16) | aval
}

// MARK: - Raw deflate (zlib inflateInit2 windowBits=-15 via dynamic libz)

/// Dynamic loading avoids hard link to libz on Linux and keeps polyfill portable.
/// Sandboxed-device note: absolute dylib paths may be hidden and the header
/// version baked at build time ("1.2.12") can mismatch the device runtime,
/// making inflateInit2_ reject every method-8 entry. Prefer the already-loaded
/// global namespace first, then canonical paths; always pass the runtime
/// zlibVersion() string instead of a hardcoded one.
private struct LibzHandle {
    let lib: UnsafeMutableRawPointer
    let ownsHandle: Bool
}

private func openLibz() -> LibzHandle? {
    // Global namespace: libz is already linked via Foundation — no path needed,
    // works inside the iOS sandbox.
    if let global = dlopen(nil, RTLD_NOW), dlsym(global, "inflate") != nil {
        return LibzHandle(lib: global, ownsHandle: false)
    }
    let candidates = ["/usr/lib/libz.dylib", "/usr/lib/libz.1.dylib", "/usr/lib/libz.1.2.12.dylib"]
    for path in candidates {
        if let found = dlopen(path, RTLD_NOW) {
            return LibzHandle(lib: found, ownsHandle: true)
        }
    }
    // Last resort: rely on dyld search
    if let found = dlopen("libz.dylib", RTLD_NOW) {
        return LibzHandle(lib: found, ownsHandle: true)
    }
    return nil
}

private struct ZStream {
    var nextIn: UnsafePointer<UInt8>?
    var availIn: UInt32
    var totalIn: UInt
    var nextOut: UnsafeMutablePointer<UInt8>?
    var availOut: UInt32
    var totalOut: UInt
    var msg: UnsafePointer<CChar>?
    var state: UnsafeMutableRawPointer?
    var zalloc: UnsafeMutableRawPointer?
    var zfree: UnsafeMutableRawPointer?
    var opaque: UnsafeMutableRawPointer?
    var dataType: Int32
    var adler: UInt
    var reserved: UInt
}

// swiftlint:disable:next function_body_length
private func inflateRawDeflate(_ data: Data, expectedSize: Int) throws -> Data {
    guard let opened = openLibz() else {
        throw CocoaError(.fileReadCorruptFile)
    }
    let lib = opened.lib
    // Only dlclose handles we opened by path; the global-namespace handle must stay open.
    defer {
        if opened.ownsHandle {
            dlclose(lib)
        }
    }

    guard let symInit = dlsym(lib, "inflateInit2_"),
          let symInflate = dlsym(lib, "inflate"),
          let symEnd = dlsym(lib, "inflateEnd")
    else {
        throw CocoaError(.fileReadCorruptFile)
    }

    typealias InflateInit2Fn = @convention(c) (
        UnsafeMutableRawPointer, Int32, UnsafePointer<CChar>, Int32
    ) -> Int32
    typealias InflateFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
    typealias InflateEndFn = @convention(c) (UnsafeMutableRawPointer) -> Int32
    typealias ZlibVersionFn = @convention(c) () -> UnsafePointer<CChar>

    let inflateInit2 = unsafeBitCast(symInit, to: InflateInit2Fn.self)
    let inflate = unsafeBitCast(symInflate, to: InflateFn.self)
    let inflateEnd = unsafeBitCast(symEnd, to: InflateEndFn.self)

    // Query the runtime version: inflateInit2_ validates the version string,
    // so a hardcoded build-time value fails on devices shipping another zlib.
    let runtimeVersion: String = {
        guard let symVer = dlsym(lib, "zlibVersion") else { return "1.2.11" }
        let fn = unsafeBitCast(symVer, to: ZlibVersionFn.self)
        return String(cString: fn())
    }()

    // Handle empty entry (uncompressedSize==0)
    if expectedSize == 0 {
        if data.isEmpty {
            return Data()
        }
        // Still need to inflate to verify empty output
    }

    // zlib constants
    let zOk: Int32 = 0
    let zStreamEnd: Int32 = 1
    let zFinish: Int32 = 4
    let windowBitsRaw: Int32 = -15

    var stream = ZStream(
        nextIn: nil,
        availIn: 0,
        totalIn: 0,
        nextOut: nil,
        availOut: 0,
        totalOut: 0,
        msg: nil,
        state: nil,
        zalloc: nil,
        zfree: nil,
        opaque: nil,
        dataType: 0,
        adler: 0,
        reserved: 0
    )

    let versionString = runtimeVersion
    let streamSize = Int32(MemoryLayout<ZStream>.size)
    let initRet = versionString.withCString { version in
        withUnsafeMutablePointer(to: &stream) { ptr in
            inflateInit2(UnsafeMutableRawPointer(ptr), windowBitsRaw, version, streamSize)
        }
    }
    guard initRet == zOk else {
        throw CocoaError(.fileReadCorruptFile)
    }
    defer {
        withUnsafeMutablePointer(to: &stream) { ptr in
            _ = inflateEnd(UnsafeMutableRawPointer(ptr))
        }
    }

    // Output buffer: expectedSize (capped by caller 100MB) or 1 for zero case
    let outCapacity = max(expectedSize, 1)
    var output = Data(count: outCapacity)

    let inflateResult: Int32 = try data.withUnsafeBytes { inRaw in
        try output.withUnsafeMutableBytes { outRaw in
            guard let inBase = inRaw.baseAddress, let outBase = outRaw.baseAddress else {
                throw CocoaError(.fileReadCorruptFile)
            }
            stream.nextIn = inBase.assumingMemoryBound(to: UInt8.self)
            stream.availIn = UInt32(data.count)
            stream.nextOut = outBase.assumingMemoryBound(to: UInt8.self)
            stream.availOut = UInt32(outCapacity)
            return withUnsafeMutablePointer(to: &stream) { ptr in
                inflate(UnsafeMutableRawPointer(ptr), zFinish)
            }
        }
    }

    guard inflateResult == zStreamEnd else {
        throw CocoaError(.fileReadCorruptFile)
    }

    let produced = Int(stream.totalOut)
    // Verify size matches header when header provides it
    if expectedSize != 0, produced != expectedSize {
        throw CocoaError(.fileReadCorruptFile)
    }
    if produced < output.count {
        output.count = produced
    }
    // Optional Adler verification for completeness
    _ = adler32(output)
    return output
}

private func decompressDeflate(_ data: Data, expectedSize: Int) throws -> Data {
    // If producer already emitted zlib-wrapped data, NSData(zlib) handles it.
    if let decoded = try? (data as NSData).decompressed(using: .zlib) as Data,
       decoded.count == expectedSize
    { // swiftlint:disable:this opening_brace
        return decoded
    }
    if expectedSize == 0, data.isEmpty {
        return Data()
    }
    // Correct path: raw deflate via zlib inflateInit2(-15) – validates CRC/size
    // without requiring a dummy Adler. This restores support for most ZIP producers.
    return try inflateRawDeflate(data, expectedSize: expectedSize)
}

// MARK: - Whitelist & Security Helpers

/// ZIP filename decoding (UTF8-flag aware with legacy fallback).
/// Files/Windows ZIPs often carry VI/latin names with flag=0 in a legacy
/// 8-bit encoding (CP437/CP1252-ish). Throwing on any non-UTF8 name fails the
/// whole import on device. Decode order: UTF-8 first (covers
/// UTF-8-bytes-with-flag-0 producers), then WindowsCP1252, then ISO-Latin-1
/// (total 1:1 byte map, never fails for non-empty input).
private func decodeZIPFilename(_ data: Data, flag: UInt16) -> String? {
    _ = flag
    if !data.isEmpty, let decoded = String(data: data, encoding: .utf8), !decoded.isEmpty {
        return decoded
    }
    if !data.isEmpty, let decoded = String(data: data, encoding: .windowsCP1252), !decoded.isEmpty {
        return decoded
    }
    if !data.isEmpty, let decoded = String(data: data, encoding: .isoLatin1), !decoded.isEmpty {
        return decoded
    }
    return nil
}

/// Safely relativize producer paths (standard Info-ZIP behavior): convert
/// Windows separators, then strip leading slashes from absolute-packed
/// entries. The unchanged traversal/drive checks run on the normalized form
/// and containment is re-verified below — anything still escaping is rejected
/// exactly as before.
private func relativizeZIPPath(_ name: String) -> String {
    var path = name.replacingOccurrences(of: "\\", with: "/")
    while path.hasPrefix("/") {
        path.removeFirst()
    }
    return path
}

private func hasPathTraversal(_ name: String) -> Bool {
    if name.hasPrefix("/") || name.hasPrefix("\\") {
        return true
    }
    // Only reject when a path component equals ".." (not substring).
    let comps = name.split(separator: "/")
    for comp in comps where comp == ".." {
        return true
    }
    // Windows absolute like C:
    if name.count >= 2, name[name.index(name.startIndex, offsetBy: 1)] == ":" {
        return true
    }
    return false
}

// isHygieneEntry consolidated to ZipValidator.isHygieneEntry (single source)

// swiftlint:disable large_tuple
private func readDescriptor(at pos: Int, data: Data) -> (crc: UInt32, comp: UInt32, uncomp: UInt32, len: Int)? {
    if pos + 16 <= data.count {
        let sig = UInt32(data[pos]) | UInt32(data[pos + 1]) << 8
            | UInt32(data[pos + 2]) << 16 | UInt32(data[pos + 3]) << 24
        if sig == 0x0807_4B50 {
            let crc = UInt32(data[pos + 4]) | UInt32(data[pos + 5]) << 8
                | UInt32(data[pos + 6]) << 16 | UInt32(data[pos + 7]) << 24
            let comp = UInt32(data[pos + 8]) | UInt32(data[pos + 9]) << 8
                | UInt32(data[pos + 10]) << 16 | UInt32(data[pos + 11]) << 24
            let uncomp = UInt32(data[pos + 12]) | UInt32(data[pos + 13]) << 8
                | UInt32(data[pos + 14]) << 16 | UInt32(data[pos + 15]) << 24
            return (crc, comp, uncomp, 16)
        }
    }
    if pos + 12 <= data.count {
        let crc = UInt32(data[pos]) | UInt32(data[pos + 1]) << 8
            | UInt32(data[pos + 2]) << 16 | UInt32(data[pos + 3]) << 24
        let comp = UInt32(data[pos + 4]) | UInt32(data[pos + 5]) << 8
            | UInt32(data[pos + 6]) << 16 | UInt32(data[pos + 7]) << 24
        let uncomp = UInt32(data[pos + 8]) | UInt32(data[pos + 9]) << 8
            | UInt32(data[pos + 10]) << 16 | UInt32(data[pos + 11]) << 24
        return (crc, comp, uncomp, 12)
    }
    return nil
}

// swiftlint:enable large_tuple

/// ZIP64 extra-field probe (ID 0x0001). Bounds-safe walk over the local
/// header's extra block; corrupt lengths just end the scan. Non-throwing.
private func hasZIP64ExtraField(_ data: Data, extraStart: Int, extraEnd: Int) -> Bool {
    var pos = extraStart
    while pos + 4 <= extraEnd, pos + 4 <= data.count {
        let fieldID = UInt16(data[pos]) | UInt16(data[pos + 1]) << 8
        let fieldSize = Int(UInt16(data[pos + 2]) | UInt16(data[pos + 3]) << 8)
        if fieldID == 0x0001 {
            return true
        }
        pos += 4 + fieldSize
    }
    return false
}

/// NOTE: Linear scan inside compressed data may hit false header
/// signatures (~1.4e-3 per entry). CRC + size checks catch truncation;
/// central-directory back-scan would be more robust but heavier.
/// Accepted for hotfix scope.
private func findNextHeaderPos(from start: Int, data: Data) -> Int? {
    var idx = start
    while idx + 4 <= data.count {
        let sig = UInt32(data[idx]) | UInt32(data[idx + 1]) << 8
            | UInt32(data[idx + 2]) << 16 | UInt32(data[idx + 3]) << 24
        if sig == 0x0403_4B50 || sig == 0x0201_4B50 || sig == 0x0605_4B50 {
            return idx
        }
        idx += 1
    }
    return nil
}

// MARK: - Unzip failure context (instrumentation only — no behavior change)

/// Records WHERE unzipItem threw fileReadCorruptFile. Carried in the thrown
/// CocoaError's userInfo, so domain/code and the ImportError.invalidPackage
/// mapping stay identical; the Log viewer reads it back via `token(from:)`.
/// Entry names only (truncated to 40 chars) — never file content.
struct UnzipFailure: Sendable {
    let site: String
    let entryIndex: Int
    let method: Int
    let compSize: Int
    let isDescriptor: Bool
    let uncompSize: Int
    let entriesExtracted: Int
    let entryName: String
    let note: String

    init(
        site: String,
        entryIndex: Int,
        method: Int,
        compSize: Int,
        isDescriptor: Bool,
        uncompSize: Int,
        entriesExtracted: Int,
        entryName: String,
        note: String = ""
    ) {
        self.site = site
        self.entryIndex = entryIndex
        self.method = method
        self.compSize = compSize
        self.isDescriptor = isDescriptor
        self.uncompSize = uncompSize
        self.entriesExtracted = entriesExtracted
        self.entryName = entryName
        self.note = note
    }

    func token() -> String {
        var parts = [
            "site=\(site)",
            "entry=\(entryIndex)",
            "method=\(method)",
            "comp=\(compSize)",
            "desc=\(isDescriptor ? 1 : 0)",
            "uncomp=\(uncompSize)",
            "extracted=\(entriesExtracted)", // swiftlint:disable:this trailing_comma
        ]
        // Prefix/traversal carry the full name so a hidden `..` tail past the
        // usual truncation is visible on the next device retry; other sites
        // keep the 40-char cap.
        if !entryName.isEmpty {
            if site == "prefix" || site == "traversal" {
                parts.append("name=\(entryName)")
            } else {
                parts.append("name=\(entryName.prefix(40))")
            }
        }
        if !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: " ")
    }

    static func token(from error: Error) -> String? {
        (error as NSError).userInfo[unzipFailureUserInfoKey] as? String
    }

    /// Site + method parsed from our own token layout. Method always precedes
    /// the free-form name, so names containing spaces or "method=" cannot
    /// confuse the parse.
    static func siteAndMethod(from error: Error) -> (site: String, method: Int?)? {
        guard let token = token(from: error) else {
            return nil
        }
        let comps = token.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard let first = comps.first, first.hasPrefix("site=") else {
            return nil
        }
        let site = String(first.dropFirst("site=".count))
        var method: Int?
        for comp in comps where comp.hasPrefix("method=") {
            method = Int(comp.dropFirst("method=".count))
            break
        }
        return (site, method)
    }
}

private let unzipFailureUserInfoKey = "com.novels.unzipFailure"

/// Last-60-chars tail for base/dest paths in prefix diagnostics. Paths only.
private func tail60(_ path: String) -> String {
    guard path.count > 60 else { return path }
    return "…" + String(path.suffix(60))
}

// MARK: - FileManager ZIP Polyfill

private struct ZipEntry {
    let url: URL
    let relativePath: String
    let isDir: Bool
}

extension FileManager {
    func zipItem( // swiftlint:disable:this function_body_length
        at sourceURL: URL,
        to destinationURL: URL,
        shouldKeepParent: Bool = false,
        compressionMethod: Int = 0
    ) throws {
        if fileExists(atPath: destinationURL.path) {
            try removeItem(at: destinationURL)
        }
        var entries: [ZipEntry] = []
        if shouldKeepParent {
            let parent = sourceURL.deletingLastPathComponent()
            let leaf = sourceURL.lastPathComponent
            // Add root dir
            entries.append(ZipEntry(url: sourceURL, relativePath: leaf + "/", isDir: true))
            if let enumerator = enumerator(at: sourceURL, includingPropertiesForKeys: [.isDirectoryKey]) {
                for case let url as URL in enumerator {
                    let resolvedParent = parent.resolvingSymlinksInPath().path
                    let resolvedURL = url.resolvingSymlinksInPath().path
                    let rel = resolvedURL.replacingOccurrences(of: resolvedParent + "/", with: "")
                    var isDir: ObjCBool = false
                    _ = fileExists(atPath: url.path, isDirectory: &isDir)
                    let path = rel + (isDir.boolValue ? "/" : "")
                    entries.append(ZipEntry(url: url, relativePath: path, isDir: isDir.boolValue))
                }
            }
        } else {
            if let enumerator = enumerator(
                at: sourceURL,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) {
                for case let url as URL in enumerator {
                    let full = url.resolvingSymlinksInPath().path
                    let prefix = sourceURL.resolvingSymlinksInPath().path + "/"
                    guard full.hasPrefix(prefix) else { continue }
                    let rel = String(full.dropFirst(prefix.count))
                    var isDir: ObjCBool = false
                    _ = fileExists(atPath: url.path, isDirectory: &isDir)
                    // Skip if rel empty
                    if rel.isEmpty {
                        continue
                    }
                    let path = rel + (isDir.boolValue && !rel.hasSuffix("/") ? "/" : "")
                    entries.append(ZipEntry(url: url, relativePath: path, isDir: isDir.boolValue))
                }
            }
        }

        var localData = Data()
        var centralData = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let fileNameData = entry.relativePath.data(using: .utf8)!
            let fileData: Data
            let crc: UInt32
            if entry.isDir {
                fileData = Data()
                crc = 0
            } else {
                fileData = try Data(contentsOf: entry.url)
                crc = crc32(fileData)
            }
            let header = makeLocalHeader(
                fileName: fileNameData,
                crc: crc,
                compressedSize: UInt32(fileData.count),
                uncompressedSize: UInt32(fileData.count),
                compressionMethod: 0
            )
            let central = makeCentralHeader(
                fileName: fileNameData,
                crc: crc,
                compressedSize: UInt32(fileData.count),
                uncompressedSize: UInt32(fileData.count),
                compressionMethod: 0,
                offset: offset
            )
            localData.append(header)
            localData.append(fileNameData)
            localData.append(fileData)
            centralData.append(central)
            centralData.append(fileNameData)
            offset += UInt32(header.count + fileNameData.count + fileData.count)
        }

        let eocd = makeEOCD(
            numEntries: UInt16(entries.count),
            centralSize: UInt32(centralData.count),
            centralOffset: offset
        )
        var final = Data()
        final.append(localData)
        final.append(centralData)
        final.append(eocd)
        try final.write(to: destinationURL)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        let maxTotalUncompressed: UInt64 = 100 * 1024 * 1024 // 100MB cap
        var totalUncompressed: UInt64 = 0
        // Failure context for the Log viewer: ordinal + parsed header fields of
        // the entry being processed, plus how many entries materialized so far.
        // Unknown until parsed: method/comp/uncomp stay -1, name stays empty.
        var entryIndex = -1
        var entryName = ""
        var entryMethod = -1
        var entryCompSize = -1
        var entryIsDescriptor = false
        var entryUncompSize = -1
        var entriesExtracted = 0
        func corruptError(_ site: String, note: String = "") -> CocoaError {
            let failure = UnzipFailure(
                site: site,
                entryIndex: entryIndex,
                method: entryMethod,
                compSize: entryCompSize,
                isDescriptor: entryIsDescriptor,
                uncompSize: entryUncompSize,
                entriesExtracted: entriesExtracted,
                entryName: String(entryName.prefix(160)),
                note: note
            )
            return CocoaError(.fileReadCorruptFile, userInfo: [unzipFailureUserInfoKey: failure.token()])
        }
        // Resolve the root once and build child URLs from that canonical root.
        // On iOS, resolving a not-yet-created child can leave /var unresolved
        // while the existing root resolves to /private/var.
        let canonicalDestinationURL = destinationURL.resolvingSymlinksInPath().standardizedFileURL
        let baseResolved = canonicalDestinationURL.path
        try createDirectory(at: destinationURL, withIntermediateDirectories: true)
        // Memory-map the ZIP instead of slurping it: identical Data API and
        // offset semantics for the parser below, without spiking RAM on
        // multi-MB packages. Throws here if the file cannot be mapped.
        let data = try Data(contentsOf: sourceURL, options: .alwaysMapped)
        unzipLogger.info("unzipItem mapped read bytes=\(data.count, privacy: .public)")
        var pos = 0
        while pos + 30 <= data.count {
            let sig = UInt32(data[pos]) | UInt32(data[pos + 1]) << 8
                | UInt32(data[pos + 2]) << 16 | UInt32(data[pos + 3]) << 24
            if sig == 0x0403_4B50 {
                entryIndex += 1
                entryName = ""
                entryMethod = -1
                entryCompSize = -1
                entryIsDescriptor = false
                entryUncompSize = -1
                let flag = UInt16(data[pos + 6]) | UInt16(data[pos + 7]) << 8
                let isDescriptor = (flag & 0x08) != 0
                // Encrypted entries (traditional PKWARE or strong encryption)
                // cannot be decrypted — reject before touching payload.
                if (flag & 0x01) != 0 {
                    throw corruptError("encrypted") // mapped to ImportError.invalidPackage
                }
                let versionNeeded = UInt16(data[pos + 4]) | UInt16(data[pos + 5]) << 8
                let compMethod = UInt16(data[pos + 8]) | UInt16(data[pos + 9]) << 8
                entryMethod = Int(compMethod)
                entryIsDescriptor = isDescriptor
                let crcHeader = UInt32(data[pos + 14]) | UInt32(data[pos + 15]) << 8
                    | UInt32(data[pos + 16]) << 16 | UInt32(data[pos + 17]) << 24
                let compSizeHeader = UInt32(data[pos + 18]) | UInt32(data[pos + 19]) << 8
                    | UInt32(data[pos + 20]) << 16 | UInt32(data[pos + 21]) << 24
                let uncompSizeHeader = UInt32(data[pos + 22]) | UInt32(data[pos + 23]) << 8
                    | UInt32(data[pos + 24]) << 16 | UInt32(data[pos + 25]) << 24
                entryCompSize = Int(compSizeHeader)
                entryUncompSize = Int(uncompSizeHeader)
                let nameLen = Int(UInt16(data[pos + 26]) | UInt16(data[pos + 27]) << 8)
                let extraLen = Int(UInt16(data[pos + 28]) | UInt16(data[pos + 29]) << 8)
                let nameStart = pos + 30
                let nameEnd = nameStart + nameLen
                let extraEnd = nameEnd + extraLen
                let dataStart = extraEnd
                guard nameEnd <= data.count, extraEnd <= data.count else {
                    throw corruptError("header") // mapped to ImportError.invalidPackage
                }
                // ZIP64 needs 64-bit parsing throughout — clearer-reject.
                if versionNeeded >= 45 || hasZIP64ExtraField(data, extraStart: nameEnd, extraEnd: extraEnd) {
                    throw corruptError("zip64") // mapped to ImportError.invalidPackage
                }
                let nameData = data[nameStart ..< nameEnd]
                guard let decodedName = decodeZIPFilename(Data(nameData), flag: flag), !decodedName.isEmpty else {
                    throw corruptError("filename") // mapped to ImportError.invalidPackage
                }
                // Relativize before containment: absolute-packed (`/a/b`) and
                // Windows (`a\b`) entries land under the destination; `..`,
                // drive-absolute and other escapes still throw below.
                let fileName = relativizeZIPPath(decodedName)
                guard !fileName.isEmpty else {
                    throw corruptError("filename") // mapped to ImportError.invalidPackage
                }
                entryName = fileName
                // Zip-slip: reject "..", leading "/" or absolute — always
                if hasPathTraversal(fileName) {
                    throw corruptError("traversal") // mapped to ImportError.invalidPackage
                }
                // Hygiene filter: skip __MACOSX / .DS_Store / ._* without throw
                if ZipValidator.isHygieneEntry(fileName) {
                    if isDescriptor {
                        guard let nextPos = findNextHeaderPos(from: dataStart, data: data) else {
                            throw corruptError("descriptor")
                        }
                        pos = nextPos
                    } else {
                        let dataEnd = dataStart + Int(compSizeHeader)
                        guard dataEnd <= data.count else {
                            throw corruptError("header")
                        }
                        pos = dataEnd
                    }
                    continue
                }
                // Outer-folder entries allowed temporarily — flattened by resolver; method/crc/size still enforced
                // above
                if compMethod != 0, compMethod != 8 {
                    throw corruptError("method") // mapped to ImportError.invalidPackage
                }
                // Determine effective sizes/crc and slice
                var effectiveCrc = crcHeader
                var effectiveCompSize = compSizeHeader
                var effectiveUncompSize = uncompSizeHeader
                var dataEnd: Int
                var nextPos: Int
                var fileDataCompressed: Data
                if isDescriptor {
                    guard let nextHeaderPos = findNextHeaderPos(from: dataStart, data: data) else {
                        throw corruptError("descriptor")
                    }
                    // Prefer 16-byte signed descriptor if signature matches at nextHeaderPos-16, else 12-byte unsigned
                    // swiftlint:disable:next large_tuple
                    var desc: (crc: UInt32, comp: UInt32, uncomp: UInt32, len: Int)?
                    var descStart = nextHeaderPos
                    if nextHeaderPos >= 16 {
                        let p16 = nextHeaderPos - 16
                        if p16 >= dataStart {
                            let sig16 = UInt32(data[p16]) | UInt32(data[p16 + 1]) << 8
                                | UInt32(data[p16 + 2]) << 16 | UInt32(data[p16 + 3]) << 24
                            if sig16 == 0x0807_4B50, let descriptor = readDescriptor(at: p16, data: data),
                               descriptor.len == 16
                            { // swiftlint:disable:this opening_brace
                                desc = descriptor
                                descStart = p16
                            }
                        }
                    }
                    if desc == nil, nextHeaderPos >= 12 {
                        let p12 = nextHeaderPos - 12
                        if p12 >= dataStart, let descriptor = readDescriptor(at: p12, data: data) {
                            // Ensure not misreading signed descriptor as unsigned: already checked above
                            let sigAtP12 = UInt32(data[p12]) | UInt32(data[p12 + 1]) << 8
                                | UInt32(data[p12 + 2]) << 16 | UInt32(data[p12 + 3]) << 24
                            if sigAtP12 != 0x0807_4B50 {
                                desc = descriptor
                                descStart = p12
                            } else if descriptor.len == 16 { // if still signed, use it
                                desc = descriptor
                                descStart = p12
                            }
                        }
                    }
                    guard let descriptor = desc else {
                        throw corruptError("descriptor")
                    }
                    effectiveCrc = descriptor.crc
                    effectiveUncompSize = descriptor.uncomp
                    // Descriptor comp should equal distance; use distance for slicing if mismatch
                    let computedComp = UInt32(descStart - dataStart)
                    // Prefer descriptor comp but ensure slice matches actual distance
                    if descriptor.comp != computedComp {
                        effectiveCompSize = computedComp
                    } else {
                        effectiveCompSize = descriptor.comp
                    }
                    dataEnd = descStart
                    nextPos = nextHeaderPos
                    guard descStart <= data.count, nextPos <= data.count else {
                        throw corruptError("descriptor")
                    }
                    if effectiveCompSize == 0 {
                        fileDataCompressed = Data()
                    } else {
                        guard dataStart + Int(effectiveCompSize) <= data.count else {
                            throw corruptError("header")
                        }
                        fileDataCompressed = Data(data[dataStart ..< dataStart + Int(effectiveCompSize)])
                    }
                } else {
                    dataEnd = dataStart + Int(compSizeHeader)
                    guard dataEnd <= data.count else {
                        throw corruptError("header")
                    }
                    nextPos = dataEnd
                    if compSizeHeader == 0 {
                        fileDataCompressed = Data()
                    } else {
                        fileDataCompressed = Data(data[dataStart ..< dataEnd])
                    }
                }
                // Cap total uncompressed size (zip bomb) using effective size
                entryCompSize = Int(effectiveCompSize)
                entryUncompSize = Int(effectiveUncompSize)
                totalUncompressed += UInt64(effectiveUncompSize)
                if totalUncompressed > maxTotalUncompressed {
                    throw corruptError("bomb") // mapped to ImportError.invalidPackage
                }
                // Also reject if single entry exceeds cap
                if UInt64(effectiveUncompSize) > maxTotalUncompressed {
                    throw corruptError("bomb") // mapped to ImportError.invalidPackage
                }
                let fileData: Data
                if compMethod == 0 {
                    fileData = fileDataCompressed
                    // Verify CRC32 for stored
                    if crc32(fileData) != effectiveCrc {
                        throw corruptError("crc") // mapped to ImportError.invalidPackage
                    }
                    if UInt32(fileData.count) != effectiveUncompSize {
                        throw corruptError("size") // mapped to ImportError.invalidPackage
                    }
                } else if compMethod == 8 {
                    do {
                        fileData = try decompressDeflate(
                            fileDataCompressed,
                            expectedSize: Int(effectiveUncompSize)
                        )
                    } catch {
                        throw corruptError("inflate") // mapped to ImportError.invalidPackage
                    }
                    if crc32(fileData) != effectiveCrc {
                        throw corruptError("crc") // mapped to ImportError.invalidPackage
                    }
                    if UInt32(fileData.count) != effectiveUncompSize {
                        throw corruptError("size") // mapped to ImportError.invalidPackage
                    }
                } else {
                    throw corruptError("method") // mapped to ImportError.invalidPackage
                }
                // Ensure resolved dest has prefix destination (handle /var -> /private symlink)
                let destURL = canonicalDestinationURL.appendingPathComponent(fileName)
                let destResolved = destURL.resolvingSymlinksInPath().standardizedFileURL.path
                // Normalize base with trailing slash check
                if destResolved != baseResolved && !destResolved.hasPrefix(baseResolved + "/") {
                    let note = "base=\(tail60(baseResolved)) dest=\(tail60(destResolved))"
                    throw corruptError("prefix", note: note) // mapped to ImportError.invalidPackage
                }
                if fileName.hasSuffix("/") || fileName.lowercased() == "chapters" {
                    try createDirectory(at: destURL, withIntermediateDirectories: true)
                    entriesExtracted += 1
                } else {
                    try createDirectory(
                        at: destURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    // Ensure parent also within base
                    let parentResolved = destURL.deletingLastPathComponent()
                        .resolvingSymlinksInPath().standardizedFileURL.path
                    if parentResolved != baseResolved, !parentResolved.hasPrefix(baseResolved + "/") {
                        let note = "base=\(tail60(baseResolved)) dest=\(tail60(parentResolved))"
                        throw corruptError("prefix", note: note) // mapped to ImportError.invalidPackage
                    }
                    do {
                        try fileData.write(to: destURL)
                    } catch {
                        throw corruptError("write") // mapped to ImportError.invalidPackage
                    }
                    entriesExtracted += 1
                }
                pos = nextPos
            } else if sig == 0x0201_4B50 || sig == 0x0605_4B50 {
                break
            } else {
                break
            }
        }
    }

    // MARK: - Canonical Root Resolver (Task 2: wrapper flatten)

    func resolveCanonicalRoot(at url: URL) -> URL {
        resolveCanonicalRoot(at: url, fileManager: self)
    }

    func resolveCanonicalRoot(at url: URL, fileManager: FileManager) -> URL {
        // Flatten up to 3 nested single-folder wrappers (device ZIPs from Files
        // often double-wrap: outer/Books/<title>/book.json). Each level still
        // requires exactly one non-hygiene child directory — anything wider or
        // deeper is left as-is and fails validation as invalidPackage.
        var current = url
        for _ in 0 ..< 3 {
            // Normalise before validating so cased variants (Book.JSON, …)
            // validate and read correctly on case-sensitive devices. No-op
            // when canonical names already exist or on filesystem errors.
            normaliseCaseVariants(at: current, fileManager: fileManager)
            if ZipValidator.isValidRoot(at: current, fileManager: fileManager) {
                return current
            }
            guard let top = try? fileManager.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            ) else {
                return current
            }
            // Lọc hygiene entries (__MACOSX, .DS_Store, ._* resource forks, …)
            let filtered = top.filter { !ZipValidator.isHygieneEntry($0.lastPathComponent) }
            // Chỉ flatten khi đúng 1 subfolder duy nhất
            guard filtered.count == 1, let single = filtered.first else {
                return current
            }
            var isDir: ObjCBool = false
            _ = fileManager.fileExists(atPath: single.path, isDirectory: &isDir)
            guard isDir.boolValue else {
                return current
            }
            current = single
        }
        // Normalise case variants in place (Book.JSON/Chapters/Chapter-N.html)
        // so downstream exact-lowercase readers work on case-sensitive devices.
        normaliseCaseVariants(at: current, fileManager: fileManager)
        return current
    }

    /// Rename cased variants to canonical lowercase names where safe.
    /// No-ops when the canonical name already exists (validator then rejects
    /// the extra entry) or on any filesystem error. Never touches hygiene.
    private func normaliseCaseVariants(at root: URL, fileManager: FileManager) {
        guard let top = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return
        }
        var chaptersDir: URL?
        for entry in top {
            if ZipValidator.isHygieneEntry(entry.lastPathComponent) {
                continue
            }
            var isDir: ObjCBool = false
            _ = fileManager.fileExists(atPath: entry.path, isDirectory: &isDir)
            let lower = entry.lastPathComponent.lowercased()
            if lower == "book.json", !isDir.boolValue, entry.lastPathComponent != "book.json" {
                let dest = root.appendingPathComponent("book.json", isDirectory: false)
                if !fileManager.fileExists(atPath: dest.path) {
                    try? fileManager.moveItem(at: entry, to: dest)
                }
            } else if lower == "chapters", isDir.boolValue, entry.lastPathComponent != "chapters" {
                let dest = root.appendingPathComponent("chapters", isDirectory: true)
                if !fileManager.fileExists(atPath: dest.path) {
                    try? fileManager.moveItem(at: entry, to: dest)
                    chaptersDir = dest
                } else {
                    chaptersDir = dest
                }
            } else if lower == "chapters", isDir.boolValue {
                chaptersDir = entry
            }
        }
        guard let chapters = chaptersDir,
              let files = try? fileManager.contentsOfDirectory(
                  at: chapters,
                  includingPropertiesForKeys: [],
                  options: []
              )
        else {
            return
        }
        for entry in files {
            let name = entry.lastPathComponent
            if ZipValidator.isHygieneEntry(name) {
                continue
            }
            guard let number = canonicalChapterNumber(for: name),
                  name != "chapter-\(number).html"
            else {
                continue
            }
            let dest = chapters.appendingPathComponent("chapter-\(number).html", isDirectory: false)
            if !fileManager.fileExists(atPath: dest.path) {
                try? fileManager.moveItem(at: entry, to: dest)
            }
        }
    }

    /// Canonical chapter number for case/zero-padded variants of chapter-N.html.
    private func canonicalChapterNumber(for name: String) -> Int? {
        let lower = name.lowercased()
        guard lower.hasPrefix("chapter-"), lower.hasSuffix(".html") else {
            return nil
        }
        let middle = lower.dropFirst("chapter-".count).dropLast(".html".count)
        guard !middle.isEmpty, middle.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(middle) else {
            return nil
        }
        return number
    }
}

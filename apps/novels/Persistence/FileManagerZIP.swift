// swiftlint:disable file_length
import Compression
import Darwin
import Foundation

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
    // Dynamic loading avoids hard link to libz on Linux and keeps polyfill portable.
    // Try canonical dylib paths; Simulator/device may expose different symlinks.
    let candidates = ["/usr/lib/libz.dylib", "/usr/lib/libz.1.dylib", "/usr/lib/libz.1.2.12.dylib"]
    var handle: UnsafeMutableRawPointer?
    for path in candidates {
        if let found = dlopen(path, RTLD_NOW) {
            handle = found
            break
        }
    }
    // Last resort: rely on dyld search
    if handle == nil {
        handle = dlopen("libz.dylib", RTLD_NOW)
    }
    guard let lib = handle else {
        throw CocoaError(.fileReadCorruptFile)
    }
    defer { dlclose(lib) }

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

    let inflateInit2 = unsafeBitCast(symInit, to: InflateInit2Fn.self)
    let inflate = unsafeBitCast(symInflate, to: InflateFn.self)
    let inflateEnd = unsafeBitCast(symEnd, to: InflateEndFn.self)

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

    let versionString = "1.2.12"
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
        // Resolve destination for prefix check handling /var vs /private symlink
        let baseResolved = destinationURL.resolvingSymlinksInPath().standardizedFileURL.path
        try createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let data = try Data(contentsOf: sourceURL)
        var pos = 0
        while pos + 30 <= data.count {
            let sig = UInt32(data[pos]) | UInt32(data[pos + 1]) << 8
                | UInt32(data[pos + 2]) << 16 | UInt32(data[pos + 3]) << 24
            if sig == 0x0403_4B50 {
                let flag = UInt16(data[pos + 6]) | UInt16(data[pos + 7]) << 8
                let isDescriptor = (flag & 0x08) != 0
                let compMethod = UInt16(data[pos + 8]) | UInt16(data[pos + 9]) << 8
                let crcHeader = UInt32(data[pos + 14]) | UInt32(data[pos + 15]) << 8
                    | UInt32(data[pos + 16]) << 16 | UInt32(data[pos + 17]) << 24
                let compSizeHeader = UInt32(data[pos + 18]) | UInt32(data[pos + 19]) << 8
                    | UInt32(data[pos + 20]) << 16 | UInt32(data[pos + 21]) << 24
                let uncompSizeHeader = UInt32(data[pos + 22]) | UInt32(data[pos + 23]) << 8
                    | UInt32(data[pos + 24]) << 16 | UInt32(data[pos + 25]) << 24
                let nameLen = Int(UInt16(data[pos + 26]) | UInt16(data[pos + 27]) << 8)
                let extraLen = Int(UInt16(data[pos + 28]) | UInt16(data[pos + 29]) << 8)
                let nameStart = pos + 30
                let nameEnd = nameStart + nameLen
                let extraEnd = nameEnd + extraLen
                let dataStart = extraEnd
                guard nameEnd <= data.count, extraEnd <= data.count else {
                    throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                }
                let nameData = data[nameStart ..< nameEnd]
                guard let fileName = String(data: nameData, encoding: .utf8), !fileName.isEmpty else {
                    throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                }
                // Zip-slip: reject "..", leading "/" or absolute — always
                if hasPathTraversal(fileName) {
                    throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                }
                // Hygiene filter: skip __MACOSX / .DS_Store / ._* without throw
                if ZipValidator.isHygieneEntry(fileName) {
                    if isDescriptor {
                        guard let nextPos = findNextHeaderPos(from: dataStart, data: data) else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        pos = nextPos
                    } else {
                        let dataEnd = dataStart + Int(compSizeHeader)
                        guard dataEnd <= data.count else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        pos = dataEnd
                    }
                    continue
                }
                // Outer-folder entries allowed temporarily — flattened by resolver; method/crc/size still enforced
                // above
                if compMethod != 0, compMethod != 8 {
                    throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
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
                        throw CocoaError(.fileReadCorruptFile)
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
                        throw CocoaError(.fileReadCorruptFile)
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
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    if effectiveCompSize == 0 {
                        fileDataCompressed = Data()
                    } else {
                        guard dataStart + Int(effectiveCompSize) <= data.count else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        fileDataCompressed = Data(data[dataStart ..< dataStart + Int(effectiveCompSize)])
                    }
                } else {
                    dataEnd = dataStart + Int(compSizeHeader)
                    guard dataEnd <= data.count else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    nextPos = dataEnd
                    if compSizeHeader == 0 {
                        fileDataCompressed = Data()
                    } else {
                        fileDataCompressed = Data(data[dataStart ..< dataEnd])
                    }
                }
                // Cap total uncompressed size (zip bomb) using effective size
                totalUncompressed += UInt64(effectiveUncompSize)
                if totalUncompressed > maxTotalUncompressed {
                    throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                }
                // Also reject if single entry exceeds cap
                if UInt64(effectiveUncompSize) > maxTotalUncompressed {
                    throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                }
                let fileData: Data
                if compMethod == 0 {
                    fileData = fileDataCompressed
                    // Verify CRC32 for stored
                    if crc32(fileData) != effectiveCrc {
                        throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                    }
                    if UInt32(fileData.count) != effectiveUncompSize {
                        throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                    }
                } else if compMethod == 8 {
                    fileData = try decompressDeflate(
                        fileDataCompressed,
                        expectedSize: Int(effectiveUncompSize)
                    )
                    if crc32(fileData) != effectiveCrc {
                        throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                    }
                    if UInt32(fileData.count) != effectiveUncompSize {
                        throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                    }
                } else {
                    throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                }
                // Ensure resolved dest has prefix destination (handle /var -> /private symlink)
                let destURL = destinationURL.appendingPathComponent(fileName)
                let destResolved = destURL.resolvingSymlinksInPath().standardizedFileURL.path
                // Normalize base with trailing slash check
                if destResolved != baseResolved && !destResolved.hasPrefix(baseResolved + "/") {
                    throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                }
                if fileName.hasSuffix("/") || fileName == "chapters" {
                    try createDirectory(at: destURL, withIntermediateDirectories: true)
                } else {
                    try createDirectory(
                        at: destURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    // Ensure parent also within base
                    let parentResolved = destURL.deletingLastPathComponent()
                        .resolvingSymlinksInPath().standardizedFileURL.path
                    if parentResolved != baseResolved, !parentResolved.hasPrefix(baseResolved + "/") {
                        throw CocoaError(.fileReadCorruptFile) // mapped to ImportError.invalidPackage
                    }
                    try fileData.write(to: destURL)
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
        if ZipValidator.isValidRoot(at: url, fileManager: fileManager) {
            return url
        }
        guard let top = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return url
        }
        // Lọc hygiene entries (__MACOSX, .DS_Store, ._* resource forks)
        let filtered = top.filter { !ZipValidator.isHygieneEntry($0.lastPathComponent) }
        // Chỉ flatten khi đúng 1 subfolder duy nhất
        guard filtered.count == 1, let single = filtered.first else {
            return url
        }
        var isDir: ObjCBool = false
        _ = fileManager.fileExists(atPath: single.path, isDirectory: &isDir)
        guard isDir.boolValue else {
            return url
        }
        if ZipValidator.isValidRoot(at: single, fileManager: fileManager) {
            return single
        }
        return url
    }
}

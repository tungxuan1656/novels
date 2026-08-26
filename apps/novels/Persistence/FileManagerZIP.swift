import Compression
import Foundation

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

private func decompressDeflate(_ data: Data, expectedSize: Int) throws -> Data {
    // Try zlib-wrapped decompression by adding header/footer
    var zlibWrapped = Data([0x78, 0x9C])
    zlibWrapped.append(data)
    // Adler32 placeholder - use 1
    zlibWrapped.append(Data([0x00, 0x00, 0x00, 0x01]))
    if let decoded = try? (zlibWrapped as NSData).decompressed(using: .zlib) as Data,
       decoded.count == expectedSize || expectedSize == 0
    { // swiftlint:disable:this opening_brace
        return decoded
    }
    // Fallback: try raw decompress via Compression framework with COMPRESSION_ZLIB
    // Use stream API for raw deflate (-15 windowBits) via compression_decode_buffer is not raw
    // As last resort, return data as is if expectedSize matches
    if data.count == expectedSize {
        return data
    }
    throw CocoaError(.fileReadCorruptFile)
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

    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        try createDirectory(at: destinationURL, withIntermediateDirectories: true)
        var pos = 0
        while pos + 30 <= data.count {
            let sig = UInt32(data[pos]) | UInt32(data[pos + 1]) << 8
                | UInt32(data[pos + 2]) << 16 | UInt32(data[pos + 3]) << 24
            if sig == 0x0403_4B50 {
                let compMethod = UInt16(data[pos + 8]) | UInt16(data[pos + 9]) << 8
                let compSize = UInt32(data[pos + 18]) | UInt32(data[pos + 19]) << 8
                    | UInt32(data[pos + 20]) << 16 | UInt32(data[pos + 21]) << 24
                let uncompSize = UInt32(data[pos + 22]) | UInt32(data[pos + 23]) << 8
                    | UInt32(data[pos + 24]) << 16 | UInt32(data[pos + 25]) << 24
                let nameLen = Int(UInt16(data[pos + 26]) | UInt16(data[pos + 27]) << 8)
                let extraLen = Int(UInt16(data[pos + 28]) | UInt16(data[pos + 29]) << 8)
                let nameStart = pos + 30
                let nameEnd = nameStart + nameLen
                let extraEnd = nameEnd + extraLen
                let dataStart = extraEnd
                let dataEnd = dataStart + Int(compSize)
                guard nameEnd <= data.count, extraEnd <= data.count, dataEnd <= data.count else {
                    break
                }
                let nameData = data[nameStart ..< nameEnd]
                guard let fileName = String(data: nameData, encoding: .utf8) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let fileDataCompressed = data[dataStart ..< dataEnd]
                let fileData: Data
                if compMethod == 0 {
                    fileData = Data(fileDataCompressed)
                } else if compMethod == 8 {
                    fileData = try decompressDeflate(
                        Data(fileDataCompressed),
                        expectedSize: Int(uncompSize)
                    )
                } else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let destURL = destinationURL.appendingPathComponent(fileName)
                if fileName.hasSuffix("/") {
                    try createDirectory(at: destURL, withIntermediateDirectories: true)
                } else {
                    try createDirectory(
                        at: destURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try fileData.write(to: destURL)
                }
                pos = dataEnd
            } else if sig == 0x0201_4B50 || sig == 0x0605_4B50 {
                break
            } else {
                break
            }
        }
    }
}

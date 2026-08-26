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

import Foundation

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

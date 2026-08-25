import CryptoKit
import Foundation

enum SHA256 {
    static func hex(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

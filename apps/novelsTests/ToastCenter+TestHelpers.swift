import Foundation
@testable import novels

extension ToastCenter {
    var lastMessage: String? {
        current?.message
    }
}

import Foundation

enum ReadingTheme: String, Codable, CaseIterable, Equatable, Identifiable {
    case vangGiay
    case trang
    case den

    var id: String {
        rawValue
    }

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .vangGiay:
                return "Vàng giấy"
            case .trang:
                return "Trắng"
            case .den:
                return "Đen"
        }
        // swiftlint:enable switch_case_alignment
    }
}

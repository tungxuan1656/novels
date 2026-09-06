import Foundation

enum ReadingTheme: String, Codable, CaseIterable, Equatable, Identifiable {
    case sach
    case xanhDiu
    case xanhLam
    case dem
    case amoled

    var id: String {
        rawValue
    }

    var title: String {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .sach:
                return "Sách"
            case .xanhDiu:
                return "Xanh dịu"
            case .xanhLam:
                return "Xanh lam"
            case .dem:
                return "Đêm"
            case .amoled:
                return "AMOLED"
        }
        // swiftlint:enable switch_case_alignment
    }
}

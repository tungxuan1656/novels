import Foundation

struct AIAction: Codable, Equatable, Hashable {
    let key: String
    let name: String
    let prompt: String
}

enum SettingsDefaults {
    static let defaultPrompt = "Dịch truyện sang tiếng Việt tự nhiên, "
        + "giữ nguyên xưng hô (ta, ngươi, huynh, đệ...), bảo tồn 100% nội dung và văn phong."
}

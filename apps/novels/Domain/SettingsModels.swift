import Foundation

struct AIAction: Codable, Equatable, Hashable {
    let key: String
    let name: String
    let prompt: String
}

enum SettingsDefaults {
    // swiftlint:disable trailing_comma
    static let defaultActions: [AIAction] = [
        AIAction(
            key: "translate",
            name: "Dịch",
            prompt: "Bạn là dịch giả tiểu thuyết. Dịch sang tiếng Việt tự nhiên, giữ 100% ý nghĩa, "
                + "tên riêng, địa danh, thuật ngữ. Giữ nguyên mọi đại từ xưng hô như ta, ngươi, hắn, nàng, "
                + "huynh, đệ, tỷ, muội... Tuyệt đối không đổi ta→em/anh, ngươi→bạn. Không thêm bớt nội dung. "
                + "Văn phong tự nhiên, mượt mà."
        ),
        AIAction(
            key: "summary",
            name: "Tóm tắt",
            prompt: "Bạn là biên tập tóm tắt. Tóm tắt chương còn 50–60% độ dài, giữ nguyên thứ tự "
                + "cốt truyện, sự kiện chính, bước ngoặt, thoại quan trọng (rút gọn nhưng giữ ý). "
                + "Chỉ lược bỏ miêu tả cảnh dài, cảm xúc lặp, bối cảnh không ảnh hưởng cốt truyện. "
                + "Tuyệt đối không bịa thêm nội dung (no hallucination)."
        ),
    ]
    // swiftlint:enable trailing_comma

    static var defaultActionsJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(defaultActions),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }
}

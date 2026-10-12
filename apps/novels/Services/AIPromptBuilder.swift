import Foundation

enum AIPromptBuilder {
    static let bilingualProtocol = """
    Quy tắc định dạng đầu ra (bắt buộc):
    - Chỉ trả về dữ liệu định dạng JSON thuần túy (JSON only), không kèm văn bản giải thích hoặc markdown ngoài JSON.
    - Cấu trúc JSON: {"paragraphs": [{"id": ..., "vi": "...", "en": "..."}]}
    - Giữ nguyên chính xác toàn bộ các id từ đầu vào (exact IDs); không được thay đổi, thêm, hoặc bớt id.
    - Mỗi id từ đầu vào phải có đúng một cặp vi và en tương ứng (one vi/en pair each).
    - Tuyệt đối không gộp (no merging) hoặc bỏ sót (no dropping) bất kỳ đoạn nào.
    """

    static func prompt(
        for mode: AIMode,
        customPrompt: String,
        bilingualPrompt: String = SettingsDefaults.defaultBilingualPrompt
    ) -> String {
        // swiftlint:disable switch_case_alignment
        switch mode {
            case .none:
                return ""
            case .rewrite:
                let trimmed = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? SettingsDefaults.defaultPrompt : customPrompt
            case .bilingual:
                let trimmed = bilingualPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                let basePrompt = trimmed.isEmpty ? SettingsDefaults.defaultBilingualPrompt : bilingualPrompt
                return "\(basePrompt)\n\n\(bilingualProtocol)"
        }
        // swiftlint:enable switch_case_alignment
    }

    static func defaultPrompt(for mode: AIMode) -> String {
        // swiftlint:disable switch_case_alignment
        switch mode {
            case .none:
                return ""
            case .rewrite:
                return SettingsDefaults.defaultPrompt
            case .bilingual:
                return SettingsDefaults.defaultBilingualPrompt
        }
        // swiftlint:enable switch_case_alignment
    }
}

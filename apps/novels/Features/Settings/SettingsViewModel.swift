import Foundation

struct SettingDescriptor {
    let key: String
    let label: String
    let placeholder: String
    let description: String
    let defaultValue: String
    let allowsVerbatimSave: Bool

    // swiftlint:disable cyclomatic_complexity switch_case_alignment
    func validate(_ value: String) -> String? {
        switch key {
            case "BOOKS_API_URL", "OPENAI_API_URL":
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "URL không được để trống" : nil
            case "OPENAI_MODEL":
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "Mô hình không được để trống" : nil
            case "AI_PROVIDER":
                let lowered = value.lowercased()
                return (lowered.isEmpty || lowered == "openai") ? nil : "Chỉ hỗ trợ openai"
            case "AI_CUSTOM_HEADERS", "AI_EXTRA_BODY":
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    return nil
                }
                guard let data = value.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data),
                      obj is [String: Any]
                else {
                    return "JSON phải là object, ví dụ {\"Authorization\":\"Bearer ...\"}"
                }
                return nil
            case "AI_PROMPT":
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "Rỗng sẽ về mặc định, dùng Xóa để khôi phục"
                }
                return nil
            case "PREFETCH_COUNT":
                if let number = Self.parsedPrefetchCount(value), (0 ... 1000).contains(number) {
                    return nil
                }
                return "0..1000, ngoài khoảng không lưu (giữ giá trị cũ)"
            case "AI_MIN_CHUNK_SIZE":
                if let number = Int(value), (500 ... 10000).contains(number) {
                    return nil
                }
                return "500..10000, ngoài khoảng sẽ về 1300"
            case "fontSize":
                if let number = Double(value), (12 ... 40).contains(number) {
                    return nil
                }
                return "12..40"
            case "lineHeight":
                if let number = Double(value), (1.0 ... 50).contains(number) {
                    return nil
                }
                return "1.0..50"
            case "font":
                return Self.fontError(value)
            case "letterSpacing":
                if let number = Double(value), (0 ... 3.0).contains(number) {
                    return nil
                }
                return "0..3.0"
            default:
                return nil
        }
    }

    // swiftlint:enable cyclomatic_complexity switch_case_alignment

    private static func fontError(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Phông chữ không được để trống"
        }
        let normalized = ReaderFontMapper.normalizedFontName(value)
        return normalized == "System" && trimmed.lowercased() != "system" ? "Phông chữ không hợp lệ" : nil
    }

    /// Single trim rule for PREFETCH_COUNT shared by editor validation,
    /// `SettingsStore.setValue`, and `SettingsStore.intValue`: trim surrounding
    /// whitespace, then `Int`, then finite-`Double` truncation (so `"20.0"` and
    /// `"20.9"` mean `20`, `"1e3"` means `1000`, `"+20"` means `20`).
    /// Returns nil when nothing numeric remains. Range checks (`0...1000 else 3`,
    /// BR-08) stay with the callers — this parser never clamps.
    static func parsedPrefetchCount(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let intValue = Int(trimmed) {
            return intValue
        }
        if let doubleValue = Double(trimmed), doubleValue.isFinite {
            return Int(doubleValue)
        }
        return nil
    }
}

enum SettingsViewModel {
    // swiftlint:disable trailing_comma
    private static let descriptors: [String: SettingDescriptor] = [
        "BOOKS_API_URL": SettingDescriptor(
            key: "BOOKS_API_URL",
            label: "URL Danh mục",
            placeholder: "https://...",
            description: "Endpoint Supabase get-exported-books",
            defaultValue: "https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books",
            allowsVerbatimSave: false
        ),
        "OPENAI_API_URL": SettingDescriptor(
            key: "OPENAI_API_URL",
            label: "URL OpenAI",
            placeholder: "http://localhost:8317/v1/chat/completions",
            description: "Endpoint chat/completions (ATS cho phép localhost)",
            defaultValue: "http://localhost:8317/v1/chat/completions",
            allowsVerbatimSave: false
        ),
        "OPENAI_MODEL": SettingDescriptor(
            key: "OPENAI_MODEL",
            label: "Mô hình",
            placeholder: "gpt-4o",
            description: "Tên model, mặc định gpt-4o",
            defaultValue: "gpt-4o",
            allowsVerbatimSave: false
        ),
        "AI_PROVIDER": SettingDescriptor(
            key: "AI_PROVIDER",
            label: "Nhà cung cấp",
            placeholder: "openai",
            description: "Chỉ openai, không phân biệt hoa thường",
            defaultValue: "openai",
            allowsVerbatimSave: false
        ),
        "AI_CUSTOM_HEADERS": SettingDescriptor(
            key: "AI_CUSTOM_HEADERS",
            label: "Headers tùy chỉnh (JSON)",
            placeholder: "{\"Authorization\":\"Bearer ...\"}",
            description: "JSON object, sai cú pháp sẽ được lưu nguyên văn nhưng bỏ qua khi gửi",
            defaultValue: "",
            allowsVerbatimSave: true
        ),
        "AI_EXTRA_BODY": SettingDescriptor(
            key: "AI_EXTRA_BODY",
            label: "Body bổ sung (JSON)",
            placeholder: "{\"temperature\":0.7}",
            description: "JSON object trộn shallow vào body, sai sẽ bỏ qua",
            defaultValue: "",
            allowsVerbatimSave: true
        ),
        "AI_PROMPT": SettingDescriptor(
            key: "AI_PROMPT",
            label: "Prompt",
            placeholder: "Dịch truyện sang...",
            description: "Prompt hệ thống cho AI Rewrite (dịch, tóm tắt, viết lại)",
            defaultValue: SettingsDefaults.defaultPrompt,
            allowsVerbatimSave: false
        ),
        "PREFETCH_COUNT": SettingDescriptor(
            key: "PREFETCH_COUNT",
            label: "Số chương tải trước",
            placeholder: "3",
            description: "0..1000; ngoài khoảng không lưu (giữ giá trị cũ), khi đọc dùng 3 (BR-08)",
            defaultValue: "3",
            allowsVerbatimSave: false
        ),
        "AI_MIN_CHUNK_SIZE": SettingDescriptor(
            key: "AI_MIN_CHUNK_SIZE",
            label: "Kích thước chunk",
            placeholder: "1300",
            description: "500..10000, ngoài khoảng về 1300",
            defaultValue: "1300",
            allowsVerbatimSave: false
        ),
        "font": SettingDescriptor(
            key: "font",
            label: "Phông chữ",
            placeholder: "System",
            description: "System/Serif/Mono",
            defaultValue: "System",
            allowsVerbatimSave: false
        ),
        "fontSize": SettingDescriptor(
            key: "fontSize",
            label: "Cỡ chữ",
            placeholder: "16",
            description: "12..40, bước 1",
            defaultValue: "16",
            allowsVerbatimSave: false
        ),
        "lineHeight": SettingDescriptor(
            key: "lineHeight",
            label: "Giãn dòng",
            placeholder: "5",
            description: "1.0..50, bước 0.5",
            defaultValue: "5",
            allowsVerbatimSave: false
        ),
        "letterSpacing": SettingDescriptor(
            key: "letterSpacing",
            label: "Giãn chữ",
            placeholder: "0",
            description: "0..3.0, bước 0.1",
            defaultValue: "0",
            allowsVerbatimSave: false
        ),
    ]
    // swiftlint:enable trailing_comma

    static func descriptor(for key: String) -> SettingDescriptor {
        descriptors[key] ?? SettingDescriptor(
            key: key,
            label: key,
            placeholder: "",
            description: "",
            defaultValue: "",
            allowsVerbatimSave: false
        )
    }

    /// Row string for the PREFETCH_COUNT settings row: the effective N the
    /// prefetch manager consumes (clamped read), not the raw stored value.
    /// Tested directly (no pixel assertions); the view only renders this string.
    @MainActor
    static func prefetchCountRowValue(_ store: SettingsStore) -> String {
        "\(store.effectivePrefetchCount())"
    }
}

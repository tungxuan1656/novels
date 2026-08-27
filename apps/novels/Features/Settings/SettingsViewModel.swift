import Foundation

// swiftlint:disable switch_case_alignment

struct SettingDescriptor {
    let key: String
    let label: String
    let placeholder: String
    let description: String
    let defaultValue: String
    let allowsVerbatimSave: Bool

    // swiftlint:disable cyclomatic_complexity function_body_length
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
                if lowered.isEmpty || lowered == "openai" {
                    return nil
                }
                return "Chỉ hỗ trợ openai"
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
            case "AI_PROCESS_ACTIONS":
                if value.isEmpty {
                    return nil
                }
                guard let data = value.data(using: .utf8),
                      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                else {
                    return "JSON phải là mảng [{key,name,prompt}]"
                }
                for item in arr {
                    guard let keyValue = item["key"] as? String,
                          keyValue == "translate" || keyValue == "summary"
                    else {
                        return "key chỉ translate/summary"
                    }
                }
                return nil
            case "PREFETCH_COUNT":
                if let number = Int(value), (1 ... 10).contains(number) {
                    return nil
                }
                return "1..10, ngoài khoảng sẽ về 3"
            case "AI_MIN_CHUNK_SIZE":
                if let number = Int(value), (500 ... 5000).contains(number) {
                    return nil
                }
                return "500..5000, ngoài khoảng sẽ về 1300"
            case "fontSize":
                if let number = Double(value), (12 ... 24).contains(number) {
                    return nil
                }
                return "12..24"
            case "lineHeight":
                if let number = Double(value), (1.2 ... 2.0).contains(number) {
                    return nil
                }
                return "1.2..2.0"
            case "font":
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "Phông chữ không được để trống" : nil
            case "letterSpacing":
                if let number = Double(value), (0 ... 1.0).contains(number) {
                    return nil
                }
                return "0..1.0"
            default:
                return nil
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}

enum SettingsViewModel {
    // swiftlint:disable function_body_length
    static func descriptor(for key: String) -> SettingDescriptor {
        switch key {
            case "BOOKS_API_URL":
                return SettingDescriptor(
                    key: key,
                    label: "URL Danh mục",
                    placeholder: "https://...",
                    description: "Endpoint Supabase get-exported-books",
                    defaultValue: "https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books",
                    allowsVerbatimSave: false
                )
            case "OPENAI_API_URL":
                return SettingDescriptor(
                    key: key,
                    label: "URL OpenAI",
                    placeholder: "http://localhost:8317/v1/chat/completions",
                    description: "Endpoint chat/completions (ATS cho phép localhost)",
                    defaultValue: "http://localhost:8317/v1/chat/completions",
                    allowsVerbatimSave: false
                )
            case "OPENAI_MODEL":
                return SettingDescriptor(
                    key: key,
                    label: "Mô hình",
                    placeholder: "gpt-4o",
                    description: "Tên model, mặc định gpt-4o",
                    defaultValue: "gpt-4o",
                    allowsVerbatimSave: false
                )
            case "AI_PROVIDER":
                return SettingDescriptor(
                    key: key,
                    label: "Nhà cung cấp",
                    placeholder: "openai",
                    description: "Chỉ openai, không phân biệt hoa thường",
                    defaultValue: "openai",
                    allowsVerbatimSave: false
                )
            case "AI_CUSTOM_HEADERS":
                return SettingDescriptor(
                    key: key,
                    label: "Headers tùy chỉnh (JSON)",
                    placeholder: "{\"Authorization\":\"Bearer ...\"}",
                    description: "JSON object, sai cú pháp sẽ được lưu nguyên văn nhưng bỏ qua khi gửi",
                    defaultValue: "",
                    allowsVerbatimSave: true
                )
            case "AI_EXTRA_BODY":
                return SettingDescriptor(
                    key: key,
                    label: "Body bổ sung (JSON)",
                    placeholder: "{\"temperature\":0.7}",
                    description: "JSON object trộn shallow vào body, sai sẽ bỏ qua",
                    defaultValue: "",
                    allowsVerbatimSave: true
                )
            case "AI_PROCESS_ACTIONS":
                return SettingDescriptor(
                    key: key,
                    label: "Hành động AI (JSON)",
                    placeholder: "[{\"key\":\"translate\",\"name\":\"...\",\"prompt\":\"...\"}]",
                    description: "Mảng translate/summary, rỗng sẽ về mặc định 2 action",
                    defaultValue: SettingsDefaults.defaultActionsJSON,
                    allowsVerbatimSave: false
                )
            case "PREFETCH_COUNT":
                return SettingDescriptor(
                    key: key,
                    label: "Số chương tải trước",
                    placeholder: "3",
                    description: "1..10, ngoài khoảng về 3 (BR-08)",
                    defaultValue: "3",
                    allowsVerbatimSave: false
                )
            case "AI_MIN_CHUNK_SIZE":
                return SettingDescriptor(
                    key: key,
                    label: "Kích thước chunk",
                    placeholder: "1300",
                    description: "500..5000, ngoài khoảng về 1300",
                    defaultValue: "1300",
                    allowsVerbatimSave: false
                )
            case "font":
                return SettingDescriptor(
                    key: key,
                    label: "Phông chữ",
                    placeholder: "System",
                    description: "System/Serif/Mono",
                    defaultValue: "System",
                    allowsVerbatimSave: false
                )
            case "fontSize":
                return SettingDescriptor(
                    key: key,
                    label: "Cỡ chữ",
                    placeholder: "16",
                    description: "12..24, bước 1",
                    defaultValue: "16",
                    allowsVerbatimSave: false
                )
            case "lineHeight":
                return SettingDescriptor(
                    key: key,
                    label: "Giãn dòng",
                    placeholder: "1.5",
                    description: "1.2..2.0, bước 0.1",
                    defaultValue: "1.5",
                    allowsVerbatimSave: false
                )
            case "letterSpacing":
                return SettingDescriptor(
                    key: key,
                    label: "Giãn chữ",
                    placeholder: "0",
                    description: "0..1.0, bước 0.1",
                    defaultValue: "0",
                    allowsVerbatimSave: false
                )
            default:
                return SettingDescriptor(
                    key: key,
                    label: key,
                    placeholder: "",
                    description: "",
                    defaultValue: "",
                    allowsVerbatimSave: false
                )
        }
    } // swiftlint:enable function_body_length
}

// swiftlint:enable switch_case_alignment

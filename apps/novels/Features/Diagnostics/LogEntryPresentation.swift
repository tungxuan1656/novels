import Foundation

extension LogEntry {
    var diagnosticTitle: String {
        if LogEntry.isMutedCancel(self) {
            return "Đã hủy"
        }
        if kind == .api {
            if errorDomain == "AIClientError.invalidStructuredOutput" {
                return "Sai JSON đầu ra"
            }
            if errorDomain == "AIClientError.noResponse" {
                return "Không có nội dung"
            }
            if let statusCode, statusCode >= 400 {
                return "HTTP \(statusCode)"
            }
            if timeoutKind != nil || (errorDomain == NSURLErrorDomain && errorCode == URLError.timedOut.rawValue) {
                return "Hết thời gian chờ"
            }
            if LogEntry.isError(self) {
                return "Lỗi yêu cầu"
            }
            if let statusCode {
                return "Đã nhận HTTP \(statusCode)"
            }
            return "Đang gửi"
        }
        // swiftlint:disable switch_case_alignment
        switch event {
            case "chunk.start": return "Bắt đầu xử lý đoạn"
            case "chunk.success": return "Đã xử lý đoạn"
            case "chunk.fail": return "Xử lý đoạn thất bại"
            case "cache.hit": return "Đọc từ bộ nhớ đệm"
            case "cache.miss": return "Chưa có bản đã xử lý"
            case "cache.save": return "Đã lưu chương"
            case "dedup.shared": return "Chờ yêu cầu đang chạy"
            case "prefetch.batchCheck": return "Kiểm tra chương tải trước"
            case "prefetch.skip": return "Bỏ qua tải trước"
            case "prefetch.cancel": return "Dừng tải trước"
            case "prefetch.error-continue": return "Lỗi tải trước"
            default: return event ?? "Sự kiện"
        }
        // swiftlint:enable switch_case_alignment
    }

    var diagnosticExplanation: String? {
        if LogEntry.isMutedCancel(self) {
            if let reason = LogEntry.cancelReason(of: self) {
                // swiftlint:disable switch_case_alignment
                switch reason {
                    case "chapterChange": return "Đã chuyển chương."
                    case "modeChange": return "Đã đổi chế độ AI."
                    case "disappear": return "Đã rời màn hình đọc."
                    default: return "Đã chủ động dừng tải trước."
                }
                // swiftlint:enable switch_case_alignment
            }
            return "Yêu cầu bị hủy trước khi hoàn tất, không tự thử lại. Máy chủ có thể vẫn tiếp tục xử lý."
        }
        if errorDomain == "AIClientError.invalidStructuredOutput" {
            return "Đã nhận phản hồi nhưng JSON đầu ra thiếu, bị từ chối, chưa hoàn tất hoặc không đúng định dạng."
        }
        if errorDomain == "AIClientError.noResponse" {
            return "Đã nhận phản hồi nhưng không tìm thấy nội dung AI có thể sử dụng."
        }
        if event == "chunk.fail", errorDomain?.contains("Bilingual") == true {
            return "Đầu ra song ngữ không hợp lệ: kiểm tra ID đoạn và nội dung của cả hai ngôn ngữ."
        }
        if let statusCode, statusCode >= 400 {
            // swiftlint:disable switch_case_alignment
            switch statusCode {
                case 401, 403:
                    return "Máy chủ từ chối xác thực hoặc quyền truy cập. Kiểm tra khóa API và cấu hình provider."
                case 429: return "Máy chủ giới hạn yêu cầu hoặc hết hạn mức. Kiểm tra hạn mức và thời gian thử lại."
                case 500 ... 599: return "Máy chủ hoặc gateway gặp lỗi. Xem phản hồi JSON để biết chi tiết."
                default: return "Máy chủ từ chối yêu cầu. Xem phản hồi JSON để kiểm tra model và tham số."
            }
            // swiftlint:enable switch_case_alignment
        }
        if errorDomain == NSURLErrorDomain {
            if errorCode == URLError.timedOut.rawValue {
                return "Chưa nhận đủ phản hồi trong thời gian cho phép. Máy chủ có thể vẫn đang xử lý."
            }
            return "Lỗi kết nối trước khi nhận đủ phản hồi. Kiểm tra mạng và địa chỉ máy chủ."
        }
        if LogEntry.isError(self) {
            return "Xử lý thất bại ở bước này. Xem mã lỗi và các mục cùng chương để xác định nguyên nhân."
        }
        return nil
    }
}

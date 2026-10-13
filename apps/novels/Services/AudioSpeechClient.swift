import Foundation

nonisolated struct AudioSpeechClient: Sendable {
    static let endpoint = "https://9router.tungxuan.io.vn/v1/audio/speech"
    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func audio(for sentence: String, apiKey: String, model: String) async throws -> Data {
        try Task.checkCancellation()
        let request = try Self.request(sentence: sentence, apiKey: apiKey, model: model)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw AudioSpeechError.invalidAudio }
        guard (200 ... 299).contains(response.statusCode) else {
            throw AudioSpeechError.httpStatus(response.statusCode)
        }
        if let mime = response.mimeType {
            guard mime.hasPrefix("audio/") || mime == "application/octet-stream" else {
                throw AudioSpeechError.invalidAudio
            }
        }
        guard !data.isEmpty, data.count <= 10 * 1024 * 1024 else { throw AudioSpeechError.invalidAudio }
        return data
    }

    private static func request(sentence: String, apiKey: String, model: String) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains(where: \.isNewline) else { throw AudioSpeechError.invalidKey }
        guard !model.isEmpty else { throw AudioSpeechError.invalidModel }
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AudioSpeechError.emptyInput
        }
        guard let url = URL(string: endpoint) else { throw AudioSpeechError.invalidAudio }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SpeechInput(model: model, input: sentence))
        return request
    }

    private struct SpeechInput: Encodable {
        let model: String
        let input: String
    }
}

nonisolated enum AudioSpeechError: LocalizedError, Equatable {
    case invalidKey
    case invalidModel
    case emptyInput
    case httpStatus(Int)
    case invalidAudio
    case playbackFailed

    var errorDescription: String? {
        // swiftlint:disable switch_case_alignment
        switch self {
            case .invalidKey:
                "Hãy thiết lập API key audio hợp lệ trong Cài đặt."
            case .invalidModel:
                "Hãy thiết lập model audio trong Cài đặt."
            case .emptyInput:
                "Không có câu để phát âm."
            case let .httpStatus(status):
                "API audio trả về lỗi HTTP \(status). Kiểm tra API key, model hoặc thử lại."
            case .invalidAudio:
                "API audio không trả về audio hợp lệ (tối đa 10 MB)."
            case .playbackFailed:
                "Không thể phát audio này. Hãy thử lại hoặc chuyển sang Apple."
        }
        // swiftlint:enable switch_case_alignment
    }
}

import Foundation

// swiftlint:disable trailing_comma

actor AIClient {
    private let settings: SettingsStore
    private let session: URLSession

    init(settings: SettingsStore, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    // swiftlint:disable:next function_body_length
    func complete(prompt: String, chunk: String) async throws -> String {
        let urlString: String = await MainActor.run {
            let trimmed = settings.openaiAPIURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "http://localhost:8317/v1/chat/completions" : settings.openaiAPIURL
        }
        let model: String = await MainActor.run {
            settings.openaiModel.isEmpty ? "gpt-4o" : settings.openaiModel
        }
        let headers: [String: String] = await MainActor.run {
            settings.effectiveHeaders()
        }
        let extra: [String: Any] = await MainActor.run {
            settings.effectiveExtraBody()
        }
        guard let url = URL(string: urlString) else {
            throw AIClientError.httpError(0, "bad url")
        }
        var lastError: Error?
        for attempt in 0 ..< 3 {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                var body: [String: Any] = [
                    "model": model,
                    "messages": [
                        ["role": "system", "content": prompt],
                        ["role": "user", "content": chunk],
                    ],
                ]
                for (key, value) in extra {
                    body[key] = value
                }
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.timeoutInterval = 15
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                    throw AIClientError.httpError(
                        http.statusCode,
                        HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                    )
                }
                let decoded = try JSONDecoder().decode(AIChatResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content,
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    throw AIClientError.noResponse
                }
                return content
            } catch {
                lastError = error
                if case AIClientError.noResponse = error {
                    throw error
                }
                if case AIClientError.httpError = error {
                    throw error
                }
                if attempt < 2 {
                    let delay: UInt64 = attempt == 0 ? 1_000_000_000 : 2_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                } else {
                    throw AIClientError.httpError(0, "AI processing failed.")
                }
            }
        }
        throw lastError ?? AIClientError.httpError(0, "AI processing failed.")
    }
}

// swiftlint:enable trailing_comma

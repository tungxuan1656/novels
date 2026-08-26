import Foundation

actor CatalogService {
    private let settingsStore: SettingsStore
    private let session: URLSession

    init(settingsStore: SettingsStore, session: URLSession = .shared) {
        self.settingsStore = settingsStore
        self.session = session
    }

    func fetchCatalog() async throws -> [ExportedBook] {
        let urlString: String = await MainActor.run {
            let trimmed = settingsStore.booksAPIURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "https://iqtndkcyrsmptlrepaks.supabase.co/functions/v1/get-exported-books"
            }
            return trimmed
        }
        guard let url = URL(string: urlString) else {
            throw CatalogError.network(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data()
        request.timeoutInterval = 15

        let data: Data
        do {
            let result = try await session.data(for: request)
            data = result.0
        } catch let error as URLError {
            throw CatalogError.network(error)
        } catch {
            if let urlError = error as? URLError {
                throw CatalogError.network(urlError)
            }
            throw error
        }

        let decoded: CatalogResponse
        do {
            decoded = try JSONDecoder().decode(CatalogResponse.self, from: data)
        } catch {
            throw CatalogError.decoding(error)
        }

        if !decoded.success {
            throw CatalogError.serverMessage(decoded.message ?? "Không tải được danh mục, thử lại")
        }
        return decoded.data
    }
}

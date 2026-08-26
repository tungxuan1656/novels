import Foundation

enum CatalogError: Error, Equatable {
    case serverMessage(String)
    case network(URLError)
    case decoding(Error)

    static func == (lhs: CatalogError, rhs: CatalogError) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}

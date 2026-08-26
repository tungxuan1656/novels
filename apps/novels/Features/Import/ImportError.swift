import Foundation

enum ImportError: Error, Equatable {
    case invalidPackage
    case downloadFailed
}

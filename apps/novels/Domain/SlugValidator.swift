import Foundation

enum SlugValidator {
    static func isValid(_ slug: String) -> Bool {
        if slug.isEmpty {
            return false
        }
        if slug == "." || slug == ".." {
            return false
        }
        if slug.hasPrefix("/") {
            return false
        }
        if slug.contains("/") || slug.contains("\\") {
            return false
        }
        if slug.contains("..") {
            return false
        }
        return true
    }
}

import Foundation

// The categories a listing can belong to.
enum Category: String, Codable, CaseIterable, Sendable {
    case electronics
    case furniture
    case clothing
    case sports
    case books
    case other
}

extension Category {
    // Name shown in the UI, e.g. "Electronics".
    var displayName: String {
        rawValue.capitalized
    }
}

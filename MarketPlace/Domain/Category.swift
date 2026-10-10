import Foundation

enum Category: String, Codable, CaseIterable, Sendable {
    case electronics
    case furniture
    case clothing
    case sports
    case books
    case other
}

extension Category {
    var displayName: String {
        rawValue.capitalized
    }
}

import Foundation

struct ListingDraft: Equatable, Sendable {
    var title = ""
    var details = ""
    // Kept as text so the editor can show exactly what the user typed.
    var priceText = ""
    var category: Category = .other
    var images: [ListingImage] = []
}

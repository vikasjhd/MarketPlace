import Foundation

// The editable fields of a listing while the user types in the editor.
struct ListingDraft: Equatable, Sendable {
    var title = ""
    var details = ""
    // Kept as text so the editor can show exactly what the user typed.
    var priceText = ""
    var category: Category = .other
    var images: [ListingImage] = []
}

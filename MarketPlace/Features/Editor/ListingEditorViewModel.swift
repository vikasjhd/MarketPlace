import Foundation
import Observation

@MainActor
@Observable
final class ListingEditorViewModel {
    var draft: ListingDraft
    private(set) var issues: [ValidationIssue] = []

    // nil means we are creating a new listing.
    @ObservationIgnored private let listingID: UUID?

    init(listing: Listing?) {
        listingID = listing?.id
        if let listing {
            draft = ListingDraft(
                title: listing.title,
                details: listing.details,
                priceText: Self.priceText(cents: listing.priceCents),
                category: listing.category,
                images: listing.images
            )
        } else {
            draft = ListingDraft()
        }
    }

    var isNew: Bool {
        listingID == nil
    }

    func message(for field: ValidationIssue.Field) -> String? {
        issues.first { $0.field == field }?.message
    }

    // Returns true when the listing was saved and the editor can close.
    func save(to repository: ListingRepository) throws -> Bool {
        issues = ListingValidator.validate(draft)
        guard issues.isEmpty else { return false }

        if let listingID {
            try repository.update(id: listingID, with: draft)
        } else {
            _ = try repository.create(draft)
        }
        return true
    }

    // 150050 paise becomes "1500.50"; whole rupees show without decimals.
    private static func priceText(cents: Int) -> String {
        let rupees = cents / 100
        let paise = cents % 100
        if paise == 0 {
            return "\(rupees)"
        }
        return String(format: "%d.%02d", rupees, paise)
    }
}

import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class ListingEditorViewModel {
    var draft: ListingDraft
    private(set) var issues: [ValidationIssue] = []

    // nil means we are creating a new listing.
    @ObservationIgnored private let listingID: UUID?
    // Files added or removed in this editor, so we can clean up on save or cancel.
    @ObservationIgnored private var addedFilenames: [String] = []
    @ObservationIgnored private var removedFilenames: [String] = []

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

    var photosLeft: Int {
        max(0, ListingValidator.maxImages - draft.images.count)
    }

    func message(for field: ValidationIssue.Field) -> String? {
        issues.first { $0.field == field }?.message
    }

    func addPhotos(_ items: [PhotosPickerItem], fileStore: ImageFileStore) async throws {
        for item in items {
            if let data = try await item.loadTransferable(type: Data.self) {
                try await addPhoto(data, fileStore: fileStore)
            }
        }
    }

    func addPhoto(_ data: Data, fileStore: ImageFileStore) async throws {
        guard photosLeft > 0 else { return }
        let filename = try await fileStore.save(data)
        addedFilenames.append(filename)
        draft.images.append(ListingImage(id: UUID(), localFilename: filename, remoteURL: nil))
    }

    func removePhoto(_ image: ListingImage) {
        draft.images.removeAll { $0.id == image.id }
        if let filename = image.localFilename {
            removedFilenames.append(filename)
        }
    }

    // Returns true when the listing was saved and the editor can close.
    func save(to repository: ListingRepository, fileStore: ImageFileStore) async throws -> Bool {
        issues = ListingValidator.validate(draft)
        guard issues.isEmpty else { return false }

        if let listingID {
            try repository.update(id: listingID, with: draft)
        } else {
            _ = try repository.create(draft)
        }

        for filename in removedFilenames {
            await fileStore.delete(filename)
        }
        return true
    }

    func cancel(fileStore: ImageFileStore) async {
        for filename in addedFilenames {
            await fileStore.delete(filename)
        }
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

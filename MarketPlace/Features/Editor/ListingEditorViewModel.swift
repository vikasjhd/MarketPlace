import Foundation
import Observation
import PhotosUI
import SwiftUI

// State and actions for the editor: the draft, photos, validation and save.
@MainActor
@Observable
final class ListingEditorViewModel {
    var draft: ListingDraft
    // Validation problems from the last Save tap.
    private(set) var issues: [ValidationIssue] = []

    // nil means we are creating a new listing.
    @ObservationIgnored private let listingID: UUID?
    // Files added or removed in this editor, so we can clean up on save or cancel.
    @ObservationIgnored private var addedFilenames: [String] = []
    @ObservationIgnored private var removedFilenames: [String] = []

    // Fills the draft from the listing when editing, or starts empty.
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

    // True when creating, false when editing.
    var isNew: Bool {
        listingID == nil
    }

    // How many more photos can be added.
    var photosLeft: Int {
        max(0, ListingValidator.maxImages - draft.images.count)
    }

    // The error text for one field, if any.
    func message(for field: ValidationIssue.Field) -> String? {
        issues.first { $0.field == field }?.message
    }

    // Loads photos chosen in the photo picker and saves them.
    func addPhotos(_ items: [PhotosPickerItem], fileStore: ImageFileStore) async throws {
        for item in items {
            if let data = try await item.loadTransferable(type: Data.self) {
                try await addPhoto(data, fileStore: fileStore)
            }
        }
    }

    // Saves one photo (downsampled) and adds it to the draft.
    func addPhoto(_ data: Data, fileStore: ImageFileStore) async throws {
        guard photosLeft > 0 else { return }
        let filename = try await fileStore.save(data)
        addedFilenames.append(filename)
        draft.images.append(ListingImage(id: UUID(), localFilename: filename, remoteURL: nil))
    }

    // Removes a photo from the draft. Its file is deleted after Save.
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

    // Deletes photo files added in this editor, because they won't be used.
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

import SwiftUI

struct ListingRow: View {
    let listing: Listing

    var body: some View {
        HStack {
            ThumbnailView(image: listing.images.first, pointSize: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.headline)
                Text(Formatters.price(cents: listing.priceCents))
                Text(listing.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if listing.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Favorite")
            }
        }
        // VoiceOver reads the whole row as one item.
        .accessibilityElement(children: .combine)
    }
}

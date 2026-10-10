import SwiftUI

// Shows one listing: photos, details, favorite and edit buttons.
struct ListingDetailView: View {
    let listingID: UUID

    @Environment(ListingRepository.self) private var repository
    @State private var showEditor = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        if let listing = repository.listing(id: listingID) {
            content(for: listing)
        } else {
            ContentUnavailableView("Listing not found", systemImage: "questionmark")
        }
    }

    // The screen for a listing that exists.
    private func content(for listing: Listing) -> some View {
        let isMine = listing.ownerID == Listing.currentUserID

        return ScrollView {
            if !listing.images.isEmpty {
                gallery(listing.images)
            }
            info(for: listing, isMine: isMine)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                toggleFavorite()
            } label: {
                Label(
                    listing.isFavorite ? "Remove from favorites" : "Add to favorites",
                    systemImage: listing.isFavorite ? "heart.fill" : "heart"
                )
            }
            if isMine {
                Button("Edit") {
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                ListingEditorView(listing: listing)
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // Swipeable photos.
    private func gallery(_ images: [ListingImage]) -> some View {
        TabView {
            ForEach(images) { image in
                ThumbnailView(image: image, pointSize: 300)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 320)
    }

    // Title, price, description, seller and dates.
    private func info(for listing: Listing, isMine: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(listing.title)
                .font(.title)
                .bold()
            Text(Formatters.price(cents: listing.priceCents))
                .font(.title2)
            Text(listing.category.displayName)
                .foregroundStyle(.secondary)

            if listing.syncState == .failed {
                failedSection(message: listing.syncError ?? "Could not sync this listing.")
            }

            if !listing.details.isEmpty {
                Text(listing.details)
            }

            Divider()
            Text("Seller: \(isMine ? "You" : listing.ownerID)")
            Text("Posted: \(listing.createdAt.formatted(date: .abbreviated, time: .shortened))")
            Text("Updated: \(listing.updatedAt.formatted(date: .abbreviated, time: .shortened))")
        }
    }

    // Shown when the server rejected this listing.
    private func failedSection(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Button("Edit to fix") {
                showEditor = true
            }
        }
    }

    // Flips favorite, and shows an alert if saving fails.
    private func toggleFavorite() {
        do {
            try repository.toggleFavorite(id: listingID)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

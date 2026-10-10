import SwiftUI

struct ListingsView: View {
    @Environment(ListingRepository.self) private var repository
    @State private var viewModel = ListingsViewModel()
    @State private var showEditor = false

    var body: some View {
        let listings = viewModel.visibleListings(from: repository.listings)

        List(listings) { listing in
            NavigationLink(value: listing.id) {
                ListingRow(listing: listing)
            }
        }
        .overlay {
            if repository.listings.isEmpty {
                ContentUnavailableView(
                    "No listings yet",
                    systemImage: "tag",
                    description: Text("Tap + to add your first listing.")
                )
            } else if listings.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
        .navigationTitle("Marketplace")
        .navigationDestination(for: UUID.self) { id in
            ListingDetailView(listingID: id)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search titles")
        .toolbar {
            Button {
                showEditor = true
            } label: {
                Label("New listing", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                ListingEditorView(listing: nil)
            }
        }
    }
}

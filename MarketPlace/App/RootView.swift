import SwiftUI

struct RootView: View {
    @Environment(ListingRepository.self) private var repository
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ListingsView()
        }
        .task {
            do {
                try repository.load()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert("Could not load listings", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
}

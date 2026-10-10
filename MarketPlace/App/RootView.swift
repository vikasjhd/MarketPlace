import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            Text("No listings yet")
                .foregroundStyle(.secondary)
                .navigationTitle("Marketplace")
        }
    }
}

#Preview {
    RootView()
}

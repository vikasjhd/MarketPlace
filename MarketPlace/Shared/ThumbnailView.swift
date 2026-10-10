import SwiftUI

// Shows one listing photo at a fixed size, or a placeholder.
struct ThumbnailView: View {
    let image: ListingImage?
    let pointSize: CGFloat

    @Environment(\.imageLoader) private var imageLoader
    @Environment(\.displayScale) private var displayScale
    @State private var uiImage: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: pointSize, height: pointSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
        // Cancelled automatically when the view goes off screen.
        .task(id: image?.id) {
            guard let image else { return }
            uiImage = await imageLoader.image(for: image, pixelSize: Int(pointSize * displayScale))
        }
    }
}

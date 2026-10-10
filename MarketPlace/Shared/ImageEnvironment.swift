import SwiftUI

// Lets views get the photo store with @Environment(\.imageFileStore).
private struct ImageFileStoreKey: EnvironmentKey {
    static let defaultValue = ImageFileStore.app
}

// Lets views get the image loader with @Environment(\.imageLoader).
private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue = ImageLoader(
        fileStore: ImageFileStoreKey.defaultValue,
        session: .mock,
        cacheFolder: URL.cachesDirectory.appending(path: "RemoteImages")
    )
}

extension EnvironmentValues {
    var imageFileStore: ImageFileStore {
        get { self[ImageFileStoreKey.self] }
        set { self[ImageFileStoreKey.self] = newValue }
    }

    var imageLoader: ImageLoader {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}

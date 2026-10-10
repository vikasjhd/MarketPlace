import SwiftUI

private struct ImageFileStoreKey: EnvironmentKey {
    static let defaultValue = ImageFileStore(
        folder: URL.applicationSupportDirectory.appending(path: "ListingImages")
    )
}

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

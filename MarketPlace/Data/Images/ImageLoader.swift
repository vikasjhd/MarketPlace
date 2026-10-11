import UIKit

// Gives views images at the size they need, using NSCache (RAM) and the Caches folder (phone storage).
actor ImageLoader {
    private let fileStore: ImageFileStore
    private let session: URLSession
    private let cacheFolder: URL
    // NSCache: shrunk images kept in RAM. iOS empties it when memory is low.
    private let cache = NSCache<NSString, UIImage>()

    init(fileStore: ImageFileStore, session: URLSession, cacheFolder: URL) {
        self.fileStore = fileStore
        self.session = session
        self.cacheFolder = cacheFolder
        cache.totalCostLimit = 40 * 1024 * 1024
    }

    // Returns the image at this pixel size, or nil if it can't be loaded.
    func image(for image: ListingImage, pixelSize: Int) async -> UIImage? {
        let key = "\(image.id.uuidString)-\(pixelSize)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let data = await imageData(for: image),
              let thumbnail = ImageDownsampler.thumbnail(from: data, maxPixelSize: pixelSize) else {
            return nil
        }

        let result = UIImage(cgImage: thumbnail)
        cache.setObject(result, forKey: key, cost: thumbnail.bytesPerRow * thumbnail.height)
        return result
    }

    // Order: my own photo in Application Support, then the Caches folder, then download.
    private func imageData(for image: ListingImage) async -> Data? {
        if let filename = image.localFilename, let data = try? await fileStore.read(filename) {
            return data
        }
        guard let url = image.remoteURL else {
            return nil
        }

        let cacheFile = cacheFolder.appending(path: "\(image.id.uuidString).jpg")
        if let data = try? Data(contentsOf: cacheFile) {
            return data
        }

        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }
        try? FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
        try? data.write(to: cacheFile, options: .atomic)
        return data
    }
}

import ImageIO
import UIKit

// Makes smaller versions of images without decoding the full-size picture.
enum ImageDownsampler {
    // Decodes only a small version of the image, never the full-size bitmap.
    static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    // Makes a smaller JPEG, used before saving a picked photo.
    static func downsample(_ data: Data, maxPixelSize: Int, quality: Double = 0.8) -> Data? {
        guard let image = thumbnail(from: data, maxPixelSize: maxPixelSize) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: quality)
    }
}

import Foundation

actor ImageFileStore {
    private let folder: URL

    init(folder: URL) {
        self.folder = folder
    }

    // Downsamples first, so a full-size photo is never stored.
    func save(_ imageData: Data) throws -> String {
        guard let jpeg = ImageDownsampler.downsample(imageData, maxPixelSize: 1600) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).jpg"
        try jpeg.write(to: folder.appending(path: filename), options: .atomic)
        return filename
    }

    func read(_ filename: String) throws -> Data {
        try Data(contentsOf: folder.appending(path: filename))
    }

    func delete(_ filename: String) {
        // A file that is already gone is fine; there is nothing else to clean up.
        try? FileManager.default.removeItem(at: folder.appending(path: filename))
    }
}

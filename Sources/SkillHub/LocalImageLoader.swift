import AppKit
import ImageIO

/// File size bounds compressed input, not decoded memory. Decode a thumbnail
/// directly so a highly compressed image cannot retain its full-size bitmap.
enum LocalImageLoader {
    static let maxFileBytes = 10_000_000
    static let previewPixelSize = 1_600

    static func load(_ url: URL, maxPixelSize: Int = previewPixelSize) -> NSImage? {
        guard let thumbnail = thumbnail(url, maxPixelSize: maxPixelSize) else { return nil }
        return NSImage(cgImage: thumbnail, size: .zero)
    }

    static func thumbnail(_ url: URL, maxPixelSize: Int = previewPixelSize) -> CGImage? {
        guard url.isFileURL, maxPixelSize > 0,
              let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true, (values.fileSize ?? Int.max) <= maxFileBytes,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        // Also bound the actual read if the file grows after checking attributes.
        guard let data = try? handle.read(upToCount: maxFileBytes + 1), data.count <= maxFileBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixelSize, previewPixelSize),
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: false
        ] as CFDictionary)
    }
}

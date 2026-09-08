import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import SkillHub

final class ImageMemoryTests: XCTestCase {
    func testHighlyCompressedImageDecodesToBoundedThumbnail() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try writePNG(to: url, width: 4_096, height: 4_096)
        let fileSize = try XCTUnwrap(url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        XCTAssertLessThan(fileSize, LocalImageLoader.maxFileBytes)
        let image = try XCTUnwrap(LocalImageLoader.thumbnail(url))
        XCTAssertEqual(image.width, 1_600)
        XCTAssertEqual(image.height, 1_600)
        let decodedBytes = image.bytesPerRow * image.height
        XCTAssertLessThanOrEqual(decodedBytes, 11_000_000)
        print("Image memory: compressed=\(fileSize) bytes, full RGBA=67108864 bytes, thumbnail=\(decodedBytes) bytes")

        let inline = try XCTUnwrap(LocalImageLoader.thumbnail(url, maxPixelSize: 256))
        XCTAssertEqual(inline.width, 256)
        XCTAssertEqual(inline.height, 256)
        XCTAssertLessThanOrEqual(inline.bytesPerRow * inline.height, 300_000)
        let clamped = try XCTUnwrap(LocalImageLoader.thumbnail(url, maxPixelSize: Int.max))
        XCTAssertEqual(clamped.width, LocalImageLoader.previewPixelSize)
    }

    func testPreservesAspectRatioAndDoesNotUpscaleSmallImages() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try writePNG(to: url, width: 2_000, height: 1_000)
        let landscape = try XCTUnwrap(LocalImageLoader.thumbnail(url))
        XCTAssertEqual(landscape.width, 1_600)
        XCTAssertEqual(landscape.height, 800)
        try writePNG(to: url, width: 40, height: 80)
        let small = try XCTUnwrap(LocalImageLoader.thumbnail(url))
        XCTAssertEqual(small.width, 40)
        XCTAssertEqual(small.height, 80)
        XCTAssertNotNil(LocalImageLoader.load(url))
    }

    func testRejectsRemoteMissingInvalidOversizedAndDirectoryInputs() throws {
        XCTAssertNil(LocalImageLoader.thumbnail(URL(string: "https://example.com/image.png")!))
        XCTAssertNil(LocalImageLoader.thumbnail(FileManager.default.temporaryDirectory))
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(LocalImageLoader.thumbnail(url))
        try Data("not an image".utf8).write(to: url)
        XCTAssertNil(LocalImageLoader.thumbnail(url))
        try Data(repeating: 0, count: LocalImageLoader.maxFileBytes + 1).write(to: url)
        XCTAssertNil(LocalImageLoader.thumbnail(url))
        XCTAssertNil(LocalImageLoader.thumbnail(url, maxPixelSize: 0))
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    }

    private func writePNG(to url: URL, width: Int, height: Int) throws {
        try autoreleasepool {
            let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.7, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let image = try XCTUnwrap(context.makeImage())
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,
                UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}

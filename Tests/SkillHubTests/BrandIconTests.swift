import AppKit
import XCTest
import SwiftUI
@testable import SkillHub

final class BrandIconTests: XCTestCase {
    @MainActor func testClaudeIconActuallyRendersOrangePixels() throws {
        XCTAssertNotNil(ClaudeBrandIcon.image)
        let renderer = ImageRenderer(content: ClaudeBrandIcon().frame(width: 32, height: 32))
        let image = try XCTUnwrap(renderer.nsImage)
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        var orangePixels = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   color.alphaComponent > 0.5, color.redComponent > 0.6,
                   color.redComponent > color.greenComponent + 0.15 {
                    orangePixels += 1
                }
            }
        }
        XCTAssertGreaterThan(orangePixels, 50, "The icon must render visible brand-colored pixels, not an empty view")
    }
    func testClaudeVectorIconLoadsFromResources() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ClaudeIcon", withExtension: "pdf"))
        let image = try XCTUnwrap(NSImage(contentsOf: url))
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertTrue(image.representations.contains { $0 is NSPDFImageRep })
    }
}

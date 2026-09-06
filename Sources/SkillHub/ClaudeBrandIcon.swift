import AppKit
import SwiftUI

struct ClaudeBrandIcon: View {
    // Standalone PDF resources need explicit loading rather than SwiftUI's named asset lookup.
    static let image: NSImage? = {
        guard let url = Bundle.module.url(forResource: "ClaudeIcon", withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = false
        return image
    }()

    var body: some View {
        if let image = Self.image {
            Image(nsImage: image).renderingMode(.original).resizable().scaledToFit()
        } else {
            Image(systemName: "sparkle").foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
        }
    }
}

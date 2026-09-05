import XCTest
import SwiftUI
@testable import SkillHub

final class ScrollAndToolbarTests: XCTestCase {
    @MainActor func testOverlayPolicyReachesNestedAndNewScrollViews() {
        let root = NSView()
        let outer = NSScrollView()
        let document = NSView()
        let inner = NSScrollView()
        outer.scrollerStyle = .legacy
        inner.scrollerStyle = .legacy
        outer.autohidesScrollers = false
        inner.autohidesScrollers = false
        root.addSubview(outer)
        outer.documentView = document
        document.addSubview(inner)
        ScrollBehavior.apply(to: root)
        XCTAssertEqual(outer.scrollerStyle, .overlay)
        XCTAssertEqual(inner.scrollerStyle, .overlay)
        XCTAssertTrue(outer.autohidesScrollers)
        XCTAssertTrue(inner.autohidesScrollers)

        let later = NSScrollView()
        later.scrollerStyle = .legacy
        document.addSubview(later)
        ScrollBehavior.apply(to: root)
        XCTAssertEqual(later.scrollerStyle, .overlay)
    }

    @MainActor func testToolbarFitsAvailableWidthWithConsistentHeight() {
        for width: CGFloat in [620, 1000] {
            let view = NSHostingView(rootView:
                CollectionToolbar(search: .constant(""), category: .constant("All categories"),
                                  sort: .constant("Name"), favorites: .constant(false),
                                  categories: ["Development", "Writing"], importCollection: {}, exportCollection: {})
                    .frame(width: width)
            )
            view.frame = NSRect(x: 0, y: 0, width: width, height: 36)
            view.layoutSubtreeIfNeeded()
            XCTAssertEqual(view.fittingSize.height, 36, accuracy: 1)
            XCTAssertLessThanOrEqual(view.fittingSize.width, width)
        }
    }
}

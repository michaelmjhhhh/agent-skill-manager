import AppKit
import SwiftUI

/// Configure transient scrollers after content updates, never on every AppKit event.
@MainActor enum ScrollBehavior {
    private static let pending = NSHashTable<NSWindow>.weakObjects()
    private static var scheduled = false
    private(set) static var passCount = 0

    static func apply(to view: NSView) {
        if let scroll = view as? NSScrollView {
            if scroll.scrollerStyle != .overlay { scroll.scrollerStyle = .overlay }
            if !scroll.autohidesScrollers { scroll.autohidesScrollers = true }
        }
        for child in view.subviews { apply(to: child) }
    }

    static func schedule(in window: NSWindow?) {
        guard let window else { return }
        pending.add(window)
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { flush() }
    }

    static func flush() {
        let windows = pending.allObjects
        pending.removeAllObjects()
        scheduled = false
        for window in windows {
            if let content = window.contentView {
                apply(to: content)
                passCount += 1
            }
        }
    }
}

struct ScrollPolicyUpdate: NSViewRepresentable {
    final class Anchor: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            ScrollBehavior.schedule(in: window)
        }
    }
    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ nsView: Anchor, context: Context) {
        ScrollBehavior.schedule(in: nsView.window)
    }
}

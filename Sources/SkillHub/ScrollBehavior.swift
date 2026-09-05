import AppKit

/// App-local policy: use native transient overlay scrollers, regardless of the
/// system's legacy "Always" preference. AppKit owns their scrolling/fade behavior.
enum ScrollBehavior {
    static func apply(to view: NSView) {
        if let scroll = view as? NSScrollView {
            if scroll.scrollerStyle != .overlay { scroll.scrollerStyle = .overlay }
            if !scroll.autohidesScrollers { scroll.autohidesScrollers = true }
        }
        for child in view.subviews { apply(to: child) }
    }
}

final class HubAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidUpdate(_ notification: Notification) {
        // Covers dynamically inserted Markdown tables/code blocks, sheets and
        // TextEditors as well as the main panes. No global defaults or swizzling.
        for window in NSApp.windows {
            if let content = window.contentView { ScrollBehavior.apply(to: content) }
        }
    }
}

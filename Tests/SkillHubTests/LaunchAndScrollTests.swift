import AppKit
import XCTest
import SwiftUI
@testable import SkillHub

final class LaunchAndScrollTests: XCTestCase {
    @MainActor func testScrollPolicyCoalescesUpdatesPerWindow() {
        ScrollBehavior.flush()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let scroll = NSScrollView()
        scroll.scrollerStyle = .legacy
        window.contentView?.addSubview(scroll)
        let before = ScrollBehavior.passCount
        for _ in 0..<100 { ScrollBehavior.schedule(in: window) }
        XCTAssertEqual(ScrollBehavior.passCount, before, "Requests must not walk the tree synchronously")
        ScrollBehavior.flush()
        XCTAssertEqual(ScrollBehavior.passCount, before + 1)
        XCTAssertEqual(scroll.scrollerStyle, .overlay)
        ScrollBehavior.flush()
        XCTAssertEqual(ScrollBehavior.passCount, before + 1, "No work without a content update")
    }

    @MainActor func testContentUpdateConfiguresNativeScrollViews() async {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = NSHostingView(rootView: ScrollView {
            MarkdownDocument(text: "# Test\n\n```swift\nlet value = 1\n```", baseURL: URL(fileURLWithPath: "/tmp"))
        }.background(ScrollPolicyUpdate()))
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        await Task.yield()
        ScrollBehavior.flush()
        var scrolls: [NSScrollView] = []
        func collect(_ view: NSView) {
            if let scroll = view as? NSScrollView { scrolls.append(scroll) }
            for child in view.subviews { collect(child) }
        }
        collect(host)
        XCTAssertGreaterThanOrEqual(scrolls.count, 2)
        XCTAssertTrue(scrolls.allSatisfy { $0.scrollerStyle == .overlay && $0.autohidesScrollers })
    }

    @MainActor func testStoreDefersCollectionReadUntilRequested() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = CollectionStorage(file: root.appendingPathComponent("collection.json"))
        let store = HubStore(storage: storage)
        XCTAssertTrue(store.collectionLoading)
        XCTAssertTrue(store.collection.isEmpty)
        let skill = SavedSkill(name: "Written after store initialization")
        try storage.save([skill])
        await store.loadCollection()
        XCTAssertEqual(store.collection, [skill])
        XCTAssertFalse(store.collectionLoading)
        XCTAssertTrue(store.save(SavedSkill(name: "New")))
        await store.loadCollection()
        XCTAssertEqual(store.collection.count, 2, "Repeated load must not overwrite edits")
    }

    @MainActor func testAsyncLoadFailureDoesNotOverwriteCollection() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = CollectionStorage(file: root.appendingPathComponent("collection.json"))
        try "invalid".write(to: storage.file, atomically: true, encoding: .utf8)
        let store = HubStore(storage: storage)
        await store.loadCollection()
        XCTAssertNotNil(store.error)
        XCTAssertFalse(store.save(SavedSkill(name: "Do not overwrite")))
        XCTAssertEqual(try String(contentsOf: storage.file), "invalid")
    }

    @MainActor func testExplicitRefreshAdvancesGenerationForEqualShallowSkills() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let agents = root.appendingPathComponent("agents")
        let claude = root.appendingPathComponent("claude")
        try FileManager.default.createDirectory(at: agents.appendingPathComponent("skill/nested"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "---\nname: Stable\n---".write(to: agents.appendingPathComponent("skill/SKILL.md"), atomically: true, encoding: .utf8)
        let defaults = UserDefaults.standard
        let oldAgents = defaults.object(forKey: "agentsPath")
        let oldClaude = defaults.object(forKey: "claudePath")
        defer {
            if let oldAgents { defaults.set(oldAgents, forKey: "agentsPath") } else { defaults.removeObject(forKey: "agentsPath") }
            if let oldClaude { defaults.set(oldClaude, forKey: "claudePath") } else { defaults.removeObject(forKey: "claudePath") }
        }
        defaults.set(agents.path, forKey: "agentsPath")
        defaults.set(claude.path, forKey: "claudePath")
        let store = HubStore(storage: CollectionStorage(file: root.appendingPathComponent("collection.json")))
        await store.refresh()
        let first = store.agents
        let generation = store.refreshGeneration
        try "new child".write(to: agents.appendingPathComponent("skill/nested/new.txt"), atomically: true, encoding: .utf8)
        await store.refresh()
        XCTAssertEqual(first, store.agents, "Only an unloaded descendant changed")
        XCTAssertEqual(store.refreshGeneration, generation + 1)
    }

    func testParsedMarkdownIsReusedAndLargeMarkdownUsesSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("SKILL.md")
        try "---\nname: Test\n---\n# Title\nHello **world**".write(to: file, atomically: true, encoding: .utf8)
        let loader = DocumentLoader()
        let first = try await loader.loadPreview(file)
        let second = try await loader.loadPreview(file)
        XCTAssertEqual(first.id, second.id, "Reuse the parsed snapshot, not just its source text")
        XCTAssertNotNil(first.markdown)
        XCTAssertFalse(first.markdown?.renderPlainText().contains("name: Test") ?? true)
        try String(repeating: "Large document.\n", count: 10_000).write(to: file, atomically: true, encoding: .utf8)
        let large = try await loader.loadPreview(file)
        XCTAssertTrue(large.sourceOnly)
        XCTAssertNil(large.markdown)
        XCTAssertFalse(large.text.isEmpty)
        XCTAssertNotEqual(first.id, large.id)
    }
}

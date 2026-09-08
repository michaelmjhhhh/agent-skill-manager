import XCTest
@testable import SkillHub

final class PerformanceTests: XCTestCase {
    func testSharedSkillScanBenchmark() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let skill = root.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try "---\nname: Shared\n---\n# Test".write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        for i in 0..<200 {
            try Data().write(to: skill.appendingPathComponent("reference-\(i).md"))
        }
        for i in 0..<30 {
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link-\(i)"), withDestinationURL: skill)
        }
        let start = Date()
        let skills = try SkillScanner.scan(path: root.path)
        print("Shared skill scan seconds: \(Date().timeIntervalSince(start))")
        XCTAssertEqual(skills.count, 31)
        XCTAssertEqual(Set(skills.map(\.id)).count, 31)
        XCTAssertTrue(skills.allSatisfy { $0.files.count == 201 })
    }

    func testScanSessionPreservesSourceEntriesAndNewRefreshSeesChanges() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let agents = root.appendingPathComponent("agents")
        let claude = root.appendingPathComponent("claude")
        let skill = agents.appendingPathComponent("skill")
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        let document = skill.appendingPathComponent("SKILL.md")
        try "---\nname: Before\n---".write(to: document, atomically: true, encoding: .utf8)
        let link = claude.appendingPathComponent("skill")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: skill)
        let session = SkillScanner.Session()
        let a = try SkillScanner.scan(path: agents.path, session: session)
        let c = try SkillScanner.scan(path: claude.path, session: session)
        XCTAssertEqual(a.first?.folder.deletingLastPathComponent().lastPathComponent, "agents")
        XCTAssertEqual(c.first?.folder.deletingLastPathComponent().lastPathComponent, "claude")
        XCTAssertNotEqual(a.first?.id, c.first?.id)
        let entry = try XCTUnwrap(c.first?.folder)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: entry.path), skill.path)
        XCTAssertEqual(session.trees.count, 1)
        XCTAssertEqual(session.metadata.count, 1)
        try "---\nname: After\n---".write(to: document, atomically: true, encoding: .utf8)
        XCTAssertEqual(try SkillScanner.scan(path: agents.path).first?.name, "After")
    }

    func testLazyTreeLoadsIndependentDirectoriesAndReportsOmissions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["first", "second"] {
            let folder = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try "# \(name)".write(to: folder.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("a-nested"), withIntermediateDirectories: true)
            try "one".write(to: folder.appendingPathComponent("a-nested/one.txt"), atomically: true, encoding: .utf8)
        }
        let first = root.appendingPathComponent("first")
        for i in 0..<(SkillScanner.entriesPerDirectoryLimit - 1) {
            try Data().write(to: first.appendingPathComponent("entry-\(i).txt"))
        }
        let session = SkillScanner.Session()
        let start = Date()
        let skills = try SkillScanner.scan(path: root.path, session: session)
        let visitedEntries = skills.reduce(0) { $0 + $1.files.count + $1.omittedCount }
        print("Independent lazy-tree initial scan: \(visitedEntries) directory entries, seconds: \(Date().timeIntervalSince(start))")
        XCTAssertEqual(visitedEntries, 503)
        XCTAssertEqual(skills.count, 2)
        XCTAssertEqual(skills.first(where: { $0.folder.lastPathComponent == "first" })?.files.count, SkillScanner.entriesPerDirectoryLimit)
        let firstSkill = try XCTUnwrap(skills.first(where: { $0.folder.lastPathComponent == "first" }))
        XCTAssertEqual(firstSkill.omittedCount, 1)
        XCTAssertEqual(firstSkill.document?.lastPathComponent, "SKILL.md")
        XCTAssertEqual(firstSkill.name, "first")
        let firstNested = try XCTUnwrap(skills.first(where: { $0.folder.lastPathComponent == "first" })?.files.first(where: { $0.url.lastPathComponent == "a-nested" }))
        let secondNested = try XCTUnwrap(skills.first(where: { $0.folder.lastPathComponent == "second" })?.files.first(where: { $0.url.lastPathComponent == "a-nested" }))
        XCTAssertFalse(firstNested.childrenLoaded)
        let expansionStart = Date()
        XCTAssertEqual(SkillScanner.loadChildren(of: firstNested).nodes.first?.url.lastPathComponent, "one.txt")
        print("One child expansion seconds: \(Date().timeIntervalSince(expansionStart))")
        XCTAssertEqual(SkillScanner.loadChildren(of: secondNested).nodes.first?.url.lastPathComponent, "one.txt")
        XCTAssertFalse(secondNested.childrenLoaded, "Loading one independent directory must not mutate another")
    }

    func testBoundedMetadataHandlesLargeBodyMissingDelimiterAndUTF8() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let good = root.appendingPathComponent("good.md")
        try "---\nname: Café\ndescription: >-\n  Une ligne\n  multilingue\n---\n\(String(repeating: "body ", count: 500_000))".write(to: good, atomically: true, encoding: .utf8)
        let missing = root.appendingPathComponent("missing.md")
        try "---\nname: Never closed\n\(String(repeating: "x", count: SkillScanner.metadataReadLimit + 100))".write(to: missing, atomically: true, encoding: .utf8)
        let boundary = root.appendingPathComponent("boundary.md")
        let boundaryName = String(repeating: "a", count: 4_085) + "é"
        try Data("---\nname: \(boundaryName)\n---\nbody".utf8).write(to: boundary)
        let invalid = root.appendingPathComponent("invalid.md")
        var invalidData = Data("---\nname: ".utf8)
        invalidData.append(0xFF)
        invalidData.append(Data("\n---\nbody".utf8))
        try invalidData.write(to: invalid)
        let splitDelimiter = root.appendingPathComponent("split-delimiter.md")
        var splitData = Data("---\nname: Split\n".utf8)
        while splitData.count < 4_092 { splitData.append(0x78) }
        splitData.append(0x0A)
        splitData.append(Data("---x\nbody".utf8))
        try splitData.write(to: splitDelimiter)
        let eofDelimiter = root.appendingPathComponent("eof-delimiter.md")
        try Data("---\nname: End\n---".utf8).write(to: eofDelimiter)
        let start = Date()
        let skills = try SkillScanner.scan(path: root.path)
        print("64 KB-bounded metadata over 2.5 MB body: seconds: \(Date().timeIntervalSince(start))")
        let parsed = try XCTUnwrap(skills.first(where: { $0.folder.lastPathComponent == "good.md" }))
        XCTAssertEqual(parsed.name, "Café")
        XCTAssertEqual(parsed.summary, "Une ligne multilingue")
        XCTAssertEqual(skills.first(where: { $0.folder.lastPathComponent == "missing.md" })?.name, "missing")
        XCTAssertEqual(skills.first(where: { $0.folder.lastPathComponent == "boundary.md" })?.name, boundaryName)
        XCTAssertEqual(skills.first(where: { $0.folder.lastPathComponent == "invalid.md" })?.name, "invalid")
        XCTAssertEqual(skills.first(where: { $0.folder.lastPathComponent == "split-delimiter.md" })?.name, "split-delimiter")
        XCTAssertEqual(skills.first(where: { $0.folder.lastPathComponent == "eof-delimiter.md" })?.name, "End")
        let depth = SkillScanner.loadChildren(of: FileNode(url: root, isDirectory: true, depth: 12))
        XCTAssertTrue(depth.notice?.contains("Maximum directory depth") == true)
        let unreadable = SkillScanner.loadChildren(of: FileNode(url: root.appendingPathComponent("does-not-exist"), isDirectory: true))
        XCTAssertTrue(unreadable.notice?.contains("Unable to read directory") == true)
    }

    func testMetadataClosingDelimiterAtExactReadLimit() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var data = Data("---\nname: Exact\n".utf8)
        data.append(Data(repeating: 0x78, count: SkillScanner.metadataReadLimit - data.count - 4))
        data.append(Data("\n---".utf8))
        XCTAssertEqual(data.count, SkillScanner.metadataReadLimit)
        try data.write(to: root.appendingPathComponent("exact.md"))
        // The same prefix must not count as closed when more bytes follow.
        data.append(Data("x\n".utf8))
        try data.write(to: root.appendingPathComponent("over.md"))
        let skills = try SkillScanner.scan(path: root.path)
        XCTAssertEqual(skills.first(where: { $0.folder.lastPathComponent == "exact.md" })?.name, "Exact")
        XCTAssertEqual(skills.first(where: { $0.folder.lastPathComponent == "over.md" })?.name, "over")
    }

    func testPreviewSymlinksAndOversizedFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("original.md")
        let link = root.appendingPathComponent("linked.md")
        try "你好".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        let loader = DocumentLoader()
        let text = try await loader.load(link)
        XCTAssertEqual(text, "你好")
        try Data(repeating: 65, count: 2_000_001).write(to: file)
        do { _ = try await loader.load(link); XCTFail("Oversized file must be rejected") }
        catch { }
    }

    func testTenThousandImportUsesIDSetAndConsecutiveWritesKeepAllItems() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = CollectionStorage(file: root.appendingPathComponent("collection.json"))
        let store = await MainActor.run { HubStore(storage: storage) }
        await store.loadCollection()
        let existing = SavedSkill(name: "existing")
        let firstSave = await store.save(existing)
        XCTAssertTrue(firstSave)
        let imported = (0..<10_000).map { SavedSkill(name: "item-\($0)") } + [existing]
        let start = Date()
        let merged = await store.mergeImported(imported)
        XCTAssertTrue(merged)
        await store.loadCollection()
        print("10,000 item import merge seconds: \(Date().timeIntervalSince(start))")
        let importedCount = await store.collection.count
        XCTAssertEqual(importedCount, 10_001)
        let edits = (0..<8).map { SavedSkill(name: "edit-\($0)") }
        for edit in edits {
            let accepted = await store.save(edit)
            XCTAssertTrue(accepted)
        }
        await store.loadCollection()
        let finalCount = await store.collection.count
        XCTAssertEqual(finalCount, 10_009)
    }

    func testRepeatedCollectionResultComputations() {
        let source = (0..<10_000).map { SavedSkill(name: "item-\($0)", summary: "searchable") }
        let repetitions = 20
        let start = Date()
        var resultCount = 0
        for _ in 0..<repetitions {
            resultCount += CollectionView.displayedItems(from: source, category: "All categories", sort: "Name", favoritesOnly: false, search: "searchable").count
        }
        let elapsed = Date().timeIntervalSince(start)
        print("Repeated collection results: \(repetitions) passes, \(source.count * repetitions) filter visits, seconds: \(elapsed)")
        XCTAssertEqual(resultCount, source.count * repetitions)
    }

    func testDocumentCacheInvalidationAndBudget() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let loader = DocumentLoader(budget: 10)
        let file = root.appendingPathComponent("test.md")
        try "first".write(to: file, atomically: true, encoding: .utf8)
        let first = try await loader.load(file)
        let cached = try await loader.load(file)
        XCTAssertEqual(first, cached)
        try "replacement".write(to: file, atomically: true, encoding: .utf8)
        let updated = try await loader.load(file)
        XCTAssertEqual(updated, "replacement")
        for i in 0..<5 {
            let next = root.appendingPathComponent("\(i).md")
            try "12345".write(to: next, atomically: true, encoding: .utf8)
            _ = try await loader.load(next)
        }
        let bytes = await loader.cachedBytes
        XCTAssertLessThanOrEqual(bytes, 10)
        try FileManager.default.removeItem(at: file)
        do { _ = try await loader.load(file); XCTFail("Deleted file must not use stale cache") }
        catch { }
    }
}

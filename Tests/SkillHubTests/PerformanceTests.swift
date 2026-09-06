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

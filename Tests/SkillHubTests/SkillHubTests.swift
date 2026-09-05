import XCTest
@testable import SkillHub

final class SkillHubTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func put(_ path: String, _ text: String) throws {
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }
    func testMetadataAndNestedBundle() throws {
        try put("design/SKILL.md", "---\nname: 'Design helper'\ndescription: >-\n  Make beautiful things\n  with intention.\n---\n# Instructions")
        try put("design/subskills/review/SKILL.md", "# Review")
        try put("single.md", "# A single-file skill")
        try put(".hidden/SKILL.md", "# Hidden")
        let skills = try SkillScanner.scan(path: root.path)
        XCTAssertEqual(skills.count, 2)
        XCTAssertEqual(skills[0].name, "Design helper")
        XCTAssertEqual(skills[0].summary, "Make beautiful things with intention.")
        XCTAssertNotNil(skills[0].files.first { $0.url.lastPathComponent == "subskills" }?.children)
        XCTAssertEqual(skills[1].document?.lastPathComponent, "single.md")
    }
    func testSymlinksAndCycles() throws {
        try put("original/SKILL.md", "# Main")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked"), withDestinationURL: root.appendingPathComponent("original"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("original/loop"), withDestinationURL: root.appendingPathComponent("original"))
        let skills = try SkillScanner.scan(path: root.path)
        XCTAssertEqual(skills.count, 2)
        XCTAssertNotNil(skills.first { $0.name == "linked" }?.document)
        XCTAssertEqual(skills[0].files.first { $0.url.lastPathComponent == "loop" }?.children?.count, 0)
    }
    func testCollectionRoundTripAndInvalidData() throws {
        let storage = CollectionStorage(file: root.appendingPathComponent("data/collection.json"))
        XCTAssertEqual(try storage.load(), [])
        let item = SavedSkill(name: "Test", url: "https://example.com", command: "echo 'hello'", summary: "Example", category: "Writing", favorite: true)
        try storage.save([item])
        XCTAssertEqual(try storage.load(), [item])
        try "broken JSON".write(to: storage.file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try storage.load())
        XCTAssertEqual(try String(contentsOf: storage.file), "broken JSON")
    }
    func testMissingRootIsReported() {
        XCTAssertThrowsError(try SkillScanner.scan(path: root.appendingPathComponent("missing").path))
    }
    func testBundleWithoutRootDocument() throws {
        try put("bundle/child/SKILL.md", "# Child")
        let skills = try SkillScanner.scan(path: root.path)
        XCTAssertEqual(skills.count, 1)
        XCTAssertNil(skills[0].document)
        XCTAssertEqual(skills[0].files.first?.children?.first?.url.lastPathComponent, "SKILL.md")
    }
}

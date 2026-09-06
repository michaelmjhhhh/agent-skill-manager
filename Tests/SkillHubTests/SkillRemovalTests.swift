import XCTest
@testable import SkillHub

final class SkillRemovalTests: XCTestCase {
    private var sandbox: URL!
    private var root: URL!
    override func setUpWithError() throws {
        sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        root = sandbox.appendingPathComponent("skills")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: sandbox)
    }
    private func directory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func testWholeDirectoryNotSelectedDocument() throws {
        let skill = try directory("drawio")
        let document = skill.appendingPathComponent("SKILL.md")
        try Data("test".utf8).write(to: document)
        let request = try SkillRemoval.prepare(target: skill, rootPath: root.path)
        XCTAssertEqual(request.target.path, skill.path)
        XCTAssertTrue(request.isDirectory)
        try request.validate(rootPath: root.path)
        XCTAssertThrowsError(try SkillRemoval.prepare(target: document, rootPath: root.path))
    }
    func testRootAncestorAndOutsideAreRejected() throws {
        for url in [root!, sandbox!, sandbox.appendingPathComponent("skills-other"), URL(fileURLWithPath: "/")] {
            XCTAssertThrowsError(try SkillRemoval.prepare(target: url, rootPath: root.path))
        }
        XCTAssertThrowsError(try SkillRemoval.prepare(target: URL(string: "https://example.com/skill")!, rootPath: root.path))
    }
    func testExternalAndBrokenSymlinksAreNotResolved() throws {
        let external = sandbox.appendingPathComponent("external")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        for name in ["link", "broken"] {
            let link = root.appendingPathComponent(name)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: name == "link" ? external : sandbox.appendingPathComponent("missing"))
            let request = try SkillRemoval.prepare(target: link, rootPath: root.path)
            XCTAssertTrue(request.isLink)
            XCTAssertEqual(request.target, link)
            XCTAssertNotEqual(request.target, external)
            try request.validate(rootPath: root.path)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: external.path))
    }
    func testStandaloneMarkdownAndUnrelatedFile() throws {
        let md = root.appendingPathComponent("notes.md")
        try Data().write(to: md)
        XCTAssertFalse(try SkillRemoval.prepare(target: md, rootPath: root.path).isDirectory)
        let text = root.appendingPathComponent("notes.txt")
        try Data().write(to: text)
        XCTAssertThrowsError(try SkillRemoval.prepare(target: text, rootPath: root.path))
    }
    func testChangedSettingsAndReplacedEntryAreRejected() throws {
        let skill = try directory("drawio")
        let request = try SkillRemoval.prepare(target: skill, rootPath: root.path)
        XCTAssertThrowsError(try request.validate(rootPath: sandbox.path))
        try FileManager.default.moveItem(at: skill, to: sandbox.appendingPathComponent("old"))
        _ = try directory("drawio")
        XCTAssertThrowsError(try request.validate(rootPath: root.path))
    }
    func testSymlinkedRootIsPinned() throws {
        let skill = try directory("drawio")
        let alias = sandbox.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        let request = try SkillRemoval.prepare(target: alias.appendingPathComponent("drawio"), rootPath: alias.path)
        XCTAssertEqual(request.target.path, skill.path)
        try request.validate(rootPath: alias.path)
        try FileManager.default.removeItem(at: alias)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: sandbox)
        XCTAssertThrowsError(try request.validate(rootPath: alias.path))
    }
    func testTrashMovesOnlyFixtureLinkAndPreservesTarget() throws {
        let external = sandbox.appendingPathComponent("external")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let marker = external.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: marker)
        let link = root.appendingPathComponent(UUID().uuidString, isDirectory: false)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)
        let request = try SkillRemoval.prepare(target: link, rootPath: root.path)
        let trashed = try XCTUnwrap(request.moveToTrash(rootPath: root.path))
        // Clean up only the unique fixture entry returned by the Trash operation.
        defer { try? FileManager.default.removeItem(at: trashed) }
        XCTAssertEqual(try String(contentsOf: marker), "keep")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: trashed.path), external.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: link.path))
    }
    func testTrashMovesWholeFixtureDirectory() throws {
        let skill = try directory(UUID().uuidString)
        try Data("fixture".utf8).write(to: skill.appendingPathComponent("SKILL.md"))
        let request = try SkillRemoval.prepare(target: skill, rootPath: root.path)
        let trashed = try XCTUnwrap(request.moveToTrash(rootPath: root.path))
        defer { try? FileManager.default.removeItem(at: trashed) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: skill.path))
        XCTAssertEqual(try String(contentsOf: trashed.appendingPathComponent("SKILL.md")), "fixture")
    }
    func testUnsafeSourceRootsAreRejected() throws {
        XCTAssertThrowsError(try SkillRemoval.prepare(target: URL(fileURLWithPath: "/tmp"), rootPath: "/"))
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertThrowsError(try SkillRemoval.prepare(target: home.appendingPathComponent("Documents"), rootPath: home.path))
    }
}

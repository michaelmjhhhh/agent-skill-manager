import Foundation
import XCTest
@testable import SkillHub

/// Repeatable non-UI measurements for issue #6. This intentionally reports
/// filesystem/JSON work and operation counts separately from UI timing.
final class Issue6BenchmarkTests: XCTestCase {
    func testIssue6ReleaseBenchmarkFixtures() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let deepRoot = root.appendingPathComponent("deep")
        try makeDeepFixture(at: deepRoot)
        let scanTimes = try median(repetitions: 7) { _ in
            _ = try SkillScanner.scan(path: deepRoot.path)
        }
        let scanned = try SkillScanner.scan(path: deepRoot.path)
        let loadedNodes = scanned.reduce(0) { $0 + countLoadedNodes($1.files) }
        print("issue6 deep scan: median_seconds=\(scanTimes), top_level_or_loaded_nodes=\(loadedNodes), skill_count=\(scanned.count)")
        XCTAssertEqual(scanned.count, 8)

        let metadataRoot = root.appendingPathComponent("metadata")
        try FileManager.default.createDirectory(at: metadataRoot, withIntermediateDirectories: true)
        let body = String(repeating: "body ", count: 500_000)
        try ("---\nname: Large\n---\n" + body).write(to: metadataRoot.appendingPathComponent("large.md"), atomically: true, encoding: .utf8)
        let metadataTimes = try median(repetitions: 7) { _ in
            _ = try SkillScanner.scan(path: metadataRoot.path)
        }
        print("issue6 2.5MB metadata scan: median_seconds=\(metadataTimes), source_bytes=\(body.utf8.count)")

        let collectionRoot = root.appendingPathComponent("collection")
        let storage = CollectionStorage(file: collectionRoot.appendingPathComponent("collection.json"))
        let entries = (0..<10_000).map { SavedSkill(name: "item-\($0)") }
        try storage.save(entries)
        let importTimes = try median(repetitions: 7) { _ in
            _ = try storage.load()
        }
        let loaded = try storage.load()
        print("issue6 10k full JSON import: median_seconds=\(importTimes), decoded_records=\(loaded.count), json_bytes=\(try Data(contentsOf: storage.file).count)")
        XCTAssertEqual(loaded.count, 10_000)

        let oldComparisonCount = (0..<10_000).reduce(0) { $0 + $1 }
        let setLookupCount = 10_000
        print("issue6 10k merge operation counts: old_linear_comparisons=\(oldComparisonCount), set_lookups=\(setLookupCount)")
    }

    private func makeDeepFixture(at root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for skillIndex in 0..<8 {
            let skill = root.appendingPathComponent("skill-\(skillIndex)")
            try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
            try "---\nname: Deep \(skillIndex)\n---\n".write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            var current = skill
            for depth in 0..<8 {
                for branch in 0..<3 {
                    let child = current.appendingPathComponent("level-\(depth)-\(branch)")
                    try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
                    for file in 0..<4 {
                        try Data().write(to: child.appendingPathComponent("file-\(file).txt"))
                    }
                }
                current = current.appendingPathComponent("level-\(depth)-0")
            }
        }
    }

    private func countLoadedNodes(_ nodes: [FileNode]) -> Int {
        nodes.reduce(0) { total, node in
            total + 1 + (node.children.map { countLoadedNodes($0) } ?? 0)
        }
    }

    private func median(repetitions: Int, _ operation: (Int) throws -> Void) rethrows -> TimeInterval {
        var times: [TimeInterval] = []
        for repetition in 0..<repetitions {
            let start = Date()
            try operation(repetition)
            times.append(Date().timeIntervalSince(start))
        }
        return times.sorted()[times.count / 2]
    }
}

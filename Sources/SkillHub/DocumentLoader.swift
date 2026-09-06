import Foundation

/// Bounded, off-main-thread text cache. File attributes are checked on every visit.
actor DocumentLoader {
    static let shared = DocumentLoader()
    private let budget: Int
    private var entries: [String: Entry] = [:]
    private var order: [String] = []
    private var bytes = 0
    private struct Entry {
        let modified: Date?
        let changed: Date?
        let inode: UInt64?
        let size: Int
        let text: String
    }

    init(budget: Int = 8_000_000) { self.budget = budget }

    func load(_ url: URL) throws -> String {
        try Task.checkCancellation()
        let file = url.resolvingSymlinksInPath()
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? Int.max
        guard attributes[.type] as? FileAttributeType == .typeRegular, size <= 2_000_000 else {
            throw NSError(domain: "Preview", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Only regular text files up to 2 MB can be previewed. Open this item in Finder."])
        }
        let modified = attributes[.modificationDate] as? Date
        let created = attributes[.creationDate] as? Date
        let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        let key = url.path
        if let entry = entries[key], entry.modified == modified, entry.changed == created,
           entry.inode == inode, entry.size == size {
            touch(key)
            return entry.text
        }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 2_000_001) ?? Data()
        guard data.count <= 2_000_000, let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Preview", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "This file is too large or is not UTF-8 text. Open it in Finder."])
        }
        try Task.checkCancellation()
        if let old = entries.removeValue(forKey: key) { bytes -= old.size }
        order.removeAll { $0 == key }
        if data.count <= budget {
            while bytes + data.count > budget || entries.count >= 32, let oldest = order.first {
                order.removeFirst()
                if let old = entries.removeValue(forKey: oldest) { bytes -= old.size }
            }
            entries[key] = Entry(modified: modified, changed: created, inode: inode, size: data.count, text: text)
            bytes += data.count
            touch(key)
        }
        return text
    }

    var cachedBytes: Int { bytes }
    private func touch(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}

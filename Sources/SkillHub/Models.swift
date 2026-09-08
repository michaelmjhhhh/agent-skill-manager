import Foundation

struct FileNode: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    var children: [FileNode]?
    let isDirectory: Bool
    var omittedCount: Int
    var childrenLoaded: Bool
    var notice: String?
    fileprivate let ancestors: Set<String>
    fileprivate let depth: Int

    init(url: URL, children: [FileNode]? = nil, isDirectory: Bool? = nil,
         omittedCount: Int = 0, childrenLoaded: Bool? = nil, notice: String? = nil,
         ancestors: Set<String> = [], depth: Int = 0) {
        self.url = url
        self.children = children
        self.isDirectory = isDirectory ?? (children != nil)
        self.omittedCount = omittedCount
        self.childrenLoaded = childrenLoaded ?? (children != nil)
        self.notice = notice
        self.ancestors = ancestors
        self.depth = depth
    }
}

struct InstalledSkill: Identifiable, Equatable {
    var id: String { folder.path }
    let folder: URL
    let document: URL?
    let name: String
    let summary: String
    let files: [FileNode]
    let omittedCount: Int
    let notice: String?

    init(folder: URL, document: URL?, name: String, summary: String, files: [FileNode],
         omittedCount: Int = 0, notice: String? = nil) {
        self.folder = folder
        self.document = document
        self.name = name
        self.summary = summary
        self.files = files
        self.omittedCount = omittedCount
        self.notice = notice
    }
}

struct SavedSkill: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var url = ""
    var command = ""
    var summary = ""
    var category = ""
    var favorite = false
    var createdAt = Date()
}

struct SkillScanner {
    /// The metadata probe is deliberately small. It stops at the frontmatter
    /// terminator and never reads the Markdown body.
    static let metadataReadLimit = 64 * 1024
    static let entriesPerDirectoryLimit = 500

    static func metadata(_ text: String) -> (name: String, summary: String) {
        let lines = text.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---",
              let end = lines.dropFirst().firstIndex(of: "---") else { return ("", "") }
        var fields: [String: String] = [:]
        var current = ""
        for line in lines[1..<end] {
            if line.first?.isWhitespace == true, !current.isEmpty {
                fields[current, default: ""] += " " + line.trimmingCharacters(in: .whitespaces)
            } else if let colon = line.firstIndex(of: ":") {
                current = String(line[..<colon])
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                fields[current] = [">", ">-", "|", "|-"].contains(value) ? "" : value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return (fields["name", default: ""], fields["description", default: ""].trimmingCharacters(in: .whitespaces))
    }

    /// Cache only within one refresh, so explicit refresh always sees filesystem changes.
    final class Session {
        var trees: [String: [FileNode]] = [:]
        var treeOmissions: [String: Int] = [:]
        var treeNotices: [String: String] = [:]
        var metadata: [String: (name: String, summary: String)] = [:]
    }

    private struct DirectoryListing {
        let nodes: [FileNode]
        let omitted: Int
        let notice: String?
    }

    static func scan(path: String, session: Session = Session()) throws -> [InstalledSkill] {
        let root = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return try FileManager.default.contentsOfDirectory(at: root.resolvingSymlinksInPath(), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]).compactMap { url in
            let isDirectory = (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            guard isDirectory || url.pathExtension.lowercased() == "md" else { return nil }
            let canonical = url.resolvingSymlinksInPath().path
            let files: [FileNode]
            let omitted: Int
            let notice: String?
            if isDirectory {
                if let cached = session.trees[canonical] {
                    files = cached
                    omitted = session.treeOmissions[canonical, default: 0]
                    notice = session.treeNotices[canonical]
                } else {
                    let listing = treeListing(url, ancestors: [], depth: 0)
                    files = listing.nodes
                    omitted = listing.omitted
                    notice = listing.notice
                    session.trees[canonical] = files
                    session.treeOmissions[canonical] = omitted
                    if let notice { session.treeNotices[canonical] = notice }
                }
            } else {
                files = []
                omitted = 0
                notice = nil
            }
            let main = isDirectory ? files.first(where: { $0.url.lastPathComponent.lowercased() == "skill.md" })?.url : url
            let fallback = files.first(where: { $0.url.lastPathComponent.lowercased() == "readme.md" })?.url
            let document = main ?? fallback
            let metadataKey = document?.resolvingSymlinksInPath().path ?? canonical
            let meta: (name: String, summary: String)
            if let cached = session.metadata[metadataKey] { meta = cached }
            else {
                meta = boundedMetadata(document)
                session.metadata[metadataKey] = meta
            }
            return InstalledSkill(folder: url, document: document,
                                  name: meta.name.isEmpty ? (isDirectory ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent) : meta.name,
                                  summary: meta.summary, files: files, omittedCount: omitted, notice: notice)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Returns only one directory level. Child directories are represented as
    /// unloaded nodes and are populated by `loadChildren` when expanded.
    static func tree(_ folder: URL, ancestors: Set<String>, depth: Int) -> [FileNode] {
        treeListing(folder, ancestors: ancestors, depth: depth).nodes
    }

    static func loadChildren(of node: FileNode) -> (nodes: [FileNode], omitted: Int, notice: String?) {
        guard node.isDirectory else { return ([], 0, nil) }
        let listing = treeListing(node.url, ancestors: node.ancestors, depth: node.depth)
        return (listing.nodes, listing.omitted, listing.notice)
    }

    private static func treeListing(_ folder: URL, ancestors: Set<String>, depth: Int) -> DirectoryListing {
        let canonical = folder.resolvingSymlinksInPath().path
        if ancestors.contains(canonical) {
            return DirectoryListing(nodes: [], omitted: 0,
                                    notice: "Cycle detected; contents omitted.")
        }
        guard depth < 12 else {
            return DirectoryListing(nodes: [], omitted: 0,
                                    notice: "Maximum directory depth reached; contents omitted.")
        }
        var visitedAncestors = ancestors
        visitedAncestors.insert(canonical)
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(at: folder.resolvingSymlinksInPath(), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        } catch {
            return DirectoryListing(nodes: [], omitted: 0,
                                    notice: "Unable to read directory: \(error.localizedDescription)")
        }
        let filtered = urls.filter { !["node_modules", "__pycache__", ".git"].contains($0.lastPathComponent) }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        let primaryNames = Set(["skill.md", "readme.md"])
        let primary = filtered.filter { primaryNames.contains($0.lastPathComponent.lowercased()) }
        let nonPrimary = filtered.filter { !primaryNames.contains($0.lastPathComponent.lowercased()) }
        let selected = (primary + nonPrimary.prefix(max(0, entriesPerDirectoryLimit - primary.count))).sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        let omitted = max(0, filtered.count - selected.count)
        let nodes = selected.map { url in
            let directory = (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            return FileNode(url: url, isDirectory: directory, omittedCount: 0, childrenLoaded: false,
                            notice: nil, ancestors: visitedAncestors, depth: depth + 1)
        }
        return DirectoryListing(nodes: nodes, omitted: omitted, notice: nil)
    }

    private static func boundedMetadata(_ document: URL?) -> (name: String, summary: String) {
        guard let document,
              let handle = try? FileHandle(forReadingFrom: document.resolvingSymlinksInPath()) else { return ("", "") }
        defer { try? handle.close() }
        var data = Data()
        var reachedEOF = false
        // Read in small blocks so a closing delimiter near the beginning does
        // not cause the whole Markdown body to be read. Decode only the
        // frontmatter bytes; malformed UTF-8 in the body is irrelevant.
        while data.count < metadataReadLimit {
            let amount = min(4096, metadataReadLimit - data.count)
            do {
                guard let chunk = try handle.read(upToCount: amount), !chunk.isEmpty else {
                    reachedEOF = true
                    break
                }
                data.append(chunk)
            } catch {
                return ("", "")
            }
            if let end = frontmatterEnd(in: data, atEOF: false) {
                let frontmatter = Data(data.prefix(end))
                guard let text = String(data: frontmatter, encoding: .utf8) else { return ("", "") }
                return metadata(text)
            }
        }
        if !reachedEOF, data.count == metadataReadLimit {
            // Confirm EOF at the limit without reading beyond the byte budget.
            reachedEOF = (try? handle.seekToEnd()) == UInt64(data.count)
        }
        guard reachedEOF, let end = frontmatterEnd(in: data, atEOF: true) else { return ("", "") }
        let frontmatter = Data(data.prefix(end))
        guard let text = String(data: frontmatter, encoding: .utf8) else { return ("", "") }
        return metadata(text)
    }

    private static func frontmatterEnd(in data: Data, atEOF: Bool) -> Int? {
        let bytes = Array(data)
        let delimiter = Array("---".utf8)
        var lineStart = 0
        var firstLine = true
        for index in bytes.indices where bytes[index] == 0x0A {
            var lineEnd = index
            if lineEnd > lineStart && bytes[lineEnd - 1] == 0x0D { lineEnd -= 1 }
            let line = bytes[lineStart..<lineEnd]
            if firstLine {
                let leading = line.drop(while: { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D })
                let trimmed = leading.reversed().drop(while: { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D }).reversed()
                guard Array(trimmed) == delimiter else { return nil }
                firstLine = false
            } else if Array(line) == delimiter {
                return index + 1
            }
            lineStart = index + 1
        }
        if atEOF && !firstLine {
            let line = bytes[lineStart..<bytes.count]
            if Array(line) == delimiter { return bytes.count }
        }
        return nil
    }
}

struct CollectionStorage {
    let file: URL
    static var standard: CollectionStorage {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return CollectionStorage(file: root.appendingPathComponent("SkillHub/collection.json"))
    }
    func load() throws -> [SavedSkill] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([SavedSkill].self, from: Data(contentsOf: file))
    }
    func save(_ items: [SavedSkill]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(items).write(to: file, options: .atomic)
    }
}

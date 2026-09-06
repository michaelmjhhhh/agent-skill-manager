import Foundation

struct FileNode: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let children: [FileNode]?
}

struct InstalledSkill: Identifiable, Equatable {
    var id: String { folder.path }
    let folder: URL
    let document: URL?
    let name: String
    let summary: String
    let files: [FileNode]
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
        var metadata: [String: (name: String, summary: String)] = [:]
    }

    static func scan(path: String, session: Session = Session()) throws -> [InstalledSkill] {
        let root = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return try FileManager.default.contentsOfDirectory(at: root.resolvingSymlinksInPath(), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]).compactMap { url in
            let isDirectory = (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            guard isDirectory || url.pathExtension.lowercased() == "md" else { return nil }
            let canonical = url.resolvingSymlinksInPath().path
            let files: [FileNode]
            if isDirectory {
                if let cached = session.trees[canonical] { files = cached }
                else {
                    files = tree(url, ancestors: [], depth: 0)
                    session.trees[canonical] = files
                }
            } else { files = [] }
            let main = isDirectory ? files.first(where: { $0.url.lastPathComponent.lowercased() == "skill.md" })?.url : url
            let fallback = files.first(where: { $0.url.lastPathComponent.lowercased() == "readme.md" })?.url
            let document = main ?? fallback
            let metadataKey = document?.resolvingSymlinksInPath().path ?? canonical
            let meta: (name: String, summary: String)
            if let cached = session.metadata[metadataKey] { meta = cached }
            else {
                meta = metadata(document.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
                session.metadata[metadataKey] = meta
            }
            return InstalledSkill(folder: url, document: document, name: meta.name.isEmpty ? (isDirectory ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent) : meta.name, summary: meta.summary, files: files)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func tree(_ folder: URL, ancestors: Set<String>, depth: Int) -> [FileNode] {
        let canonical = folder.resolvingSymlinksInPath().path
        guard depth < 12, !ancestors.contains(canonical) else { return [] }
        var visited = ancestors
        visited.insert(canonical)
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder.resolvingSymlinksInPath(), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return urls.filter { !["node_modules", "__pycache__", ".git"].contains($0.lastPathComponent) }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }.prefix(500).map { url in
            let directory = (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            return FileNode(url: url, children: directory ? tree(url, ancestors: visited, depth: depth + 1) : nil)
        }
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

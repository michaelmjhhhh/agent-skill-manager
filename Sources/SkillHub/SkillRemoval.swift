import Foundation
import Darwin

/// A confirmation applies to one filesystem entry, never the currently open document.
struct SkillRemoval: Identifiable {
    let id = UUID()
    let target: URL
    let root: URL
    let isLink: Bool
    let isDirectory: Bool
    private let configuredRoot: URL
    private let rootIdentity: Identity
    private let targetIdentity: Identity

    private struct Identity: Equatable {
        let device: dev_t
        let inode: ino_t
        let kind: mode_t
    }

    private static func inspect(_ url: URL) throws -> Identity {
        var info = stat()
        guard url.path.withCString({ lstat($0, &info) }) == 0 else {
            throw failure("The skill or its source folder is no longer available. Refresh and try again.")
        }
        return Identity(device: info.st_dev, inode: info.st_ino, kind: info.st_mode & S_IFMT)
    }

    static func prepare(target: URL, rootPath: String) throws -> Self {
        let configured = URL(fileURLWithPath: (rootPath as NSString).expandingTildeInPath).standardizedFileURL
        let candidate = target.standardizedFileURL
        guard target.isFileURL, candidate.deletingLastPathComponent().path == configured.path else {
            throw failure("Only a top-level skill in the configured source folder can be removed.")
        }
        let root = configured.resolvingSymlinksInPath()
        // A mistaken source setting must not expose home or filesystem-root entries.
        guard root.path != "/", root.path != FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path else {
            throw failure("Choose a dedicated skills folder in Settings before removing skills.")
        }
        let rootIdentity = try inspect(root)
        guard rootIdentity.kind == S_IFDIR else { throw failure("The source is not a directory.") }
        // Resolve the parent only. Resolving the entry would follow a skill symlink.
        let entry = root.appendingPathComponent(candidate.lastPathComponent, isDirectory: false)
        let identity = try inspect(entry)
        guard [mode_t(S_IFDIR), mode_t(S_IFREG), mode_t(S_IFLNK)].contains(identity.kind),
              identity.kind != S_IFREG || entry.pathExtension.lowercased() == "md" else {
            throw failure("This entry is not a skill directory, Markdown file, or symbolic link.")
        }
        return Self(target: entry, root: root, isLink: identity.kind == S_IFLNK,
                    isDirectory: identity.kind == S_IFDIR, configuredRoot: configured,
                    rootIdentity: rootIdentity, targetIdentity: identity)
    }

    func validate(rootPath: String) throws {
        let current = URL(fileURLWithPath: (rootPath as NSString).expandingTildeInPath).standardizedFileURL
        guard current.path == configuredRoot.path, current.resolvingSymlinksInPath().path == root.path,
              try Self.inspect(root) == rootIdentity,
              try Self.inspect(target) == targetIdentity else {
            throw Self.failure("The skill or source folder changed since confirmation. Refresh and try again.")
        }
    }

    @discardableResult func moveToTrash(rootPath: String) throws -> URL? {
        try validate(rootPath: rootPath)
        // No shell, recursive remove, target symlink resolution, or permanent-delete fallback.
        // FileManager's path-based Trash API cannot eliminate a concurrent filesystem race.
        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: target, resultingItemURL: &trashedURL)
        return trashedURL as URL?
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "SkillHub.Removal", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

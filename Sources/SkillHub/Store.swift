import SwiftUI
import AppKit

@MainActor final class HubStore: ObservableObject {
    @Published var agents: [InstalledSkill] = []
    @Published var claude: [InstalledSkill] = []
    @Published var collection: [SavedSkill] = []
    @Published var scanMessages: [String: String] = [:]
    @Published var error: String?
    @Published var scanning = false
    @Published private(set) var collectionLoading = true
    @Published private(set) var refreshGeneration = 0
    private var collectionLoaded = false
    private var collectionLoadTask: Task<[SavedSkill], Error>?
    private var collectionWriteTask: Task<Bool, Never>?
    private var pendingCollection: [SavedSkill]?
    private var mutationGeneration = 0
    private var lastRefresh: Date?
    private var lastPaths: [String] = []
    let storage: CollectionStorage

    init(storage: CollectionStorage = .standard) { self.storage = storage }

    func loadCollection() async {
        // A caller may use loadCollection as a convenient synchronization point
        // after an edit. Waiting here also prevents a stale disk snapshot from
        // replacing an edit whose write is still in flight.
        _ = await collectionWriteTask?.value
        guard !collectionLoaded else { return }
        let task: Task<[SavedSkill], Error>
        if let existing = collectionLoadTask { task = existing }
        else {
            let storage = self.storage
            task = Task.detached(priority: .userInitiated) { try storage.load() }
            collectionLoadTask = task
        }
        do {
            let items = try await task.value
            if !collectionLoaded {
                collection = items
                collectionLoaded = true
            }
        } catch {
            self.error = "Could not load collection. Your file has not been changed.\n\(error.localizedDescription)"
        }
        collectionLoadTask = nil
        collectionLoading = false
    }

    func refresh(automatic: Bool = false) async {
        guard !scanning else { return }
        let a = UserDefaults.standard.string(forKey: "agentsPath") ?? "~/.agents/skills"
        let c = UserDefaults.standard.string(forKey: "claudePath") ?? "~/.claude/skills"
        if automatic, lastPaths == [a, c], let lastRefresh, Date().timeIntervalSince(lastRefresh) < 3 { return }
        scanning = true
        let result = await Task.detached(priority: .userInitiated) {
            let session = SkillScanner.Session()
            return (Result { try SkillScanner.scan(path: a, session: session) },
                    Result { try SkillScanner.scan(path: c, session: session) })
        }.value
        var messages: [String: String] = [:]
        switch result.0 {
        case .success(let items): if agents != items { agents = items }
        case .failure(let error): if !agents.isEmpty { agents = [] }; messages["agents"] = "\(a): \(error.localizedDescription)"
        }
        switch result.1 {
        case .success(let items): if claude != items { claude = items }
        case .failure(let error): if !claude.isEmpty { claude = [] }; messages["claude"] = "\(c): \(error.localizedDescription)"
        }
        if scanMessages != messages { scanMessages = messages }
        // Increment even when shallow InstalledSkill values compare equal: a
        // loaded descendant may have changed and must be discarded by the tree.
        refreshGeneration &+= 1
        lastPaths = [a, c]
        lastRefresh = Date()
        scanning = false
    }

    func save(_ skill: SavedSkill) async -> Bool {
        var next = pendingCollection ?? collection
        if let index = next.firstIndex(where: { $0.id == skill.id }) { next[index] = skill }
        else { next.append(skill) }
        return await persist(next)
    }

    func delete(_ skill: SavedSkill) async -> Bool {
        await persist((pendingCollection ?? collection).filter { $0.id != skill.id })
    }

    /// Merge imported records without repeatedly scanning the growing array.
    /// Existing records win when an imported ID collides.
    func mergeImported(_ imported: [SavedSkill]) async -> Bool {
        var next = pendingCollection ?? collection
        var ids = Set(next.map(\.id))
        for item in imported where ids.insert(item.id).inserted { next.append(item) }
        return await persist(next)
    }

    private func persist(_ items: [SavedSkill]) async -> Bool {
        guard collectionLoaded else {
            error = collectionLoading ? "The collection is still loading. Try again shortly."
                : "Collection is unavailable. Repair or restore \(storage.file.path), then reopen the app."
            return false
        }
        pendingCollection = items
        mutationGeneration += 1
        let generation = mutationGeneration
        let previous = collectionWriteTask
        let storage = self.storage
        let task = Task { [weak self] in
            // The queue is intentionally serialized: every snapshot includes
            // all preceding edits, so an older write cannot overwrite a newer one.
            _ = await previous?.value
            do {
                try await Task.detached(priority: .utility) { try storage.save(items) }.value
                guard let self else { return false }
                // Every successful queued snapshot is a committed UI state.
                // A later failed snapshot must not roll this state back.
                self.collection = items
                if self.mutationGeneration == generation {
                    self.pendingCollection = nil
                }
                return true
            } catch {
                guard let self else { return false }
                self.error = "Could not save collection: \(error.localizedDescription)"
                if self.mutationGeneration == generation { self.pendingCollection = nil }
                return false
            }
        }
        collectionWriteTask = task
        return await task.value
    }

    func exportCollection() {
        guard collectionLoaded else { error = "Load the collection before exporting it."; return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "skill-collection.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard CollectionStorage.canExport(to: url, withoutOverwriting: storage) else {
            error = "Choose a different export destination; the active collection file cannot be overwritten."
            return
        }
        let items = pendingCollection ?? collection
        Task { [weak self] in
            do {
                try await Task.detached(priority: .utility) { try CollectionStorage(file: url).save(items) }.value
            } catch {
                self?.error = error.localizedDescription
            }
        }
    }

    func importCollection() {
        guard collectionLoaded else { error = "Load the collection before importing it."; return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { [weak self] in
            do {
                let imported = try await Task.detached(priority: .userInitiated) {
                    try CollectionStorage(file: url).load()
                }.value
                if let self { _ = await self.mergeImported(imported) }
            } catch {
                self?.error = "Invalid collection file: \(error.localizedDescription)"
            }
        }
    }
}

func copyText(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

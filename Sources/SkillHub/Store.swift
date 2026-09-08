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
    private var lastRefresh: Date?
    private var lastPaths: [String] = []
    let storage: CollectionStorage

    init(storage: CollectionStorage = .standard) { self.storage = storage }

    func loadCollection() async {
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
            if !collectionLoaded { collection = items; collectionLoaded = true }
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
        // Loaded descendants may change even when the shallow scan is equal.
        refreshGeneration &+= 1
        lastPaths = [a, c]
        lastRefresh = Date()
        scanning = false
    }

    @discardableResult func save(_ skill: SavedSkill) -> Bool {
        var next = collection
        if let index = next.firstIndex(where: { $0.id == skill.id }) { next[index] = skill }
        else { next.append(skill) }
        return persist(next)
    }
    func delete(_ skill: SavedSkill) { _ = persist(collection.filter { $0.id != skill.id }) }
    private func persist(_ items: [SavedSkill]) -> Bool {
        guard collectionLoaded else {
            error = collectionLoading ? "The collection is still loading. Try again shortly."
                : "Collection is unavailable. Repair or restore \(storage.file.path), then reopen the app."
            return false
        }
        do { try storage.save(items); collection = items; return true }
        catch { self.error = "Could not save collection: \(error.localizedDescription)"; return false }
    }
    func exportCollection() {
        guard collectionLoaded else { error = "Load the collection before exporting it."; return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "skill-collection.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try CollectionStorage(file: url).save(collection) }
        catch { self.error = error.localizedDescription }
    }
    func importCollection() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try CollectionStorage(file: url).load()
            var next = collection
            for item in imported where !next.contains(where: { $0.id == item.id }) { next.append(item) }
            _ = persist(next)
        } catch { self.error = "Invalid collection file: \(error.localizedDescription)" }
    }
}

func copyText(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

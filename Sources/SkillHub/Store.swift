import SwiftUI
import AppKit

@MainActor final class HubStore: ObservableObject {
    @Published var agents: [InstalledSkill] = []
    @Published var claude: [InstalledSkill] = []
    @Published var collection: [SavedSkill] = []
    @Published var scanMessages: [String: String] = [:]
    @Published var error: String?
    @Published var scanning = false
    private var collectionLoaded = false
    let storage = CollectionStorage.standard

    init() {
        do { collection = try storage.load(); collectionLoaded = true }
        catch { self.error = "Could not load collection. Your file has not been changed.\n\(error.localizedDescription)" }
    }

    func refresh() async {
        guard !scanning else { return }
        scanning = true
        let a = UserDefaults.standard.string(forKey: "agentsPath") ?? "~/.agents/skills"
        let c = UserDefaults.standard.string(forKey: "claudePath") ?? "~/.claude/skills"
        let result = await Task.detached {
            (Result { try SkillScanner.scan(path: a) }, Result { try SkillScanner.scan(path: c) })
        }.value
        scanMessages = [:]
        switch result.0 {
        case .success(let items): agents = items
        case .failure(let error): agents = []; scanMessages["agents"] = "\(a): \(error.localizedDescription)"
        }
        switch result.1 {
        case .success(let items): claude = items
        case .failure(let error): claude = []; scanMessages["claude"] = "\(c): \(error.localizedDescription)"
        }
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
        guard collectionLoaded else { error = "Collection is unavailable. Repair or restore \(storage.file.path), then reopen the app."; return false }
        do { try storage.save(items); collection = items; return true }
        catch { self.error = "Could not save collection: \(error.localizedDescription)"; return false }
    }
    func exportCollection() {
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

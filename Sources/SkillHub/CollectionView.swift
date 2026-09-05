import SwiftUI
import AppKit

struct CollectionView: View {
    @EnvironmentObject var store: HubStore
    @AppStorage("terminal") private var terminal = "Terminal"
    @State private var search = ""
    @State private var category = "All categories"
    @State private var sort = "Name"
    @State private var favorites = false
    @State private var draft: SavedSkill?
    @State private var installing: SavedSkill?
    @State private var deleting: SavedSkill?
    var categories: [String] { Array(Set(store.collection.map(\.category).filter { !$0.isEmpty })).sorted() }
    var items: [SavedSkill] {
        store.collection.filter {
            (category == "All categories" || $0.category == category) && (!favorites || $0.favorite) &&
            (search.isEmpty || "\($0.name) \($0.summary) \($0.category) \($0.url)".localizedCaseInsensitiveContains(search))
        }.sorted { sort == "Newest" ? $0.createdAt > $1.createdAt : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Your skill collection").font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("Save skill links, categories, and installation commands.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { draft = SavedSkill() } label: { Label("Add skill", systemImage: "plus") }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut("n")
            }
            CollectionToolbar(search: $search, category: $category, sort: $sort, favorites: $favorites,
                              categories: categories, importCollection: store.importCollection,
                              exportCollection: store.exportCollection)
            if items.isEmpty {
                VStack {
                    EmptyState(icon: "bookmark", title: store.collection.isEmpty ? "No saved skills" : "No matching skills", detail: store.collection.isEmpty ? "Add a skill to your collection. Saving an entry does not install it." : "Try another search or category.")
                    if store.collection.isEmpty { Button("Add your first skill") { draft = SavedSkill() }.buttonStyle(.borderedProminent).padding(.bottom, 80) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 18)], alignment: .leading, spacing: 18) {
                        ForEach(items) { skill in card(skill) }
                    }.padding(.bottom, 12)
                }
            }
        }.padding(28)
        .sheet(item: $draft) { CollectionEditor(initial: $0) }
        .alert("Run installation command?", isPresented: Binding(get: { installing != nil }, set: { if !$0 { installing = nil } })) {
            Button("Cancel", role: .cancel) { installing = nil }
            Button("Run in \(terminal)", role: .destructive) {
                guard let skill = installing else { return }
                do { try TerminalLauncher.launch(command: skill.command, application: terminal) }
                catch { store.error = error.localizedDescription }
                installing = nil
            }
        } message: { Text("Only run commands you trust. This runs with your user permissions in your home directory.\n\n\(installing?.command ?? "")") }
        .alert("Remove from collection?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Remove", role: .destructive) { if let deleting { store.delete(deleting) }; deleting = nil }
        } message: { Text("This only removes the bookmark. Installed files are never deleted.") }
    }
    func card(_ skill: SavedSkill) -> some View {
        SavedSkillCard(skill: skill, favorite: {
            var updated = skill
            updated.favorite.toggle()
            store.save(updated)
        }, install: { installing = skill }, edit: { draft = skill }, remove: { deleting = skill })
    }
}

struct CollectionEditor: View {
    @EnvironmentObject var store: HubStore
    @Environment(\.dismiss) var dismiss
    @State private var skill: SavedSkill
    init(initial: SavedSkill) { _skill = State(initialValue: initial) }
    var validURL: Bool { skill.url.isEmpty || (URL(string: skill.url).map { ["https", "http"].contains($0.scheme?.lowercased() ?? "") && $0.host != nil } ?? false) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.collection.contains(where: { $0.id == skill.id }) ? "Edit skill" : "Add skill").font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Enter the skill details. Only the name is required.").foregroundStyle(.secondary)
            }
            field("NAME", placeholder: "e.g. Interface design", text: $skill.name)
            field("SOURCE URL", placeholder: "https://github.com/owner/skills", text: $skill.url)
            if !validURL { Text("Enter a valid http or https URL.").font(.caption).foregroundStyle(.red) }
            field("DESCRIPTION", placeholder: "Briefly describe what the skill does", text: $skill.summary)
            field("CATEGORY", placeholder: "e.g. Development, Design, Writing", text: $skill.category)
            VStack(alignment: .leading, spacing: 8) {
                Text("INSTALL COMMAND").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                TextEditor(text: $skill.command).font(.system(size: 12, design: .monospaced)).scrollContentBackground(.hidden).padding(8).frame(height: 72).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                Text("Optional. Saved as text; runs only after your confirmation.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Toggle("Favorite", isOn: $skill.favorite)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save skill") {
                    skill.name = skill.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    skill.category = skill.category.trimmingCharacters(in: .whitespacesAndNewlines)
                    if store.save(skill) { dismiss() }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(skill.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !validURL)
            }
        }.padding(30).frame(width: 500)
    }
    func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.plain).padding(11).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

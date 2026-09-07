import SwiftUI
import AppKit

struct InstalledView: View {
    @EnvironmentObject var store: HubStore
    let source: String
    @State private var search = ""
    @State private var selectedID: String?
    @State private var selectedFile: URL?
    @State private var expanded: Set<String> = []
    @State private var draft: SavedSkill?
    @State private var removal: SkillRemoval?
    @AppStorage("agentsPath") private var agentsPath = "~/.agents/skills"
    @AppStorage("claudePath") private var claudePath = "~/.claude/skills"
    private var rootPath: String { source == "agents" ? agentsPath : claudePath }
    var skills: [InstalledSkill] { source == "agents" ? store.agents : store.claude }
    var filtered: [InstalledSkill] { skills.filter { search.isEmpty || "\($0.name) \($0.summary)".localizedCaseInsensitiveContains(search) } }
    var selected: InstalledSkill? { skills.first { $0.id == selectedID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text(source == "agents" ? "Agent skills" : "Claude skills").font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("Browse globally installed skills.").foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(skills.count) installed", systemImage: "checkmark.circle.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(hubTeal)
                    .padding(10).background(hubTeal.opacity(0.08), in: Capsule())
            }
            if let message = store.scanMessages[source] {
                Label(message + " Check the path in Settings.", systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            HSplitView {
                VStack(spacing: 12) {
                    HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Find a skill…", text: $search).textFieldStyle(.plain) }
                        .padding(11).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filtered) { skill in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top, spacing: 8) {
                                        if !skill.files.isEmpty {
                                            Button {
                                                if expanded.contains(skill.id) { expanded.remove(skill.id) } else { expanded.insert(skill.id) }
                                            } label: { Image(systemName: expanded.contains(skill.id) ? "chevron.down" : "chevron.right").font(.system(size: 10)).frame(width: 14, height: 20) }.buttonStyle(.plain).help("Expand files")
                                        }
                                        Button { selectedID = skill.id; selectedFile = skill.document } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(skill.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(selectedID == skill.id ? hubTeal : .primary)
                                                Text(skill.summary.isEmpty ? "Local skill bundle" : skill.summary).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                    }
                                    if expanded.contains(skill.id) {
                                        SkillFileTree(nodes: skill.files, selectedFile: selectedFile) { file in
                                            selectedID = skill.id
                                            selectedFile = file
                                        }
                                    }
                                }.padding(12).background(selectedID == skill.id ? hubTeal.opacity(0.08) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                            }
                            if filtered.isEmpty { Text("No matching skills").foregroundStyle(.secondary).padding(20) }
                        }
                    }
                }.padding(.trailing, 12).frame(minWidth: 230, idealWidth: 275, maxWidth: 360)
                VStack(spacing: 0) {
                    if let skill = selected {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(skill.name).font(.headline)
                                Text(selectedFile?.lastPathComponent ?? "Skill bundle").font(.caption).foregroundStyle(.secondary)
                            }
                            HStack {
                                Button { draft = SavedSkill(name: skill.name, summary: skill.summary) } label: {
                                    Label("Save skill", systemImage: "bookmark")
                                }.fixedSize().help("Save to collection")
                                Button(role: .destructive) {
                                    do { removal = try SkillRemoval.prepare(target: skill.folder, rootPath: rootPath) }
                                    catch { store.error = error.localizedDescription }
                                } label: { Label("Remove…", systemImage: "trash") }
                                    .fixedSize().disabled(store.scanning).help("Move the whole selected skill to Trash")
                                Button { NSWorkspace.shared.activateFileViewerSelecting([selectedFile ?? skill.folder]) } label: {
                                    Label("Finder", systemImage: "arrow.up.right.square")
                                }.help("Reveal in Finder")
                            }.controlSize(.small)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                        Divider()
                        if let file = selectedFile { DocumentView(url: file).id(file) }
                        else { EmptyState(icon: "folder", title: "Select a file", detail: "Expand the skill’s file tree and select a document to preview it.") }
                    } else { EmptyState(icon: "doc.text.magnifyingglass", title: "Select a skill", detail: "Select a skill to read its instructions. Expand its file tree to view references and subskills.") }
                }.frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.07)))
                    .padding(.leading, 12)
            }
        }.padding(26)
        .background(ScrollPolicyUpdate())
        .onAppear { selectFirst() }
        .onChange(of: skills.map(\.id)) { _ in selectFirst() }
        .sheet(item: $draft) { item in CollectionEditor(initial: item) }
        .alert("Move selected skill to Trash?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } })) {
            Button("Cancel", role: .cancel) { removal = nil }
            Button("Move to Trash", role: .destructive) { removeSelectedSkill() }
        } message: {
            if let removal {
                Text((removal.isLink
                      ? "Only this symbolic link will be removed. Its target and files will stay in place."
                      : removal.isDirectory
                        ? "The entire skill folder and its contents will be removed, not just the open document."
                        : "This standalone Markdown skill file will be removed.")
                     + "\n\n" + removal.target.path
                     + "\n\nYou can restore it from Trash. Saved collection entries will remain.")
            }
        }
    }
    private func removeSelectedSkill() {
        guard let request = removal, !store.scanning else { return }
        removal = nil
        do {
            try request.moveToTrash(rootPath: rootPath)
            selectedID = nil
            selectedFile = nil
            Task { await store.refresh() }
        } catch { store.error = error.localizedDescription }
    }
    func selectFirst() {
        if selected == nil { selectedID = skills.first?.id; selectedFile = skills.first?.document }
    }
}

struct DocumentView: View {
    let url: URL
    @State private var snapshot: DocumentSnapshot?
    private var text: String { snapshot?.text ?? "" }
    @State private var error: String?
    @State private var raw = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).lineLimit(1).truncationMode(.middle).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Toggle("Source", isOn: $raw).toggleStyle(.switch).controlSize(.mini)
                Button { copyText(text) } label: { Image(systemName: "doc.on.doc") }.help("Copy document").disabled(text.isEmpty)
            }.padding(14)
            Divider()
            if let error { EmptyState(icon: "doc.questionmark", title: "Preview unavailable", detail: error) }
            else if snapshot == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if !raw, let markdown = snapshot?.markdown {
                        MarkdownDocument(content: markdown, baseURL: url.deletingLastPathComponent()).equatable().padding(26)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            if snapshot?.sourceOnly == true {
                                Text("Large Markdown document: showing source to keep the interface responsive. Open in Finder for another viewer.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(text).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(ScrollPolicyUpdate())
        .task(id: url) {
            error = nil
            snapshot = nil
            do {
                let value = try await DocumentLoader.shared.loadPreview(url)
                guard !Task.isCancelled else { return }
                snapshot = value
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }
    }
}

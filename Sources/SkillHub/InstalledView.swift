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
    var skills: [InstalledSkill] { source == "agents" ? store.agents : store.claude }
    var filtered: [InstalledSkill] { skills.filter { search.isEmpty || "\($0.name) \($0.summary)".localizedCaseInsensitiveContains(search) } }
    var selected: InstalledSkill? { skills.first { $0.id == selectedID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text(source == "agents" ? "Agent skills" : "Claude skills").font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("Installed globally. Ready for your next idea.").foregroundStyle(.secondary)
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
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(skill.name).font(.headline)
                                Text(selectedFile?.lastPathComponent ?? "Skill bundle").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { draft = SavedSkill(name: skill.name, summary: skill.summary) } label: { Image(systemName: "bookmark.badge.plus") }.help("Save to collection")
                            Button { NSWorkspace.shared.activateFileViewerSelecting([selectedFile ?? skill.folder]) } label: { Label("Finder", systemImage: "arrow.up.right.square") }.help("Reveal in Finder")
                        }.padding(18)
                        Divider()
                        if let file = selectedFile { DocumentView(url: file).id(file) }
                        else { EmptyState(icon: "folder", title: "Explore this bundle", detail: "Expand the skill’s file tree and select a document to preview it.") }
                    } else { EmptyState(icon: "doc.text.magnifyingglass", title: "A little expertise, on hand", detail: "Select a skill to read its instructions. Expand its tree to explore references and subskills.") }
                }.frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.07)))
            }
        }.padding(26)
        .onAppear { selectFirst() }
        .onChange(of: skills.map(\.id)) { _ in selectFirst() }
        .sheet(item: $draft) { item in CollectionEditor(initial: item) }
    }
    func selectFirst() {
        if selected == nil { selectedID = skills.first?.id; selectedFile = skills.first?.document }
    }
}

struct DocumentView: View {
    let url: URL
    @State private var text = ""
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
            else {
                ScrollView {
                    if raw || !["md", "markdown"].contains(url.pathExtension.lowercased()) {
                        Text(text).font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding(24).textSelection(.enabled)
                    } else { MarkdownDocument(text: text, baseURL: url.deletingLastPathComponent()).padding(26) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.task(id: url) {
            let result = await Task.detached { () -> Result<String, Error> in
                Result {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 2_000_000 else { throw NSError(domain: "Preview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Files over 2 MB can be opened in Finder."]) }
                    return try String(contentsOf: url, encoding: .utf8)
                }
            }.value
            switch result { case .success(let value): text = value; case .failure(let issue): error = issue.localizedDescription }
        }
    }
}

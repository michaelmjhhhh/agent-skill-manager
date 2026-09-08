import SwiftUI

/// Flatten visible nodes so every row shares the same leading coordinate system.
/// OutlineGroup outside List centers leaf labels on macOS instead of aligning them.
struct SkillTreeRow: Identifiable {
    var id: String { node.id }
    let node: FileNode
    let depth: Int

    static func visible(in nodes: [FileNode], expanded: Set<String>, depth: Int = 0) -> [SkillTreeRow] {
        nodes.flatMap { node in
            let row = SkillTreeRow(node: node, depth: depth)
            guard let children = node.children, node.childrenLoaded, expanded.contains(node.id) else { return [row] }
            return [row] + visible(in: children, expanded: expanded, depth: depth + 1)
        }
    }
}

struct SkillFileTree: View {
    let nodes: [FileNode]
    let rootOmittedCount: Int
    let rootNotice: String?
    let refreshGeneration: Int
    let selectedFile: URL?
    let select: (URL) -> Void
    @State private var localNodes: [FileNode]
    @State private var expanded: Set<String> = []
    @State private var loadingPaths: Set<String> = []
    @State private var currentGeneration: Int

    init(nodes: [FileNode], rootOmittedCount: Int = 0, rootNotice: String? = nil,
         refreshGeneration: Int = 0, selectedFile: URL?, select: @escaping (URL) -> Void) {
        self.nodes = nodes
        self.rootOmittedCount = rootOmittedCount
        self.rootNotice = rootNotice
        self.refreshGeneration = refreshGeneration
        self.selectedFile = selectedFile
        self.select = select
        _localNodes = State(initialValue: nodes)
        _currentGeneration = State(initialValue: refreshGeneration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SkillTreeRow.visible(in: localNodes, expanded: expanded)) { row in
                rowView(row)
            }
            if rootOmittedCount > 0 {
                omittedNotice(rootOmittedCount, depth: 0)
            }
            if let rootNotice {
                noticeView(rootNotice, depth: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: nodes) { newValue in
            localNodes = newValue
            expanded = expanded.intersection(Set(newValue.map(\.id)))
            loadingPaths.removeAll()
        }
        .onChange(of: refreshGeneration) { _ in
            // A shallow scan can compare equal while files in previously
            // loaded descendants changed. Drop all loaded values and let the
            // next expansion read from the new filesystem snapshot.
            localNodes = nodes
            loadingPaths.removeAll()
            expanded.removeAll()
            currentGeneration = refreshGeneration
        }
    }

    @ViewBuilder
    private func rowView(_ row: SkillTreeRow) -> some View {
        let folder = row.node.isDirectory
        let isExpanded = expanded.contains(row.id)
        let isSelected = selectedFile == row.node.url
        VStack(alignment: .leading, spacing: 1) {
            Button {
                if folder {
                    if isExpanded {
                        expanded.remove(row.id)
                    } else {
                        expanded.insert(row.id)
                        loadChildrenIfNeeded(row.node)
                    }
                } else {
                    select(row.node.url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: folder ? (isExpanded ? "chevron.down" : "chevron.right") : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12).opacity(folder ? 1 : 0)
                    Image(systemName: folder ? (isExpanded ? "folder.fill" : "folder") : "doc.text")
                        .frame(width: 15).foregroundStyle(isSelected ? hubTeal : .secondary)
                    Text(row.node.url.lastPathComponent)
                        .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? hubTeal : .primary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 4 + CGFloat(row.depth) * 16)
                .padding(.trailing, 6)
                .frame(maxWidth: .infinity, minHeight: 27, alignment: .leading)
                .background(isSelected ? hubTeal.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help(row.node.url.path)
            .accessibilityLabel(row.node.url.lastPathComponent)
            .accessibilityValue(folder ? (isExpanded ? "Expanded" : "Collapsed") : (isSelected ? "Selected" : "File"))
            .accessibilityHint(folder ? "Toggle folder contents" : "Preview file")
            if row.node.omittedCount > 0 {
                omittedNotice(row.node.omittedCount, depth: row.depth + 1)
            }
            if let notice = row.node.notice {
                noticeView(notice, depth: row.depth + 1)
            }
        }
    }

    private func omittedNotice(_ count: Int, depth: Int) -> some View {
        Text("Showing the first \(SkillScanner.entriesPerDirectoryLimit) entries; \(count) omitted")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.leading, 8 + CGFloat(depth) * 16)
            .padding(.vertical, 3)
            .accessibilityLabel("\(count) entries omitted")
    }

    private func noticeView(_ notice: String, depth: Int) -> some View {
        Text(notice)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.leading, 8 + CGFloat(depth) * 16)
            .padding(.vertical, 3)
            .accessibilityLabel(notice)
    }

    private func loadChildrenIfNeeded(_ node: FileNode) {
        guard !node.childrenLoaded, !loadingPaths.contains(node.id) else { return }
        let generation = currentGeneration
        loadingPaths.insert(node.id)
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                SkillScanner.loadChildren(of: node)
            }.value
            if generation == currentGeneration { loadingPaths.remove(node.id) }
            guard !Task.isCancelled, generation == currentGeneration else { return }
            _ = updateNode(id: node.id, in: &localNodes) { value in
                value.children = result.nodes
                value.omittedCount = result.omitted
                value.notice = result.notice
                value.childrenLoaded = true
            }
        }
    }

    private func updateNode(id: String, in nodes: inout [FileNode], _ update: (inout FileNode) -> Void) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == id {
                update(&nodes[index])
                return true
            }
            if var children = nodes[index].children,
               updateNode(id: id, in: &children, update) {
                nodes[index].children = children
                return true
            }
        }
        return false
    }
}

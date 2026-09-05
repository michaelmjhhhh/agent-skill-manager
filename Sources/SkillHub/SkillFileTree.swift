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
            guard let children = node.children, expanded.contains(node.id) else { return [row] }
            return [row] + visible(in: children, expanded: expanded, depth: depth + 1)
        }
    }
}

struct SkillFileTree: View {
    let nodes: [FileNode]
    let selectedFile: URL?
    let select: (URL) -> Void
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SkillTreeRow.visible(in: nodes, expanded: expanded)) { row in
                let folder = row.node.children != nil
                let isExpanded = expanded.contains(row.id)
                let isSelected = selectedFile == row.node.url
                Button {
                    if folder {
                        if isExpanded { expanded.remove(row.id) } else { expanded.insert(row.id) }
                    } else { select(row.node.url) }
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
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

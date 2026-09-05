import SwiftUI

struct SavedSkillCard: View {
    let skill: SavedSkill
    let favorite: () -> Void
    let install: () -> Void
    let edit: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 19)).foregroundStyle(hubTeal)
                    .frame(width: 42, height: 42)
                    .background(hubTeal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(skill.name).font(.system(size: 16, weight: .semibold))
                        .lineLimit(1).help(skill.name)
                    Text(skill.category.isEmpty ? "Uncategorized" : skill.category)
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(hubTeal)
                        .lineLimit(1).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(hubTeal.opacity(0.07), in: Capsule())
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button(action: favorite) {
                    Image(systemName: skill.favorite ? "star.fill" : "star")
                        .foregroundStyle(skill.favorite ? .orange : .secondary)
                        .frame(width: 24, height: 28)
                }.buttonStyle(.plain).help(skill.favorite ? "Remove favorite" : "Mark as favorite")
            }.frame(height: 44)

            Text(skill.summary.isEmpty ? "No description" : skill.summary)
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .lineLimit(2).lineSpacing(3)
                .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36, alignment: .topLeading)
                .help(skill.summary)

            sourceRow.frame(height: 22)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("INSTALL COMMAND").font(.system(size: 9, weight: .semibold)).tracking(1)
                    Spacer()
                    Button { copyText(skill.command) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).disabled(!skill.hasInstallCommand).help("Copy install command")
                }.foregroundStyle(.secondary)
                Text(skill.hasInstallCommand ? skill.command : "No command saved")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(skill.hasInstallCommand ? .primary : .secondary)
                    .lineLimit(2).truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .topLeading)
                    .help(skill.hasInstallCommand ? skill.command : "Add an installation command with Edit.")
            }.padding(12)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))

            Divider().opacity(0.5)

            HStack(spacing: 8) {
                Button(action: install) { Label("Install…", systemImage: "terminal") }
                    .buttonStyle(.borderedProminent).disabled(!skill.hasInstallCommand)
                    .help(skill.hasInstallCommand ? "Review and run installation command" : "Add a command to enable installation")
                Spacer()
                Button("Edit", action: edit).buttonStyle(.bordered)
                Menu {
                    Button("Remove from collection…", role: .destructive, action: remove)
                } label: { Image(systemName: "ellipsis") }
                    .menuIndicator(.hidden).frame(width: 28)
                    .help("More actions").accessibilityLabel("More actions for \(skill.name)")
            }.controlSize(.regular).frame(height: 28)
        }.padding(18)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.07)))
    }

    @ViewBuilder private var sourceRow: some View {
        if let url = skill.sourceURL {
            Link(destination: url) {
                HStack(spacing: 7) {
                    Image(systemName: "link").frame(width: 14)
                    Text(skill.sourceLabel).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.system(size: 9))
                }.font(.system(size: 11)).foregroundStyle(hubTeal)
            }.help(skill.url)
        } else {
            Label("No source linked", systemImage: "link")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

extension SavedSkill {
    var hasInstallCommand: Bool {
        let value = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !["", "n/a", "na", "none", "not applicable", "-"].contains(value)
    }
    var sourceURL: URL? {
        guard let value = URL(string: url), let host = value.host, !host.isEmpty,
              ["https", "http"].contains(value.scheme?.lowercased() ?? "") else { return nil }
        return value
    }
    var sourceLabel: String {
        guard let source = sourceURL else { return "No source linked" }
        let parts = source.pathComponents.filter { $0 != "/" }
        // Keep GitHub links recognizable without displaying the whole blob path.
        if source.host?.lowercased() == "github.com", parts.count >= 2 {
            return parts.prefix(2).joined(separator: " / ")
        }
        return (source.host ?? "") + (source.path == "/" ? "" : source.path)
    }
}

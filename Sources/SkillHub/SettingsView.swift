import SwiftUI
import AppKit

/// Expand the content to the pane width, not just the outer scroll-view frame.
/// This keeps the system scrollbar at the window edge instead of beside the cards.
struct SettingsPage: View {
    var body: some View {
        ScrollView(.vertical) {
            HubSettings()
                .frame(maxWidth: 750)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HubSettings: View {
    @EnvironmentObject var store: HubStore
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("terminal") private var terminal = "Terminal"
    @AppStorage("agentsPath") private var agentsPath = "~/.agents/skills"
    @AppStorage("claudePath") private var claudePath = "~/.claude/skills"
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Settings").font(.system(size: 28, weight: .bold, design: .rounded))
            section("Appearance", icon: "circle.lefthalf.filled") {
                Picker("Theme", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            }
            section("Skill locations", icon: "folder") {
                pathField("Agent skills", path: $agentsPath)
                pathField("Claude skills", path: $claudePath)
                HStack {
                    Text("Read-only browsing. Existing skills are never modified.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Apply & refresh") { Task { await store.refresh() } }.disabled(store.scanning)
                }
            }
            section("Installation terminal", icon: "terminal") {
                Picker("Open commands in", selection: $terminal) { Text("Terminal").tag("Terminal"); Text("iTerm").tag("iTerm") }
                Text("Commands open in a new terminal session after confirmation. iTerm requires iTerm2 to be installed. Refresh after installing to see new skills.").font(.caption).foregroundStyle(.secondary)
            }
            section("Your data", icon: "externaldrive") {
                Text("Your collection is stored locally as JSON. Export a backup or import a collection; existing IDs are kept when merging.").font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Import…") { store.importCollection() }
                    Button("Export…") { store.exportCollection() }
                    Spacer()
                    Button("Show data in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.storage.file.deletingLastPathComponent()]) }
                }
            }
        }.padding(28).frame(minWidth: 540)
    }
    func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(hubTeal)
            content()
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.06)))
    }
    func pathField(_ title: String, path: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Folder path", text: path).textFieldStyle(.roundedBorder)
                Button("Choose…") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.showsHiddenFiles = true
                    if panel.runModal() == .OK, let url = panel.url { path.wrappedValue = url.path }
                }
            }
        }
    }
}

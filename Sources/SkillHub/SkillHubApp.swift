import SwiftUI
import AppKit

let hubTeal = Color(red: 0.05, green: 0.52, blue: 0.48)

@main struct SkillHubApp: App {
    @StateObject private var store = HubStore()
    @AppStorage("appearance") private var appearance = "System"
    var body: some Scene {
        WindowGroup {
            HubView().environmentObject(store)
                .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
                .tint(hubTeal)
                .frame(minWidth: 980, minHeight: 650)
                .onAppear { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Refresh Skills") { Task { await store.refresh() } }.keyboardShortcut("r")
            }
        }
        Settings {
            SettingsPage().environmentObject(store).tint(hubTeal)
                .frame(width: 700, height: 650)
        }
    }
}

enum HubPage: String, CaseIterable {
    case agents, claude, collection, settings
    var title: String {
        switch self { case .agents: return "Agent skills"; case .claude: return "Claude skills"; case .collection: return "Collection"; case .settings: return "Settings" }
    }
    var icon: String {
        switch self { case .agents: return "square.stack.3d.up"; case .claude: return "sparkle"; case .collection: return "bookmark"; case .settings: return "slider.horizontal.3" }
    }
}

struct HubView: View {
    @EnvironmentObject var store: HubStore
    @Environment(\.scenePhase) var phase
    @State private var page: HubPage = .agents
    @State private var sidebar = true
    var body: some View {
        HStack(spacing: 0) {
            if sidebar {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up.fill").font(.title2).foregroundStyle(hubTeal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Skill Hub").font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("A home for your capabilities").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }.padding(.top, 30)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary).padding(.bottom, 7)
                        ForEach([HubPage.agents, .claude, .collection], id: \.self) { navigation($0) }
                    }
                    Spacer()
                    navigation(.settings)
                }.padding(20).frame(width: 218).background(hubTeal.opacity(0.035))
                Divider()
            }
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { sidebar.toggle() } label: { Image(systemName: "sidebar.left") }.buttonStyle(.plain).help("Toggle sidebar")
                    Text("WORKSPACE").tracking(1.3).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(.tertiary)
                    Text(page.title).font(.system(size: 12, weight: .medium))
                    Spacer()
                    if store.scanning { ProgressView().controlSize(.small) }
                    Button { Task { await store.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }.disabled(store.scanning)
                }.padding(.horizontal, 26).frame(height: 58)
                Divider()
                switch page {
                case .agents, .claude: InstalledView(source: page.rawValue).id(page)
                case .collection: CollectionView()
                case .settings: SettingsPage()
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await store.refresh() }
        .onChange(of: phase) { value in if value == .active { Task { await store.refresh() } } }
        .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
    private func navigation(_ item: HubPage) -> some View {
        Button { page = item } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon).frame(width: 20)
                Text(item.title)
                Spacer()
                if item != .settings {
                    Text("\(item == .agents ? store.agents.count : item == .claude ? store.claude.count : store.collection.count)")
                        .font(.system(size: 10, weight: .semibold)).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(page == item ? hubTeal.opacity(0.12) : Color.secondary.opacity(0.08), in: Capsule())
                }
            }.font(.system(size: 13, weight: page == item ? .semibold : .regular))
                .padding(11).foregroundStyle(page == item ? hubTeal : .primary)
                .background(page == item ? hubTeal.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(hubTeal).padding(20).background(hubTeal.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
            Text(title).font(.title3.weight(.semibold))
            Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 380)
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

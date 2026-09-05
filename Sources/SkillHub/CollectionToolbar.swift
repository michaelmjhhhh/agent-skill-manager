import SwiftUI

struct CollectionToolbar: View {
    @Binding var search: String
    @Binding var category: String
    @Binding var sort: String
    @Binding var favorites: Bool
    let categories: [String]
    let importCollection: () -> Void
    let exportCollection: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search your collection…", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).help("Clear search")
                }
            }
            .padding(.horizontal, 12).frame(minWidth: 120, maxWidth: .infinity).frame(height: 36)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))

            Menu {
                Picker("Category", selection: $category) {
                    Text("All categories").tag("All categories")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(category).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }.toolbarSurface(width: 150)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .help("Filter by category").accessibilityLabel("Category: \(category)")

            Menu {
                Picker("Sort by", selection: $sort) {
                    Text("Name").tag("Name")
                    Text("Newest").tag("Newest")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down").foregroundStyle(.secondary)
                    Text(sort)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }.toolbarSurface(width: 118)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .help("Sort collection").accessibilityLabel("Sort by: \(sort)")

            Button { favorites.toggle() } label: {
                Image(systemName: favorites ? "star.fill" : "star")
                    .foregroundStyle(favorites ? hubTeal : .secondary)
                    .toolbarSurface(width: 36, selected: favorites)
            }.buttonStyle(.plain)
                .help(favorites ? "Show all skills" : "Show favorites only")
                .accessibilityLabel("Favorites only").accessibilityValue(favorites ? "On" : "Off")

            Menu {
                Button("Import JSON…", action: importCollection)
                Button("Export JSON…", action: exportCollection)
            } label: {
                Image(systemName: "ellipsis").toolbarSurface(width: 36)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .help("Import or export collection").accessibilityLabel("Collection actions")
        }
        .font(.system(size: 12))
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    func toolbarSurface(width: CGFloat, selected: Bool = false) -> some View {
        self.padding(.horizontal, width > 36 ? 12 : 0)
            .frame(width: width, height: 36)
            .background(selected ? hubTeal.opacity(0.10) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

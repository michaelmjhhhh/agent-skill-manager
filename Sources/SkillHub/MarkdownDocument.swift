import SwiftUI
import AppKit
import MarkdownUI

/// GitHub-flavored Markdown rendered as native SwiftUI views, not HTML/WebKit.
struct MarkdownDocument: View, Equatable {
    let content: MarkdownContent
    let baseURL: URL

    init(content: MarkdownContent, baseURL: URL) {
        self.content = content
        self.baseURL = baseURL
    }

    init(text: String, baseURL: URL) {
        self.init(content: MarkdownContent(Self.bodyText(text)), baseURL: baseURL)
    }

    nonisolated static func bodyText(_ source: String) -> String {
        var normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        if normalized.hasPrefix("\u{FEFF}") { normalized.removeFirst() }
        let lines = normalized.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { ["---", "..."].contains($0.trimmingCharacters(in: .whitespaces)) }),
              // Don't mistake a Markdown horizontal rule for YAML metadata.
              lines[1..<end].contains(where: { $0.contains(":") }) else { return normalized }
        return lines.dropFirst(end + 1).joined(separator: "\n")
    }

    var body: some View {
        Markdown(content, baseURL: baseURL, imageBaseURL: baseURL)
            .markdownTheme(.skillHub)
            .background(ScrollPolicyUpdate())
            .markdownImageProvider(LocalMarkdownImages())
            .markdownInlineImageProvider(LocalInlineImages())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                // A document link must not execute a local script or custom URL scheme.
                if url.isFileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    return .handled
                }
                return ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") ? .systemAction : .discarded
            })
    }
}

extension MarkdownUI.Theme {
    static let skillHub = Theme.gitHub
        .text {
            FontSize(14)
            ForegroundColor(.primary)
            BackgroundColor(nil)
        }
        .link { ForegroundColor(hubTeal) }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            BackgroundColor(Color.primary.opacity(0.055))
        }
        .codeBlock { configuration in
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(configuration.language?.uppercased() ?? "CODE")
                        .font(.system(size: 9, weight: .semibold)).tracking(1)
                    Spacer()
                    Button { copyText(configuration.content) } label: {
                        Label("Copy", systemImage: "doc.on.doc").font(.system(size: 10))
                    }.buttonStyle(.plain).help("Copy code")
                }.foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 10)
                Divider().opacity(0.5)
                ScrollView(.horizontal) {
                    configuration.label
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(12)
                            BackgroundColor(nil)
                        }
                        .relativeLineSpacing(.em(0.2))
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(14)
                }
            }
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06)))
            .markdownMargin(top: 0, bottom: 18)
        }
        .blockquote { configuration in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3).fill(hubTeal.opacity(0.5)).frame(width: 3)
                configuration.label
                    .markdownTextStyle { ForegroundColor(.secondary) }
                    .padding(.vertical, 4)
            }
            .padding(12)
            .fixedSize(horizontal: false, vertical: true)
            .background(hubTeal.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .markdownMargin(top: 0, bottom: 16)
        }
        .table { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .markdownTableBorderStyle(.init(color: Color.primary.opacity(0.10)))
                    .markdownTableBackgroundStyle(.alternatingRows(.clear, Color.primary.opacity(0.025)))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
            .markdownMargin(top: 0, bottom: 18)
        }
}

/// Opening a local skill never downloads tracking pixels or remote images.
private struct LocalMarkdownImages: ImageProvider {
    func makeImage(url: URL?) -> some View { LocalMarkdownImage(url: url) }
}

private struct LocalMarkdownImage: View {
    let url: URL?
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Label(url?.isFileURL == true ? "Image preview unavailable" : "Remote image · not loaded", systemImage: "photo")
                    .font(.caption).foregroundStyle(.secondary).padding(12)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
        }.task(id: url) {
            image = nil
            let target = url
            let loaded = await Task.detached(priority: .userInitiated) {
                LocalImageTransfer(image: target.flatMap { LocalImageLoader.load($0) })
            }.value
            guard !Task.isCancelled else { return }
            image = loaded.image
        }
    }
}

// NSImage's Sendable annotation starts at macOS 14. This single-owner transfer
// also supports macOS 13: the worker stops using the image before the UI receives it.
private struct LocalImageTransfer: @unchecked Sendable {
    let image: NSImage?
}

private struct LocalInlineImages: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        guard let image = LocalImageLoader.load(url, maxPixelSize: 256) else { return Image(systemName: "photo") }
        return Image(nsImage: image)
    }
}

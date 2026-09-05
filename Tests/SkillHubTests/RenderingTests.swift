import XCTest
import SwiftUI
import MarkdownUI
@testable import SkillHub

final class RenderingTests: XCTestCase {
    func testTreeDepthIsStableForSiblingsAndNestedFolders() {
        let base = URL(fileURLWithPath: "/skills")
        let nodes = [
            FileNode(url: base.appendingPathComponent("assets"), children: [
                FileNode(url: base.appendingPathComponent("assets/a.json"), children: nil),
                FileNode(url: base.appendingPathComponent("assets/b.json"), children: nil),
                FileNode(url: base.appendingPathComponent("assets/nested"), children: [
                    FileNode(url: base.appendingPathComponent("assets/nested/c.json"), children: nil)
                ])
            ]),
            FileNode(url: base.appendingPathComponent("SKILL.md"), children: nil)
        ]
        let collapsed = SkillTreeRow.visible(in: nodes, expanded: [])
        XCTAssertEqual(collapsed.map(\.depth), [0, 0])
        let open = Set([nodes[0].id, nodes[0].children![2].id])
        let rows = SkillTreeRow.visible(in: nodes, expanded: open)
        XCTAssertEqual(rows.map(\.depth), [0, 1, 1, 1, 2, 0])
        XCTAssertEqual(rows.map { $0.node.url.lastPathComponent }, ["assets", "a.json", "b.json", "nested", "c.json", "SKILL.md"])
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
        XCTAssertEqual(SkillTreeRow.visible(in: nodes, expanded: [nodes[0].children![2].id]).count, 2)
    }

    func testFrontmatterRemovalPreservesMarkdownStructure() {
        let input = "\u{FEFF}---\r\nname: Test\r\ndescription: A skill\r\n---\r\n# Title\r\n\r\nParagraph\r\ncontinued.\r\n\r\n- one\r\n- two"
        XCTAssertEqual(MarkdownDocument.bodyText(input), "# Title\n\nParagraph\ncontinued.\n\n- one\n- two")
        let rules = "---\nA paragraph\n---\nAnother paragraph"
        XCTAssertEqual(MarkdownDocument.bodyText(rules), rules)
        XCTAssertEqual(MarkdownDocument.bodyText("---\nname: Incomplete"), "---\nname: Incomplete")
    }

    func testRichMarkdownParsing() {
        let content = MarkdownContent(MarkdownDocument.bodyText(Self.sample))
        // HTML is used only to inspect the parser's structure in this test.
        // The app's renderer uses native SwiftUI views, not HTML.
        let html = content.renderHTML()
        for tag in ["<h1>", "<strong>", "<blockquote>", "<ol>", "<ul>", "<table>", "<pre>", "<del>"] {
            XCTAssertTrue(html.contains(tag), "Missing parsed element: \(tag)")
        }
        XCTAssertFalse(content.renderPlainText().contains("name: Preview"))
        XCTAssertTrue(content.renderPlainText().contains("continued on the next source line"))
    }

    @MainActor func testNativeMarkdownLayout() throws {
        let view = NSHostingView(rootView:
            MarkdownDocument(text: Self.sample, baseURL: URL(fileURLWithPath: "/tmp", isDirectory: true))
                .padding(24).frame(width: 640).environment(\.colorScheme, .light)
        )
        view.frame = NSRect(x: 0, y: 0, width: 640, height: 1100)
        view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(view.fittingSize.height, 300)
        XCTAssertLessThanOrEqual(view.fittingSize.width, 640)
    }

    static let sample = """
    ---
    name: Preview
    ---
    # Native Markdown

    A **bold** paragraph with *emphasis*, ~~removed text~~, and `inline code`,
    continued on the next source line.

    > A useful note.
    >
    > With another paragraph.

    1. First step
    2. Second step
       - Nested point
       - Another point

    - [x] Finished
    - [ ] Pending

    | Skill | Status |
    | :--- | ---: |
    | Design | Ready |
    | Writing | Saved |

    ```swift
    let greeting = "Hello, world"
    print(greeting)
    ```

    [Documentation](https://example.com)
    """
}

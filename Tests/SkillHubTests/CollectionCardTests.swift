import XCTest
import SwiftUI
@testable import SkillHub

final class CollectionCardTests: XCTestCase {
    func testPlaceholderCommandsAreNotInstallable() {
        for command in ["", "  ", "N/A", " n/a\n", "none", "-", "Not Applicable"] {
            XCTAssertFalse(SavedSkill(command: command).hasInstallCommand, command)
        }
        XCTAssertTrue(SavedSkill(command: "npm install example").hasInstallCommand)
        XCTAssertTrue(SavedSkill(command: "echo 'N/A'").hasInstallCommand)
    }

    func testCompactSourceKeepsOriginalDestination() {
        let url = "https://github.com/cursor/plugins/blob/main/pstack/skills/unslop/SKILL.md"
        let skill = SavedSkill(url: url)
        XCTAssertEqual(skill.sourceLabel, "cursor / plugins")
        XCTAssertEqual(skill.sourceURL?.absoluteString, url)
        XCTAssertEqual(SavedSkill(url: "https://example.com/skills").sourceLabel, "example.com/skills")
        XCTAssertNil(SavedSkill(url: "file:///tmp/install.command").sourceURL)
        XCTAssertNil(SavedSkill(url: "not a URL").sourceURL)
    }

    @MainActor func testCardsHaveConsistentHeightAndFitNarrowGrid() {
        let short = SavedSkill(name: "Writing", command: "N/A", summary: "Short description.")
        let long = SavedSkill(name: "A much longer skill name that should truncate", url: "https://github.com/owner/repository/blob/main/path/SKILL.md", command: String(repeating: "long-install-command ", count: 20), summary: String(repeating: "A detailed description. ", count: 20), category: "Development")
        for scheme in [ColorScheme.light, .dark] {
            let sizes = [short, long].map { skill in
                let view = NSHostingView(rootView:
                    SavedSkillCard(skill: skill, favorite: {}, install: {}, edit: {}, remove: {})
                        .frame(width: 310).environment(\.colorScheme, scheme)
                )
                view.frame = NSRect(x: 0, y: 0, width: 310, height: 360)
                view.layoutSubtreeIfNeeded()
                return view.fittingSize
            }
            XCTAssertEqual(sizes[0].height, sizes[1].height, accuracy: 1)
            XCTAssertLessThanOrEqual(sizes[1].width, 310)
            XCTAssertGreaterThan(sizes[0].height, 250)
        }
    }
}

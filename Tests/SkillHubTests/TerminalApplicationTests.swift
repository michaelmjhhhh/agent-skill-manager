import XCTest
@testable import SkillHub

final class TerminalApplicationTests: XCTestCase {
    func testCustomSelectionAndLegacyNames() {
        let selected = TerminalApplication(customPath: "/Applications/Custom Terminal.app", legacyName: "iTerm")
        XCTAssertEqual(selected.displayName, "Custom Terminal")
        XCTAssertEqual(selected.url?.path, "/Applications/Custom Terminal.app")
        XCTAssertEqual(TerminalApplication(customPath: "", legacyName: "iTerm").displayName, "iTerm")
        XCTAssertEqual(TerminalApplication(customPath: "", legacyName: "Terminal").displayName, "Terminal")
    }

    func testMissingAndNonApplicationSelectionsAreRejected() {
        XCTAssertThrowsError(try TerminalApplication.validate(URL(fileURLWithPath: "/missing/Terminal.app")))
        XCTAssertThrowsError(try TerminalApplication.validate(URL(fileURLWithPath: "/bin/zsh")))
        XCTAssertThrowsError(try TerminalApplication.validate(URL(string: "https://example.com/Terminal.app")!))
    }

    func testApplicationBundleValidationWithoutLaunching() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Test Terminal.app")
        let executables = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: executables, withIntermediateDirectories: true)
        let info: [String: String] = [
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "TestTerminal",
            "CFBundleIdentifier": "test.skillhub.terminal"
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        let executable = executables.appendingPathComponent("TestTerminal")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let selected = TerminalApplication(customPath: app.path, legacyName: "Terminal")
        XCTAssertEqual(try selected.validatedURL().path, app.path)
        try FileManager.default.removeItem(at: executable)
        XCTAssertThrowsError(try selected.validatedURL())
    }
}

import XCTest
import AppKit
@testable import SkillHub

final class TerminalDriverTests: XCTestCase {
    func testSupportedDriversAndGhosttyVersionRequirement() {
        XCTAssertEqual(TerminalDriver.detect(identifier: "com.apple.Terminal", version: nil), .terminal)
        XCTAssertEqual(TerminalDriver.detect(identifier: "com.googlecode.iterm2", version: "3.5.0"), .iTerm)
        XCTAssertEqual(TerminalDriver.detect(identifier: "com.mitchellh.ghostty", version: "1.3.1"), .ghostty)
        XCTAssertEqual(TerminalDriver.detect(identifier: "com.mitchellh.ghostty", version: "1.10.0"), .ghostty)
        XCTAssertNil(TerminalDriver.detect(identifier: "com.mitchellh.ghostty", version: "1.2.3"))
        XCTAssertNil(TerminalDriver.detect(identifier: "com.mitchellh.ghostty", version: nil))
        XCTAssertNil(TerminalDriver.detect(identifier: "unknown.terminal", version: "9.0"))
    }

    func testCommandsStayInArgumentsNotAppleScriptSource() {
        let command = "printf '%s\\n' \"a quoted value\"; echo '$HOME'\nprintf '第二行'"
        let app = URL(fileURLWithPath: "/Applications/Terminal with spaces.app")
        for driver in [TerminalDriver.terminal, .iTerm, .ghostty] {
            let arguments = driver.arguments(app: app, command: command, home: "/Users/a user")
            XCTAssertEqual(arguments, ["-e", driver.script, "--", app.path, command, "/Users/a user"])
            XCTAssertFalse(driver.script.contains(command))
            XCTAssertFalse(driver.script.contains(".command"))
            XCTAssertFalse(driver.script.contains("System Events"))
        }
        XCTAssertTrue(TerminalDriver.ghostty.script.contains("new window with configuration cfg"))
        XCTAssertTrue(TerminalDriver.ghostty.script.contains("input text commandText to targetTerminal"))
    }

    func testTerminalScriptCompilesWithoutExecutingCommands() throws {
        try compile(TerminalDriver.terminal.script)
    }

    func testGhosttyScriptCompilesAgainstInstalledDictionary() throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty"),
              let bundle = Bundle(url: url),
              TerminalDriver.detect(identifier: bundle.bundleIdentifier,
                                    version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) == .ghostty else {
            throw XCTSkip("Ghostty 1.3+ is not installed")
        }
        try compile(TerminalDriver.ghostty.script)
    }

    private func compile(_ source: String) throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("SkillHub-test-\(UUID().uuidString).scpt")
        defer { try? FileManager.default.removeItem(at: output) }
        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
        process.arguments = ["-o", output.path, "-e", source]
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let data = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: data, as: UTF8.self))
    }
}

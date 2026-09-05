import AppKit

struct TerminalApplication {
    let customPath: String
    let legacyName: String

    var displayName: String {
        customPath.isEmpty ? legacyName : URL(fileURLWithPath: customPath).deletingPathExtension().lastPathComponent
    }

    var url: URL? {
        if !customPath.isEmpty { return URL(fileURLWithPath: customPath) }
        let identifier = legacyName == "iTerm" ? "com.googlecode.iterm2" : "com.apple.Terminal"
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
    }

    var driver: TerminalDriver? {
        guard let url, let bundle = Bundle(url: url) else { return nil }
        return TerminalDriver.detect(identifier: bundle.bundleIdentifier,
                                     version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    func validatedURL() throws -> URL {
        guard let url else {
            throw Self.error("\(displayName) is not installed. Choose a terminal in Settings.")
        }
        try Self.validate(url)
        return url
    }

    static func validate(_ url: URL) throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw error("The selected application is unavailable or invalid. Choose an installed .app in Settings.")
        }
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "SkillHub.Terminal", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

/// Only expose direct execution for documented, supported application APIs.
enum TerminalDriver: Equatable {
    case terminal, iTerm, ghostty

    static func detect(identifier: String?, version: String?) -> Self? {
        switch identifier {
        case "com.apple.Terminal": return .terminal
        case "com.googlecode.iterm2": return .iTerm
        case "com.mitchellh.ghostty":
            guard let version,
                  let major = Int(version.split(separator: ".").first ?? ""),
                  major >= 1,
                  version.compare("1.3.0", options: .numeric) != .orderedAscending else { return nil }
            return .ghostty
        default: return nil
        }
    }

    /// Commands and paths are argv values. They never become AppleScript source.
    var script: String {
        switch self {
        case .terminal:
            return """
            on run argv
                set appPath to item 1 of argv
                set commandText to item 2 of argv
                set homePath to item 3 of argv
                using terms from application "Terminal"
                    tell application appPath
                        activate
                        do script ("cd " & quoted form of homePath & " && " & commandText)
                    end tell
                end using terms from
            end run
            """
        case .iTerm:
            return """
            on run argv
                set appPath to item 1 of argv
                set commandText to item 2 of argv
                set homePath to item 3 of argv
                using terms from application "iTerm"
                    tell application appPath
                        activate
                        set newWindow to (create window with default profile)
                        tell current session of newWindow
                            write text ("cd " & quoted form of homePath & " && " & commandText)
                        end tell
                    end tell
                end using terms from
            end run
            """
        case .ghostty:
            return """
            on run argv
                set appPath to item 1 of argv
                set commandText to item 2 of argv
                set homePath to item 3 of argv
                using terms from application "Ghostty"
                    tell application appPath
                        activate
                        set cfg to new surface configuration
                        set initial working directory of cfg to homePath
                        set win to new window with configuration cfg
                        set targetTerminal to terminal 1 of selected tab of win
                        input text commandText to targetTerminal
                        send key "enter" to targetTerminal
                    end tell
                end using terms from
            end run
            """
        }
    }

    func arguments(app: URL, command: String, home: String) -> [String] {
        ["-e", script, "--", app.path, command, home]
    }
}

@MainActor enum TerminalLauncher {
    static func launch(command: String, application: TerminalApplication) async throws {
        let app = try application.validatedURL()
        guard let driver = application.driver else {
            throw NSError(domain: "SkillHub.Terminal", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "Direct execution is not supported for this terminal version. Use Copy command & open."])
        }
        let arguments = driver.arguments(app: app, command: command, home: NSHomeDirectory())
        // No temporary files, simulated keystrokes, or Accessibility permission.
        // Each driver creates a new session; existing sessions are not modified.
        try await Task.detached {
            let process = Process()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errors
            try process.run()
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let detail = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                let explanation = detail.contains("-1743")
                    ? "Automation permission was denied. Allow Skill Hub to control the terminal in System Settings > Privacy & Security > Automation, or use Copy command & open."
                    : "Could not send the command to the terminal. No retry was attempted. You can use Copy command & open."
                throw NSError(domain: "SkillHub.Terminal", code: Int(process.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: "\(explanation)\n\n\(detail)"])
            }
        }.value
    }

    static func copyAndOpen(command: String, application: TerminalApplication) async throws {
        let app = try application.validatedURL()
        copyText(command)
        // Never paste or execute automatically in fallback mode.
        _ = try await NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }
}

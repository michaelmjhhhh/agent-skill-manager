#!/usr/bin/env swift
import Foundation
import CoreGraphics

// Measures process launch to the first visible app window, not first-install Gatekeeper time.
// Only terminates processes started by this script. Requires a logged-in macOS desktop.
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift scripts/measure-launch.swift <app executable>\n", stderr)
    exit(1)
}
for _ in 0..<3 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    let start = ProcessInfo.processInfo.systemUptime
    try process.run()
    var visible = false
    while process.isRunning && ProcessInfo.processInfo.systemUptime - start < 10 {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        visible = windows.contains { window in
            (window[kCGWindowOwnerPID as String] as? Int32) == process.processIdentifier &&
            (window[kCGWindowLayer as String] as? Int) == 0 &&
            ((window[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0) > 300
        }
        if visible { break }
        Thread.sleep(forTimeInterval: 0.01)
    }
    print("Window visible: \(visible), ms: \(Int((ProcessInfo.processInfo.systemUptime - start) * 1000))")
    if process.isRunning { process.terminate() }
    process.waitUntilExit()
    if !visible { exit(1) }
}

# Changelog

User-facing changes are listed here. Unreleased changes have not shipped in a tagged release.

## [Unreleased]

### Changed

- Scan shared skill folders once per refresh, even when Agent and Claude entries link to the same folder.
- Cache document text and parsed Markdown. Check file attributes before reusing cached content.
- Skip repeated automatic refreshes within three seconds. Manual refresh still scans immediately.
- Load the collection and parse Markdown off the main thread.
- Configure scrollbars after content updates instead of traversing every window on each AppKit update.
- Show Markdown over 128 KB as source to avoid expensive rich-text layout. The text preview limit remains 2 MB.
- Load local preview images off the main thread and ignore results from cancelled document views.

### Fixed

- Display the supplied Claude brand icon in the sidebar using an explicitly loaded vector resource.

### Development

- Add a script to measure process launch to the first visible window.
- Record release changes in this file and use the matching version section for GitHub release notes.

## [0.0.1]

Released 2026-09-06.

### Added

- Move an installed skill's whole folder to Trash after path confirmation. Selecting a nested file does not change the removal target.
- Remove skill symlinks without removing their targets. Reject outside paths, unsafe source roots, and entries changed since confirmation.

### Fixed

- Replace the blank save control with a visible "Save skill" button and bookmark icon.
- Fix the local build script's empty-array error on macOS Bash 3.

### Changed

- Pin CI and release builds to Xcode 26.5, build 17F42, to match the local build toolchain.
- Simplify the README and explain removal behavior and its remaining filesystem race risk.

## [0.0.0]

Released 2026-09-06.

### Added

- Browse Agent and Claude skills, preview Markdown and source files, and save a separate collection of skill links and install commands.
- Choose an installation working folder and terminal before running a saved command.
- Add the supplied application icon.
- Build and publish a universal macOS DMG with a SHA-256 checksum through GitHub Actions.
- Document installation of the ad-hoc signed, unnotarized app.

### Release correction

- Replaced the original Xcode 15.4 DMG with an Xcode 26.5 rebuild on 2026-09-06. Updated its checksum. The version tag and app source stayed unchanged.

[Unreleased]: https://github.com/michaelmjhhhh/agent-skill-manager/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/michaelmjhhhh/agent-skill-manager/compare/v0.0.0...v0.0.1
[0.0.0]: https://github.com/michaelmjhhhh/agent-skill-manager/releases/tag/v0.0.0

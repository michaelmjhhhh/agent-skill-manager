# Changelog

User-facing changes are listed here. Unreleased changes have not shipped in a tagged release.

## [Unreleased]

## [0.0.3]

Released 2026-09-08.

### Changed

- Load child directories when expanded instead of walking every skill's file tree during the initial scan.
- Read frontmatter in 4 KiB blocks with a 64 KiB limit instead of loading the entire Markdown file for metadata.
- Move collection JSON encoding, decoding, and file I/O off the main actor. Serialize saves and use a Set to deduplicate imported IDs.
- Filter and sort the collection once per view body evaluation.

### Fixed

- Keep SKILL.md and README.md available when a directory exceeds the 500-entry display limit. Show notices for omitted entries, cycles, depth limits, and read failures.
- Discard stale child listings and reload the selected document after refresh.
- Keep the last successfully saved collection visible if a later queued write fails. Reject exports that target the active collection file or a symlink alias.
- Handle UTF-8 and frontmatter delimiters across read boundaries, including a closing delimiter at the exact 64 KiB limit.
- Separate the installed-skill preview card from the split divider and clip its content and border to the rounded corners.
- Fill the application icon canvas with an opaque background.

### Performance measurements

- On an Apple M4, release-build medians over seven runs reduced the nested-directory scan from 24.234 ms to 1.364 ms and metadata scanning for a 2.5 MB Markdown body from 20.215 ms to 0.091 ms.
- Reading and decoding 10,000 JSON records showed no improvement. Source-preview and scroll-policy changes remain deferred pending UI profiling.
- Add [reproducible benchmarks and measurement details](https://github.com/michaelmjhhhh/agent-skill-manager/blob/v0.0.3/docs/performance-issue-6.md). These numbers measure filesystem work, not UI frame times.

## [0.0.2]

Released 2026-09-07.

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

[Unreleased]: https://github.com/michaelmjhhhh/agent-skill-manager/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/michaelmjhhhh/agent-skill-manager/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/michaelmjhhhh/agent-skill-manager/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/michaelmjhhhh/agent-skill-manager/compare/v0.0.0...v0.0.1
[0.0.0]: https://github.com/michaelmjhhhh/agent-skill-manager/releases/tag/v0.0.0

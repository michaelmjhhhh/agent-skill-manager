# Agent Skill Manager

A macOS app for browsing installed agent skills and saving a collection of skill links and install commands. Built with SwiftUI, AppKit, and MarkdownUI.

Reads `~/.agents/skills` and `~/.claude/skills` by default. You can change both paths in Settings. No account required.

## Install

Download the universal `.dmg` from [Releases](https://github.com/michaelmjhhhh/agent-skill-manager/releases), open it, and drag Agent Skill Manager into Applications. Requires macOS 13 or later on Apple silicon or Intel.

The app is ad-hoc signed, but Apple has not notarized it. If macOS blocks it, try opening it once, then go to System Settings > Privacy & Security > Open Anyway.

For a download you trust, you can also remove quarantine from this app:

```sh
xattr -dr com.apple.quarantine "/Applications/Agent Skill Manager.app"
```

This removes the app's downloaded-file protection. It does not notarize the app or disable Gatekeeper for other apps.

Each release includes a SHA-256 checksum. To check your download, run this in the folder containing both files, replacing `X.Y.Z` with the release version:

```sh
shasum -a 256 -c Agent-Skill-Manager-X.Y.Z-universal.dmg.sha256
```

## What you can do

- Search installed skills, browse their files, and preview Markdown or source code.
- Save skill links, descriptions, categories, favorites, and install commands in a separate collection.
- Search, filter, and sort the collection. Import or export it as JSON.
- Choose a working folder and run a saved command in Terminal, iTerm2, or Ghostty 1.3 or later. Other terminals use "Copy command & open" so you can run it yourself.
- Switch between system, light, and dark appearance.

Press ⌘R to refresh or ⌘N to add a collection entry. The app also refreshes installed skills when it becomes active, skipping repeated automatic scans within three seconds. Manual refresh always scans again.

A refresh scans shared skill folders once, even when both sources link to them. Previews cache text and parsed Markdown for up to 32 documents, with an 8 MB source-text budget. Parsed Markdown uses additional memory. The app checks file attributes before reusing a document, and reads the collection after opening the window.

## Commands and permissions

Review install commands before running them. They run with your user permissions in a new terminal session, only after confirmation. The app never retries commands or tracks whether installation finished. Refresh the library afterward.

macOS may ask for Automation permission. If you deny it, you can enable it in System Settings > Privacy & Security > Automation. Ghostty also needs `macos-applescript` enabled, which is its default.

"Copy command & open" copies the command and opens your terminal. It does not paste or run anything.

## Your data

Use "Remove" in the installed skill view to move the selected skill's whole folder to Trash. The confirmation shows the path. Selecting a nested document still removes the whole skill, not just that document. A standalone Markdown skill removes only that file. For a symbolic link, only the link moves to Trash, not its target.

You can restore removed entries from Trash. Removing an installed skill keeps its collection entry. Removing a collection entry does not uninstall the skill.

Removal checks that the entry is a direct child of the configured skills folder and that its filesystem identity has not changed since confirmation. It refuses the source root, home directory, and outside paths. There is no permanent-delete fallback. A separate process changing filesystem paths during the final Trash operation remains a race risk.

Collection entries live in:

```text
~/Library/Application Support/SkillHub/collection.json
```

The app keeps the `SkillHub` directory name for compatibility. It writes changes atomically and refuses to overwrite invalid collection JSON. Imports merge entries by UUID and keep existing entries. Export your collection to back it up.

Preferences use macOS UserDefaults. The app does not sync data or make background network requests.

## Limits

- No automatic repository downloads or installation detection for collection entries. Removing a skill does not undo other files or settings created by its installer.
- Markdown previews block remote images and do not support embedded HTML, executable diagrams, syntax highlighting, or in-document anchors. Relative file links open in Finder.
- Local image previews have a 10 MB limit. Text previews have a 2 MB limit. Markdown over 128 KB opens as source to avoid expensive rich-text layout.
- File trees stop at 12 levels and 500 entries per directory. They skip hidden files, `node_modules`, and Python caches.
- Metadata parsing supports common name and description fields, not arbitrary YAML.

## Build from source

Requires macOS 13 or later and Xcode Command Line Tools with Swift 5.9 or later.

```sh
git clone https://github.com/michaelmjhhhh/agent-skill-manager.git
cd agent-skill-manager
./scripts/build-app.sh
open "dist/Agent Skill Manager.app"
```

The first build downloads dependencies pinned in `Package.resolved`. The script builds an ad-hoc signed app for your Mac's architecture.

Use `swift run` during development and `swift test` to run tests. You can also open `Package.swift` in Xcode.

To build a universal DMG for both Apple silicon and Intel, install full Xcode and run:

```sh
VERSION=0.2.0 ./scripts/build-dmg.sh
```

To measure process launch to the first visible window on a logged-in Mac:

```sh
swift scripts/measure-launch.swift "dist/Agent Skill Manager.app/Contents/MacOS/SkillHub"
```

The script starts and closes three app instances. It does not measure downloaded-app security checks or when all skill previews finish loading.

## Releases

See [CHANGELOG.md](CHANGELOG.md) for release history and unreleased changes. Add user-facing changes under `Unreleased` with each change. Before tagging, move those entries into a new version section, add its release date, and update the comparison links. Keep an empty `Unreleased` section for the next changes.

The release workflow uses the matching version section for its notes and fails if that section is missing or empty.

Pull requests and pushes to `main` run tests and build a universal DMG. GitHub Actions saves the DMG and checksum as workflow artifacts.

To publish a reviewed commit on `main`, tag it with a new version:

```sh
git tag v0.2.0
git push origin v0.2.0
```

Tags must use `vX.Y.Z`. The workflow puts that version in the app and DMG filename, then publishes a GitHub Release after tests and packaging pass. Releases include the DMG, checksum, and install instructions. No signing secrets are configured.

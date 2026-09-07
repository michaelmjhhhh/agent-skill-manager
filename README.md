# Agent Skill Manager

Browse installed agent skills on macOS. Keep skill links and install commands in a separate collection.

The app reads `~/.agents/skills` and `~/.claude/skills` by default. Change either path in Settings. No account required.

## Install

Requires macOS 13 or later on Apple silicon or Intel.

Download the universal `.dmg` from [Releases](https://github.com/michaelmjhhhh/agent-skill-manager/releases). Open it and drag Agent Skill Manager into Applications.

The app is ad-hoc signed but not notarized by Apple. If macOS blocks it, try opening it once, then go to System Settings > Privacy & Security > Open Anyway.

For a download you trust, you can also remove quarantine from this app:

```sh
xattr -dr com.apple.quarantine "/Applications/Agent Skill Manager.app"
```

This removes the app's downloaded-file protection. It does not notarize the app or disable Gatekeeper for other apps.

Each release includes a SHA-256 checksum. Run this in the folder containing the DMG and checksum file. Replace `X.Y.Z` with the release version:

```sh
shasum -a 256 -c Agent-Skill-Manager-X.Y.Z-universal.dmg.sha256
```

## Browse and save skills

- Search installed skills, browse their files, and preview Markdown or source code.
- Save links, descriptions, categories, favorites, and install commands in a separate collection.
- Search, filter, and sort the collection. Import or export it as JSON.
- Choose system, light, or dark appearance.

Press ⌘R to refresh or ⌘N to add a collection entry. The app refreshes installed skills when it becomes active, but skips repeated automatic scans within three seconds. Manual refresh always scans again.

## Run install commands

Choose a working folder and terminal for a saved command. The app can run commands in Terminal, iTerm2, or Ghostty 1.3 or later.

Review each command before confirming. It runs with your user permissions in a new terminal session. The app does not retry commands or check whether installation finished. Refresh the library afterward.

macOS may ask for Automation permission. If you deny it, you can enable it in System Settings > Privacy & Security > Automation. Ghostty also needs `macos-applescript` enabled, which is its default.

For other terminals, use "Copy command & open". This copies the command and opens your terminal. It does not paste or run anything.

## Remove installed skills

Use "Remove" in the installed skill view to move a skill to Trash. Check the path in the confirmation before proceeding.

- For a skill folder, removal includes the whole folder, even if you selected a nested document.
- For a standalone Markdown skill, removal includes only that file.
- For a symbolic link, only the link moves to Trash. Its target stays in place.

You can restore removed skills from Trash. Removing an installed skill keeps its collection entry. Removing a collection entry does not uninstall the skill.

The app checks that the entry is a direct child of the configured skills folder and that its filesystem identity has not changed since confirmation. It refuses to remove the source root, your home directory, or outside paths. If moving to Trash fails, the app does not try permanent deletion.

These checks cannot prevent another process from changing filesystem paths during the final Trash operation.

## Stored data

Collection entries live in:

```text
~/Library/Application Support/SkillHub/collection.json
```

The app keeps the `SkillHub` directory name for compatibility. It writes changes atomically and refuses to overwrite invalid collection JSON.

Imports merge entries by UUID. If an entry already exists, the app keeps the existing entry. Export your collection to back it up.

Preferences use macOS UserDefaults. The app does not sync data or make background network requests.

## Limits

- Collection entries do not trigger repository downloads or detect installations. Removing a skill does not undo other files or settings created by its installer.
- Markdown previews block remote images. They do not support embedded HTML, executable diagrams, syntax highlighting, or in-document anchors. Relative file links open in Finder.
- Local image previews have a 10 MB limit. Text previews have a 2 MB limit. Markdown over 128 KB opens as source to avoid slow rich-text layout.
- File trees stop at 12 levels and 500 entries per directory. They skip hidden files, `node_modules`, and Python caches.
- Metadata parsing supports common name and description fields, not arbitrary YAML.

## Build from source

The app uses SwiftUI, AppKit, and MarkdownUI. Building requires macOS 13 or later and Xcode Command Line Tools with Swift 5.9 or later.

```sh
git clone https://github.com/michaelmjhhhh/agent-skill-manager.git
cd agent-skill-manager
./scripts/build-app.sh
open "dist/Agent Skill Manager.app"
```

The first build downloads dependencies pinned in `Package.resolved`. The script builds an ad-hoc signed app for your Mac's architecture.

Use `swift run` during development and `swift test` to run tests. You can also open `Package.swift` in Xcode.

To build a universal DMG for Apple silicon and Intel, install full Xcode and run:

```sh
VERSION=0.2.0 ./scripts/build-dmg.sh
```

### Refresh and preview caching

Each refresh scans shared skill folders once, even when both sources link to them. Previews cache text and parsed Markdown for up to 32 documents, with an 8 MB source-text budget. Parsed Markdown uses additional memory.

The app checks file attributes before reusing a cached document. It reads the collection after opening the window.

### Measure launch time

Run this on a logged-in Mac to measure process launch to the first visible window:

```sh
swift scripts/measure-launch.swift "dist/Agent Skill Manager.app/Contents/MacOS/SkillHub"
```

The script starts and closes three app instances. It does not measure downloaded-app security checks or the time to finish loading all skill previews.

## Releases

[CHANGELOG.md](CHANGELOG.md) lists released and unreleased changes. Add user-facing changes under `Unreleased`.

Before tagging a release:

1. Move the unreleased entries into a new version section.
2. Add the release date and update the comparison links.
3. Leave an empty `Unreleased` section for the next changes.

The release workflow takes its notes from the matching version section. It fails if that section is missing or empty.

Pull requests and pushes to `main` run tests and build a universal DMG. GitHub Actions saves the DMG and checksum as workflow artifacts.

To publish a reviewed commit on `main`, tag it with a new version:

```sh
git tag v0.2.0
git push origin v0.2.0
```

Tags must use `vX.Y.Z`. The workflow puts that version in the app and DMG filename. After tests and packaging pass, it publishes a GitHub Release with the DMG, checksum, and install instructions. No signing secrets are configured.

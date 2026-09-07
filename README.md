# Agent Skill Manager

A macOS app to browse installed agent skills, preview their files, and save skill links and install commands.

Reads `~/.agents/skills` and `~/.claude/skills`. Change either path in Settings.

## Install

Requires macOS 13 or later on Apple silicon or Intel.

Download the `.dmg` from [Releases](https://github.com/michaelmjhhhh/agent-skill-manager/releases), open it, and drag Agent Skill Manager into Applications.

The app is ad-hoc signed, not notarized by Apple. If macOS blocks a download you trust, try opening it once, then go to System Settings > Privacy & Security > Open Anyway.

## Use

- Search installed skills and preview Markdown or source files.
- Save links, descriptions, categories, favorites, and install commands in a separate collection.
- Import or export the collection as JSON.
- Press ⌘R to refresh or ⌘N to add a collection entry.

### Install commands

Choose a working folder and Terminal, iTerm2, or Ghostty 1.3 or later. Review the command before confirming. It runs with your user permissions. The app does not check whether installation succeeded. Refresh afterward.

Allow Automation access if macOS asks. Ghostty needs `macos-applescript` enabled. Other terminals use "Copy command & open", which does not paste or run the command.

### Removal

"Remove" moves the whole skill folder to Trash, even when you select a nested file. Standalone Markdown skills remove only that file. Symbolic links remove only the link, not its target.

Removing an installed skill keeps its collection entry. Removing a collection entry does not uninstall the skill. Removal does not undo other files or settings created by an installer.

## Data

The app stores your collection locally in `~/Library/Application Support/SkillHub/collection.json`. Export it as JSON to back it up. Imports keep existing entries with the same UUID.

The app does not sync data or make background network requests.

## Preview limits

Markdown previews do not support remote images, embedded HTML, executable diagrams, syntax highlighting, or in-document anchors. Relative file links open in Finder.

Text previews have a 2 MB limit, and local images have a 10 MB limit. Markdown over 128 KB opens as source.

## Build

Requires Xcode Command Line Tools with Swift 5.9 or later.

```sh
git clone https://github.com/michaelmjhhhh/agent-skill-manager.git
cd agent-skill-manager
./scripts/build-app.sh
open "dist/Agent Skill Manager.app"
```

Use `swift run` during development and `swift test` to run tests.

See [CHANGELOG.md](CHANGELOG.md) for release history.

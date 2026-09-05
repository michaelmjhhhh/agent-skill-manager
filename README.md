# Skill Hub

A native macOS app for browsing installed agent skills and managing a local skill collection. Built with SwiftUI and AppKit, with MarkdownUI for native Markdown previews.

The app reads `~/.agents/skills` and `~/.claude/skills`. Collection entries are stored separately from installed skills. No account is required, and the app does not make background network requests.

## Run

Requires macOS 13+ and Xcode Command Line Tools with Swift 5.9+.

```sh
git clone https://github.com/michaelmjhhhh/agent-skill-hub.git
cd agent-skill-hub
./scripts/build-app.sh
open "dist/Skill Hub.app"
```

The first build downloads Swift package dependencies. `Package.resolved` records their versions.

Drag `dist/Skill Hub.app` into Applications if desired. The build script creates an ad-hoc signed app for your current architecture. Distribution to other Macs would require Developer ID signing and notarization.

For development: `swift run`. Tests: `swift test`. Open `Package.swift` in Xcode to develop there.

## Features

- Browse `~/.agents/skills` and `~/.claude/skills`, with configurable locations in Settings.
- Find installed skills by name or description, expand consistently aligned nested file trees, read Markdown or source, copy content, and reveal documents in Finder.
- Native Markdown supports tables, nested/ordered/task lists, blockquotes, inline formatting, local images, and fenced code with copy buttons. Relative file links reveal their targets in Finder rather than executing them.
- Supports standalone Markdown files, skill bundles, nested subskills, and symlinked directories; prevents recursive symlink loops.
- Manually curate a separate collection with name, source URL, description, category, installation command, and favorite flag.
- Search, filter by category/favorites, sort by name or newest, edit, remove, and import/export JSON.
- Organized collection cards with category badges, compact source links, two-line command previews, and a separate action row. Empty or placeholder commands such as `N/A` disable installation.
- Minimal Settings page and consistent collection toolbar controls. All app scroll views use native auto-fading overlay scrollbars instead of persistent tracks, without changing your system preferences.
- Save an installed skill to your collection using its bookmark button, then add its source and command manually.
- Choose an installed terminal `.app` from Applications in Settings. Its name, icon, and path are shown, and the selection is saved. Existing Terminal/iTerm preferences remain supported.
- Run a saved command after confirmation using native AppleScript integration with Terminal, iTerm2, or Ghostty 1.3+. Each execution opens a new session in your home directory. No temporary installation script is created. Other terminals use **Copy command & open** for manual execution.
- System, light, and dark appearance; collapsible sidebar; rounded panels and controls.
- Refresh with ⌘R. Skills also refresh when the app becomes active. ⌘N adds a bookmark while viewing Collection.

## Data and safety

Installed skills are read-only. Removing a collection entry does not uninstall a skill.

Collection data is stored at:

```
~/Library/Application Support/SkillHub/collection.json
```

Changes are written atomically. Invalid existing collection JSON is not overwritten. Import merges by UUID, keeping existing entries. Export periodically for backups. Preferences are stored with macOS UserDefaults.

Direct installation uses the selected terminal's AppleScript API and runs with your user permissions. The command is passed as an argument, not inserted into AppleScript source. macOS may request Automation permission; if denied, enable it in **System Settings > Privacy & Security > Automation**, or use **Copy command & open**. Ghostty also needs its `macos-applescript` setting enabled (the default).

**Copy command & open** only copies the command and opens the chosen app; it does not paste or execute anything. Inspect commands and trust their source before running them. Commands are never automatically retried. Installation completion is not tracked; refresh the library afterward.

## Limitations

Markdown uses MarkdownUI's GitHub-flavored parser and native SwiftUI rendering. Embedded HTML, executable diagrams, syntax highlighting, and in-document anchor navigation are not provided. Remote images stay blocked; local image previews are limited to 10 MB. YAML metadata parsing covers common scalar and multiline name/description fields, not arbitrary YAML. Text previews are limited to 2 MB; file trees are bounded to 12 levels and 500 entries per directory, excluding hidden files, node_modules, and Python caches. There is no automatic repository fetching, installation detection for bookmarks, uninstalling, or cloud sync.

## Verification

Twenty-one automated tests cover metadata, nested bundles, standalone Markdown, symlink traversal/cycles, missing directories, collection persistence/corruption, stable tree indentation, frontmatter handling, rich Markdown parsing, native Markdown layout, compact source labels, placeholder commands, consistent card layout in light/dark modes, nested overlay scrollbar configuration, collection toolbar sizing, terminal selection compatibility, application bundle validation, terminal driver selection, command argument isolation, and AppleScript compilation against installed Terminal and Ghostty dictionaries. Debug and release builds verified locally. The app was launched successfully; full-window screenshot capture was unavailable in the build session. Real installation commands were deliberately not executed during testing.

# Skill Hub

A local-first native macOS skill browser and personal collection, built with SwiftUI and AppKit. MarkdownUI provides native GitHub-flavored Markdown rendering (no WebView). No account or background network requests; remote Markdown images are not loaded. The first build downloads Swift package dependencies.

## Run

Requires macOS 13+ and Xcode Command Line Tools with Swift 5.9+.

```sh
./scripts/build-app.sh
open "dist/Skill Hub.app"
```

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
- Minimal Settings page with a pane-width native scrollbar that follows macOS visibility preferences.
- Save an installed skill to your collection using its bookmark button, then add its source and command manually.
- Run a saved command in Terminal or iTerm2 only after explicit confirmation. Copy-only is also available.
- System, light, and dark appearance; collapsible sidebar; rounded panels and controls.
- Refresh with ⌘R. Skills also refresh when the app becomes active. ⌘N adds a bookmark while viewing Collection.

## Data and safety

Installed skills are read-only. Removing a collection entry does not uninstall a skill.

Collection data lives at:

```
~/Library/Application Support/SkillHub/collection.json
```

Changes are written atomically. Invalid existing collection JSON is not overwritten. Import merges by UUID, keeping existing entries. Export periodically for backups. Preferences are stored with macOS UserDefaults.

Installation commands run as your user in your home directory, in a visible terminal. Inspect commands and trust their source before running them. The app writes a private executable `.command` file to a unique system temporary directory and opens it with your selected terminal. Those files remain until system temporary-file cleanup. Installation completion is not tracked; refresh the library afterward.

## MVP boundaries

Markdown uses MarkdownUI's GitHub-flavored parser and native SwiftUI rendering. Embedded HTML, executable diagrams, syntax highlighting, and in-document anchor navigation are not provided. Remote images stay blocked; local image previews are limited to 10 MB. YAML metadata parsing covers common scalar and multiline name/description fields, not arbitrary YAML. Text previews are limited to 2 MB; file trees are bounded to 12 levels and 500 entries per directory, excluding hidden files, node_modules, and Python caches. There is no automatic repository fetching, installation detection for bookmarks, uninstalling, or cloud sync.

## Verification

Twelve automated tests cover metadata, nested bundles, standalone Markdown, symlink traversal/cycles, missing directories, collection persistence/corruption, stable tree indentation, frontmatter handling, rich Markdown parsing, native Markdown layout, compact source labels, placeholder commands, and consistent card layout in light/dark modes. Debug and release builds verified locally. The app was launched successfully; full-window screenshot capture was unavailable in the build session. Real installation commands were deliberately not executed during testing.

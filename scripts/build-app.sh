#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/Agent Skill Manager.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SkillHub" "$APP/Contents/MacOS/SkillHub"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Agent Skill Manager</string>
<key>CFBundleDisplayName</key><string>Agent Skill Manager</string>
<key>CFBundleIdentifier</key><string>local.skillhub.app</string>
<key>CFBundleExecutable</key><string>SkillHub</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Agent Skill Manager sends installation commands you confirm to a new session in your selected terminal.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
printf '\nBuilt: %s\n' "$APP"

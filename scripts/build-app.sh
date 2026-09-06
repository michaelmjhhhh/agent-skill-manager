#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/Agent Skill Manager.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SkillHub" "$APP/Contents/MacOS/SkillHub"

# Build the native macOS icon from the checked-in artwork.
ICONSET="$APP/Contents/Resources/AppIcon.iconset"
rm -rf "$ICONSET" "$APP/Contents/Resources/AppIcon.icns"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Agent Skill Manager</string>
<key>CFBundleDisplayName</key><string>Agent Skill Manager</string>
<key>CFBundleIdentifier</key><string>local.skillhub.app</string>
<key>CFBundleExecutable</key><string>SkillHub</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
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

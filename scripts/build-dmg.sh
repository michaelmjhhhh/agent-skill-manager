#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export VERSION="${VERSION:-0.1.0}"
export UNIVERSAL=1
./scripts/build-app.sh
APP="$PWD/dist/Agent Skill Manager.app"
lipo "$APP/Contents/MacOS/SkillHub" -verify_arch arm64 x86_64
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Agent Skill Manager.app"
ln -s /Applications "$STAGING/Applications"
DMG="dist/Agent-Skill-Manager-${VERSION}-universal.dmg"
hdiutil create -volname "Agent Skill Manager" -srcfolder "$STAGING" -format UDZO -ov "$DMG"
hdiutil verify "$DMG"
(cd dist && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
printf '\nBuilt: %s\n' "$DMG"

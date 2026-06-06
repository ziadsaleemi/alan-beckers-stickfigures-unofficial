#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Alan Beckers Stickfigures"
DMG_NAME="Alan-Beckers-Stickfigures-macOS.dmg"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$DIST_DIR/build"
DMG_ROOT="$BUILD_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "DMG packaging must run on macOS." >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required to build the DMG." >&2
  exit 1
fi

APP_BUNDLE="$("$ROOT_DIR/script/build_macos_app.sh")"

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

hdiutil verify "$DMG_PATH" >/dev/null

echo "$DMG_PATH"

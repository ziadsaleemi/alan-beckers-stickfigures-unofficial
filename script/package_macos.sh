#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Alan Beckers Stickfigures"
DMG_NAME="Alan-Beckers-Stickfigures-macOS.dmg"
MACOS_CODESIGN_IDENTITY="${MACOS_CODESIGN_IDENTITY:--}"
MACOS_REQUIRE_NOTARIZATION="${MACOS_REQUIRE_NOTARIZATION:-0}"
MACOS_NOTARIZE="${MACOS_NOTARIZE:-$MACOS_REQUIRE_NOTARIZATION}"

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

if [ "$MACOS_NOTARIZE" = "1" ]; then
  if [ "$MACOS_CODESIGN_IDENTITY" = "-" ]; then
    echo "Notarization requires MACOS_CODESIGN_IDENTITY to be a Developer ID Application identity." >&2
    exit 1
  fi

  HAS_NOTARY_API_KEY=0
  if [ -n "${MACOS_NOTARY_KEY_ID:-}" ] && [ -n "${MACOS_NOTARY_ISSUER_ID:-}" ] && [ -n "${MACOS_NOTARY_KEY_PATH:-}" ]; then
    HAS_NOTARY_API_KEY=1
  fi

  HAS_NOTARY_APPLE_ID=0
  if [ -n "${MACOS_NOTARY_APPLE_ID:-}" ] && [ -n "${MACOS_NOTARY_TEAM_ID:-}" ] && [ -n "${MACOS_NOTARY_PASSWORD:-}" ]; then
    HAS_NOTARY_APPLE_ID=1
  fi

  if [ "$HAS_NOTARY_API_KEY" = "0" ] && [ "$HAS_NOTARY_APPLE_ID" = "0" ]; then
    echo "Notarization requires either Team API key secrets MACOS_NOTARY_KEY_ID, MACOS_NOTARY_ISSUER_ID, and MACOS_NOTARY_KEY_PATH; or MACOS_NOTARY_APPLE_ID, MACOS_NOTARY_TEAM_ID, and MACOS_NOTARY_PASSWORD." >&2
    exit 1
  fi
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

if [ "$MACOS_CODESIGN_IDENTITY" != "-" ]; then
  codesign --force --timestamp --sign "$MACOS_CODESIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [ "$MACOS_NOTARIZE" = "1" ]; then
  if [ "${HAS_NOTARY_API_KEY:-0}" = "1" ]; then
    NOTARY_ARGS=(
      "$DMG_PATH"
      --key "$MACOS_NOTARY_KEY_PATH"
      --key-id "$MACOS_NOTARY_KEY_ID"
      --issuer "$MACOS_NOTARY_ISSUER_ID"
    )
    NOTARY_ARGS+=(--wait)
    xcrun notarytool submit "${NOTARY_ARGS[@]}"
  else
    xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$MACOS_NOTARY_APPLE_ID" \
      --team-id "$MACOS_NOTARY_TEAM_ID" \
      --password "$MACOS_NOTARY_PASSWORD" \
      --wait
  fi
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

echo "$DMG_PATH"

#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Alan Beckers Stickfigures"
BUNDLE_ID="${MACOS_BUNDLE_ID:-com.skittlq.alanbeckersstickfigures.unofficial}"
MIN_SYSTEM_VERSION="13.0"
APP_VERSION="${APP_VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MACOS_CODESIGN_IDENTITY="${MACOS_CODESIGN_IDENTITY:--}"
MACOS_CODESIGN_ENTITLEMENTS="${MACOS_CODESIGN_ENTITLEMENTS:-}"
MACOS_PROVISIONING_PROFILE="${MACOS_PROVISIONING_PROFILE:-}"
MACOS_REQUIRE_NOTARIZATION="${MACOS_REQUIRE_NOTARIZATION:-0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$DIST_DIR/build"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
STICKFIGURES_DIR="$RESOURCES_DIR/Stickfigures"
APP_BINARY="$MACOS_DIR/$APP_NAME"
SOURCE_FILE="$ROOT_DIR/macos/AlanBeckersStickfiguresLauncher/main.swift"
ICON_SOURCE="$ROOT_DIR/repository-images/icon-xl.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macOS packaging must run on macOS." >&2
  exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc is required to build the macOS app wrapper." >&2
  exit 1
fi

if [ "$MACOS_REQUIRE_NOTARIZATION" = "1" ] && [ "$MACOS_CODESIGN_IDENTITY" = "-" ]; then
  echo "MACOS_REQUIRE_NOTARIZATION=1 requires MACOS_CODESIGN_IDENTITY to be a Developer ID Application identity." >&2
  exit 1
fi

rm -rf "$APP_BUNDLE" "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$STICKFIGURES_DIR" "$BUILD_DIR"

compile_arch() {
  local arch="$1"
  local output="$BUILD_DIR/$APP_NAME-$arch"

  if ! MACOSX_DEPLOYMENT_TARGET="$MIN_SYSTEM_VERSION" swiftc \
    -swift-version 5 \
    -O \
    -parse-as-library \
    -framework Cocoa \
    -target "$arch-apple-macos$MIN_SYSTEM_VERSION" \
    "$SOURCE_FILE" \
    -o "$output"; then
    return 1
  fi

  printf '%s\n' "$output"
}

ARCH_BINARIES=()
for arch in arm64 x86_64; do
  if output="$(compile_arch "$arch")"; then
    ARCH_BINARIES+=("$output")
  else
    echo "warning: failed to compile $arch wrapper slice; continuing if another slice is available" >&2
  fi
done

if [ "${#ARCH_BINARIES[@]}" -eq 0 ]; then
  echo "failed to compile any macOS wrapper architecture" >&2
  exit 1
elif [ "${#ARCH_BINARIES[@]}" -eq 1 ]; then
  cp "${ARCH_BINARIES[0]}" "$APP_BINARY"
else
  /usr/bin/lipo -create "${ARCH_BINARIES[@]}" -output "$APP_BINARY"
fi

chmod +x "$APP_BINARY"

cp -R "$ROOT_DIR/conf" "$STICKFIGURES_DIR/conf"
cp -R "$ROOT_DIR/img" "$STICKFIGURES_DIR/img"

if [ -n "$MACOS_PROVISIONING_PROFILE" ]; then
  if [ ! -f "$MACOS_PROVISIONING_PROFILE" ]; then
    echo "MACOS_PROVISIONING_PROFILE does not exist: $MACOS_PROVISIONING_PROFILE" >&2
    exit 1
  fi
  cp "$MACOS_PROVISIONING_PROFILE" "$CONTENTS_DIR/embedded.provisionprofile"
fi

cat >"$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' >"$CONTENTS_DIR/PkgInfo"

if [ -f "$ICON_SOURCE" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
  mkdir -p "$ICONSET_DIR"
  for size in 16 32 128 256 512; do
    tmp_icon="$BUILD_DIR/icon-${size}.png"
    sips -Z "$size" "$ICON_SOURCE" --out "$tmp_icon" >/dev/null 2>&1
    sips -p "$size" "$size" --padColor FFFFFF "$tmp_icon" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null 2>&1

    double_size=$((size * 2))
    tmp_icon_2x="$BUILD_DIR/icon-${double_size}.png"
    sips -Z "$double_size" "$ICON_SOURCE" --out "$tmp_icon_2x" >/dev/null 2>&1
    sips -p "$double_size" "$double_size" --padColor FFFFFF "$tmp_icon_2x" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null 2>&1
  done
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
fi

plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null

if command -v codesign >/dev/null 2>&1; then
  CODESIGN_ARGS=(--force --deep --sign "$MACOS_CODESIGN_IDENTITY")
  if [ "$MACOS_CODESIGN_IDENTITY" != "-" ]; then
    CODESIGN_ARGS+=(--options runtime --timestamp)
    if [ -n "$MACOS_CODESIGN_ENTITLEMENTS" ]; then
      CODESIGN_ARGS+=(--entitlements "$MACOS_CODESIGN_ENTITLEMENTS")
    fi
  fi

  codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE" 2>&1 | sed '/replacing existing signature/d'
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
elif [ "$MACOS_REQUIRE_NOTARIZATION" = "1" ]; then
  echo "codesign is required for notarized release builds." >&2
  exit 1
fi

echo "$APP_BUNDLE"

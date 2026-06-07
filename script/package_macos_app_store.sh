#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Alan Beckers Stickfigures"
PKG_NAME="Alan-Beckers-Stickfigures-Mac-App-Store.pkg"
MACOS_APP_STORE_CODESIGN_IDENTITY="${MACOS_APP_STORE_CODESIGN_IDENTITY:-}"
MACOS_APP_STORE_INSTALLER_IDENTITY="${MACOS_APP_STORE_INSTALLER_IDENTITY:-}"
MACOS_APP_STORE_PROVISIONING_PROFILE="${MACOS_APP_STORE_PROVISIONING_PROFILE:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PKG_PATH="$DIST_DIR/$PKG_NAME"
ENTITLEMENTS_PATH="$ROOT_DIR/macos/AppStore.entitlements"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Mac App Store packaging must run on macOS." >&2
  exit 1
fi

if ! command -v productbuild >/dev/null 2>&1; then
  echo "productbuild is required to build the Mac App Store package." >&2
  exit 1
fi

if [ -z "$MACOS_APP_STORE_CODESIGN_IDENTITY" ]; then
  echo "Set MACOS_APP_STORE_CODESIGN_IDENTITY to an Apple Distribution or 3rd Party Mac Developer Application identity." >&2
  exit 1
fi

if [ -z "$MACOS_APP_STORE_INSTALLER_IDENTITY" ]; then
  echo "Set MACOS_APP_STORE_INSTALLER_IDENTITY to a 3rd Party Mac Developer Installer identity." >&2
  exit 1
fi

if [ -z "$MACOS_APP_STORE_PROVISIONING_PROFILE" ] || [ ! -f "$MACOS_APP_STORE_PROVISIONING_PROFILE" ]; then
  echo "Set MACOS_APP_STORE_PROVISIONING_PROFILE to a downloaded Mac App Store Connect provisioning profile." >&2
  exit 1
fi

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
  echo "Missing App Store entitlements: $ENTITLEMENTS_PATH" >&2
  exit 1
fi

APP_BUNDLE="$(
  MACOS_CODESIGN_IDENTITY="$MACOS_APP_STORE_CODESIGN_IDENTITY" \
  MACOS_CODESIGN_ENTITLEMENTS="$ENTITLEMENTS_PATH" \
  MACOS_PROVISIONING_PROFILE="$MACOS_APP_STORE_PROVISIONING_PROFILE" \
  MACOS_REQUIRE_NOTARIZATION=0 \
  "$ROOT_DIR/script/build_macos_app.sh"
)"

rm -f "$PKG_PATH"
COPYFILE_DISABLE=1 productbuild \
  --sign "$MACOS_APP_STORE_INSTALLER_IDENTITY" \
  --component "$APP_BUNDLE" \
  /Applications \
  "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH"
cat <<'NOTICE'
Note: this Mac App Store package is for App Store Connect upload only.
It is not a local test installer; macOS may refuse to launch the installed app
outside the App Store provisioning/receipt flow. Use script/package_macos.sh for
a locally runnable direct-download DMG.
NOTICE
echo "$PKG_PATH"

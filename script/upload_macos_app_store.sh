#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${MACOS_BUNDLE_ID:-com.skittlq.alanbeckersstickfigures.unofficial}"
APP_VERSION="${APP_VERSION:-1.0.1}"
BUILD_NUMBER="${BUILD_NUMBER:-3}"
PKG_PATH="${MACOS_APP_STORE_PKG_PATH:-}"
APPLE_ID="${MACOS_APP_STORE_APPLE_ID:-}"
API_KEY_ID="${MACOS_APP_STORE_API_KEY_ID:-${MACOS_NOTARY_KEY_ID:-}}"
API_ISSUER_ID="${MACOS_APP_STORE_API_ISSUER_ID:-${MACOS_NOTARY_ISSUER_ID:-}}"
API_KEY_PATH="${MACOS_APP_STORE_API_KEY_PATH:-${MACOS_NOTARY_KEY_PATH:-}}"
PROVIDER_PUBLIC_ID="${MACOS_APP_STORE_PROVIDER_PUBLIC_ID:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "$PKG_PATH" ]; then
  PKG_PATH="$ROOT_DIR/dist/Alan-Beckers-Stickfigures-Mac-App-Store.pkg"
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Mac App Store upload must run on macOS." >&2
  exit 1
fi

if [ ! -f "$PKG_PATH" ]; then
  echo "Mac App Store package does not exist: $PKG_PATH" >&2
  exit 1
fi

if [ -z "$APPLE_ID" ]; then
  echo "Set MACOS_APP_STORE_APPLE_ID to the numeric Apple ID from the App Store Connect app record." >&2
  exit 1
fi

if [ -z "$API_KEY_ID" ] || [ -z "$API_ISSUER_ID" ] || [ -z "$API_KEY_PATH" ]; then
  echo "Set MACOS_APP_STORE_API_KEY_ID, MACOS_APP_STORE_API_ISSUER_ID, and MACOS_APP_STORE_API_KEY_PATH." >&2
  exit 1
fi

UPLOAD_ARGS=(
  --upload-package "$PKG_PATH"
  --platform macos
  --apple-id "$APPLE_ID"
  --bundle-id "$BUNDLE_ID"
  --bundle-short-version-string "$APP_VERSION"
  --bundle-version "$BUILD_NUMBER"
  --api-key "$API_KEY_ID"
  --api-issuer "$API_ISSUER_ID"
  --p8-file-path "$API_KEY_PATH"
  --wait
)

if [ -n "$PROVIDER_PUBLIC_ID" ]; then
  UPLOAD_ARGS+=(--provider-public-id "$PROVIDER_PUBLIC_ID")
fi

xcrun altool "${UPLOAD_ARGS[@]}"

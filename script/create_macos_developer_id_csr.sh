#!/usr/bin/env bash
set -euo pipefail

SIGNING_DIR="${SIGNING_DIR:-$HOME/Downloads/AlanBeckersStickfiguresSigning}"
ACCOUNT_EMAIL="${APPLE_DEVELOPER_EMAIL:-$(git config user.email 2>/dev/null || true)}"
COMMON_NAME="${MACOS_CERT_COMMON_NAME:-Alan Beckers Stickfigures Developer ID}"
KEY_PATH="$SIGNING_DIR/developer-id-private-key.pem"
CSR_PATH="$SIGNING_DIR/DeveloperIDApplication.certSigningRequest"

if [ -z "$ACCOUNT_EMAIL" ]; then
  echo "Set APPLE_DEVELOPER_EMAIL to the email address for your Apple Developer account." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required to create the certificate signing request." >&2
  exit 1
fi

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"

if [ -e "$KEY_PATH" ] || [ -e "$CSR_PATH" ]; then
  echo "Refusing to overwrite existing signing files in $SIGNING_DIR." >&2
  echo "Move the existing files first, or set SIGNING_DIR to a new directory." >&2
  exit 1
fi

openssl genrsa -out "$KEY_PATH" 2048 >/dev/null 2>&1
chmod 600 "$KEY_PATH"
openssl req \
  -new \
  -key "$KEY_PATH" \
  -out "$CSR_PATH" \
  -subj "/emailAddress=$ACCOUNT_EMAIL,CN=$COMMON_NAME"

echo "Created Developer ID CSR:"
echo "$CSR_PATH"
echo
echo "Private key saved at:"
echo "$KEY_PATH"
echo
echo "Upload the CSR at Apple Developer > Certificates, Identifiers & Profiles > Certificates > + > Developer ID > Developer ID Application."
echo "After downloading the .cer file from Apple, run script/configure_macos_developer_id_certificate.sh."

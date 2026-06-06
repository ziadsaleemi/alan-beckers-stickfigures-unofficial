#!/usr/bin/env bash
set -euo pipefail

SIGNING_DIR="${SIGNING_DIR:-$HOME/Downloads/AlanBeckersStickfiguresSigning}"
CERT_PATH="${DEVELOPER_ID_CERT_PATH:-}"
KEY_PATH="${DEVELOPER_ID_KEY_PATH:-$SIGNING_DIR/developer-id-private-key.pem}"
CERT_PEM_PATH="$SIGNING_DIR/developer-id-certificate.pem"
P12_PATH="$SIGNING_DIR/DeveloperIDApplication.p12"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
P12_PASSWORD="${MACOS_CERTIFICATE_PASSWORD:-}"
IMPORT_TO_KEYCHAIN="${IMPORT_TO_KEYCHAIN:-1}"
SKIP_GH_SECRETS="${SKIP_GH_SECRETS:-0}"

if [ -z "$CERT_PATH" ]; then
  CERT_PATH="$(find "$HOME/Downloads" "$SIGNING_DIR" -maxdepth 1 -type f \( -iname '*.cer' -o -iname '*.der' \) -print 2>/dev/null | while read -r candidate; do
    subject="$(openssl x509 -inform DER -in "$candidate" -noout -subject -nameopt RFC2253 2>/dev/null || openssl x509 -in "$candidate" -noout -subject -nameopt RFC2253 2>/dev/null || true)"
    case "$subject" in
      *"CN=Developer ID Application:"*) printf '%s\n' "$candidate" ;;
    esac
  done | sort | tail -1)"
fi

if [ -z "$CERT_PATH" ] || [ ! -f "$CERT_PATH" ]; then
  echo "Set DEVELOPER_ID_CERT_PATH to the downloaded Developer ID Application .cer file." >&2
  exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
  echo "Missing private key at $KEY_PATH." >&2
  echo "Run script/create_macos_developer_id_csr.sh first, then create/download the certificate from Apple using that CSR." >&2
  exit 1
fi

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"

if ! openssl x509 -inform DER -in "$CERT_PATH" -out "$CERT_PEM_PATH" 2>/dev/null; then
  openssl x509 -in "$CERT_PATH" -out "$CERT_PEM_PATH"
fi
chmod 600 "$CERT_PEM_PATH"

subject="$(openssl x509 -in "$CERT_PEM_PATH" -noout -subject -nameopt RFC2253)"
identity="$(printf '%s\n' "$subject" | sed -n 's/^subject=.*CN=\([^,]*\).*/\1/p')"

case "$identity" in
  "Developer ID Application:"*) ;;
  *)
    echo "Certificate is not a Developer ID Application certificate." >&2
    echo "$subject" >&2
    exit 1
    ;;
esac

if [ -z "$P12_PASSWORD" ]; then
  if [ -t 0 ]; then
    printf "Create a password for the exported .p12: " >&2
    stty -echo
    read -r P12_PASSWORD
    stty echo
    printf "\n" >&2
  else
    P12_PASSWORD="$(openssl rand -base64 32)"
  fi
fi

openssl pkcs12 \
  -export \
  -inkey "$KEY_PATH" \
  -in "$CERT_PEM_PATH" \
  -out "$P12_PATH" \
  -name "$identity" \
  -passout "pass:$P12_PASSWORD"
chmod 600 "$P12_PATH"

if [ "$IMPORT_TO_KEYCHAIN" = "1" ]; then
  security import "$P12_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$HOME/Library/Keychains/login.keychain-db" >/dev/null
  security find-identity -v -p codesigning | sed -n '/Developer ID Application/p'
fi

if [ "$SKIP_GH_SECRETS" != "1" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI is not installed. Skipping GitHub Secrets setup." >&2
  else
    if [ -z "$GITHUB_REPOSITORY" ]; then
      GITHUB_REPOSITORY="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
    fi
    if [ -z "$GITHUB_REPOSITORY" ]; then
      echo "Set GITHUB_REPOSITORY, for example ziadsaleemi/alan-beckers-stickfigures-unofficial." >&2
      exit 1
    fi

    base64 -i "$P12_PATH" | gh secret set MACOS_CERTIFICATE_P12 --repo "$GITHUB_REPOSITORY"
    printf '%s' "$P12_PASSWORD" | gh secret set MACOS_CERTIFICATE_PASSWORD --repo "$GITHUB_REPOSITORY"
    gh secret set MACOS_CODESIGN_IDENTITY --repo "$GITHUB_REPOSITORY" --body "$identity"
  fi
fi

echo "Configured Developer ID certificate:"
echo "$identity"
echo
echo "Exported .p12:"
echo "$P12_PATH"

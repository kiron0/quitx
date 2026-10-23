#!/usr/bin/env bash
set -euo pipefail

NAME="${1:-QuitX Code Signing}"
OUT="quitx-signing.p12"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ -e "$OUT" ]]; then
  echo "$OUT already exists. Move it away first so it isn't overwritten." >&2
  exit 1
fi

PASSWORD="$(openssl rand -base64 24)"

cat > "$WORK/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.cnf" 2>/dev/null

LEGACY=""
if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then LEGACY="-legacy"; fi
openssl pkcs12 -export $LEGACY -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$NAME" -out "$OUT" -passout "pass:$PASSWORD"

cat <<MSG

Created $OUT. Keep it private and never commit it.

Add these secrets in GitHub → Settings → Secrets and variables → Actions:

  MACOS_SIGNING_IDENTITY       $NAME
  MACOS_SIGNING_CERT_PASSWORD  $PASSWORD
  MACOS_SIGNING_CERT_P12       (the base64 text below)

$(base64 < "$OUT")

To sign local builds with the same identity, double-click $OUT to import it into your
login keychain, then run:  QUITX_CODESIGN_IDENTITY="$NAME" npm run build
MSG

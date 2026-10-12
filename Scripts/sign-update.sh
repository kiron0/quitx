#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: sign-update.sh <dmg-path> <version> <output-json>" >&2
    exit 1
fi

DMG_PATH="$1"
VERSION="$2"
OUT_PATH="$3"

if [ -z "${UPDATE_ED25519_PRIVATE_KEY:-}" ]; then
    echo "missing UPDATE_ED25519_PRIVATE_KEY" >&2
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo "DMG not found: $DMG_PATH" >&2
    exit 1
fi

find_openssl() {
    if [ -n "${OPENSSL:-}" ]; then
        echo "$OPENSSL"
        return 0
    fi
    local candidates=()
    if command -v brew >/dev/null 2>&1; then
        candidates+=("$(brew --prefix openssl@3 2>/dev/null || true)/bin/openssl")
        candidates+=("$(brew --prefix openssl 2>/dev/null || true)/bin/openssl")
    fi
    candidates+=(
        "/opt/homebrew/opt/openssl@3/bin/openssl"
        "/usr/local/opt/openssl@3/bin/openssl"
        "openssl"
    )
    local candidate
    for candidate in "${candidates[@]}"; do
        if [ -z "$candidate" ] || [ "$candidate" = "/bin/openssl" ]; then
            continue
        fi
        if [ -x "$candidate" ] || command -v "$candidate" >/dev/null 2>&1; then
            if "$candidate" pkeyutl -help 2>&1 | grep -q -- "-rawin"; then
                echo "$candidate"
                return 0
            fi
        fi
    done
    return 1
}

OPENSSL_BIN="$(find_openssl)" || {
    echo "OpenSSL 3 with Ed25519 support not found. Install with: brew install openssl@3" >&2
    exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SEED_HEX="$(printf '%s' "$UPDATE_ED25519_PRIVATE_KEY" | base64 -d | xxd -p -c 256 | tr -d '\n')"
if [ "${#SEED_HEX}" -ne 64 ]; then
    echo "UPDATE_ED25519_PRIVATE_KEY must decode to 32 raw bytes" >&2
    exit 1
fi

printf '%s' "302e020100300506032b657004220420${SEED_HEX}" | xxd -r -p > "$TMP_DIR/key.der"
"$OPENSSL_BIN" pkey -inform DER -in "$TMP_DIR/key.der" -out "$TMP_DIR/key.pem" >/dev/null 2>&1

"$OPENSSL_BIN" pkeyutl -sign -inkey "$TMP_DIR/key.pem" -rawin -in "$DMG_PATH" -out "$TMP_DIR/sig.bin" >/dev/null 2>&1

DIGEST_HEX="$("$OPENSSL_BIN" dgst -sha256 -r "$DMG_PATH" | awk '{print $1}')"
SIGNATURE_B64="$(base64 < "$TMP_DIR/sig.bin" | tr -d '\n')"
SIZE_BYTES="$(wc -c < "$DMG_PATH" | tr -d ' ')"
FILE_NAME="$(basename "$DMG_PATH")"

cat > "$OUT_PATH" <<EOF
{
  "version": "$VERSION",
  "digest": "sha256:$DIGEST_HEX",
  "edSignature": "$SIGNATURE_B64",
  "sizeBytes": $SIZE_BYTES,
  "fileName": "$FILE_NAME"
}
EOF

echo "wrote $OUT_PATH"

#!/usr/bin/env bash
set -euo pipefail

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

"$OPENSSL_BIN" genpkey -algorithm ed25519 -out "$TMP_DIR/private.pem" >/dev/null 2>&1

SEED_HEX="$("$OPENSSL_BIN" pkey -in "$TMP_DIR/private.pem" -outform DER | tail -c 32 | xxd -p -c 256 | tr -d '\n')"
PRIV_B64="$(printf '%s' "$SEED_HEX" | xxd -r -p | base64 | tr -d '\n')"

"$OPENSSL_BIN" pkey -in "$TMP_DIR/private.pem" -pubout -out "$TMP_DIR/public.pem" >/dev/null 2>&1
PUB_HEX="$("$OPENSSL_BIN" pkey -pubin -in "$TMP_DIR/public.pem" -outform DER | tail -c 32 | xxd -p -c 256 | tr -d '\n')"
PUB_B64="$(printf '%s' "$PUB_HEX" | xxd -r -p | base64 | tr -d '\n')"

echo "UPDATE_ED25519_PRIVATE_KEY=$PRIV_B64"
echo "compiledEdPublicKey=$PUB_B64"

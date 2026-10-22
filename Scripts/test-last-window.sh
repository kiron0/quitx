#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/QuitXLastWindowTest.XXXXXX")"
FIXTURE_PATH="$TEST_TEMP_DIR/QuitXLastWindowFixture"

cleanup() {
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf -- "$TEST_TEMP_DIR"
    fi
}
trap cleanup EXIT

cd "$ROOT_DIR"

echo "▶ Building last-window fixture..."
xcrun clang \
    -fobjc-arc \
    -framework AppKit \
    -framework Foundation \
    "$ROOT_DIR/Tests/Fixtures/LastWindowQuitFixture.m" \
    -o "$FIXTURE_PATH"

echo "▶ Running real WindowServer close-button test..."
export QUITX_LAST_WINDOW_FIXTURE="$FIXTURE_PATH"
set -o pipefail
swift test \
    --build-system native \
    --filter LastWindowQuitIntegrationTests \
    -Xswiftc -F \
    -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
    2>&1 | LC_ALL=C sed -E '/warning:.*build-system native.*deprecated/d'

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

echo "▶ Wrapping fixture as an app bundle for multi-instance tests..."
FIXTURE_APP="$TEST_TEMP_DIR/QuitXInstanceFixture.app"
mkdir -p "$FIXTURE_APP/Contents/MacOS"
cp "$FIXTURE_PATH" "$FIXTURE_APP/Contents/MacOS/QuitXInstanceFixture"
cat > "$FIXTURE_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>QuitXInstanceFixture</string>
    <key>CFBundleIdentifier</key><string>com.quitx.tests.instance-fixture</string>
    <key>CFBundleName</key><string>QuitX Instance Fixture</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$FIXTURE_APP" >/dev/null 2>&1 || true

echo "▶ Running real WindowServer close-button and multi-instance tests..."
export QUITX_LAST_WINDOW_FIXTURE="$FIXTURE_PATH"
export QUITX_INSTANCE_FIXTURE_APP="$FIXTURE_APP"
set -o pipefail
swift test \
    --build-system native \
    --filter "LastWindowQuitIntegrationTests|MultiInstanceIntegrationTests" \
    -Xswiftc -F \
    -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
    2>&1 | LC_ALL=C sed -E '/warning:.*build-system native.*deprecated/d'

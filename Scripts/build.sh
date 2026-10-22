#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="QuitX"
VERSION=$(awk -F'"' '/"version"/ { print $4; exit }' "$ROOT_DIR/package.json")
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

cd "$ROOT_DIR"

echo "▶ Building $APP_NAME (release)..."
swift build -c release --build-system native 2>&1 | sed '/warning:.*build-system native.*deprecated/d'

echo "▶ Packaging $APP_NAME.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Support/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT_DIR"/Support/Icons/*.png "$ROOT_DIR"/Support/Icons/*.icns "$RESOURCES_DIR"/ 2>/dev/null || true
cp "$ROOT_DIR"/Support/Sounds/*.aiff "$RESOURCES_DIR"/ 2>/dev/null || true
cp "$ROOT_DIR/Support/Assets.car" "$RESOURCES_DIR"/ 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true

# A stable designated requirement lets macOS recognize local ad-hoc rebuilds as
# updates of the same app, so privacy grants do not bind to a changing CDHash.
# Release builds should set QUITX_CODESIGN_IDENTITY to a Developer ID identity.
if [[ -n "${QUITX_CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --sign "$QUITX_CODESIGN_IDENTITY" "$APP_DIR"
else
    codesign \
        --force \
        --deep \
        --sign - \
        --requirements '=designated => identifier "io.coreify.quitx" and info[CFBundleIdentifier] = "io.coreify.quitx"' \
        "$APP_DIR"
fi
REQUIREMENT=$(codesign --display --requirements - "$APP_DIR" 2>&1 || true)
if ! grep -q 'designated => .*identifier "io.coreify.quitx"' <<<"$REQUIREMENT" || grep -q 'cdhash' <<<"$REQUIREMENT"; then
    echo "❌ Unstable designated requirement. macOS privacy grants would reset on every update:" >&2
    echo "$REQUIREMENT" >&2
    exit 1
fi
codesign --verify --strict --deep "$APP_DIR"
echo "✅ $APP_NAME.app ready: $APP_DIR"

if [[ "${1:-}" == "--run" ]]; then
    echo "▶ Launching $APP_NAME..."
    open "$APP_DIR"
fi

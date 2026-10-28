#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/QuitX.app}"
OUT_PATH="${2:-$ROOT_DIR/.build/QuitX.dmg}"
VOLUME_NAME="QuitX"
ASSETS_DIR="$ROOT_DIR/Support/DMG"
WORK_DIR="$ROOT_DIR/.build/dmg-work"
VENV_DIR="$ROOT_DIR/.build/dmgbuild-venv"

[[ -d "$APP_PATH" ]] || { echo "❌ App not found: $APP_PATH"; exit 1; }

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$(dirname "$OUT_PATH")"
rm -f "$OUT_PATH"

plain_dmg() {
    local stage="$WORK_DIR/stage"
    rm -rf "$stage"
    mkdir -p "$stage"
    cp -R "$APP_PATH" "$stage/"
    ln -s /Applications "$stage/Applications"
    hdiutil create -volname "$VOLUME_NAME" -srcfolder "$stage" -ov -format ULFO "$OUT_PATH"
}

BACKGROUND="$WORK_DIR/background.tiff"
if ! tiffutil -cathidpicheck "$ASSETS_DIR/background.png" "$ASSETS_DIR/background@2x.png" -out "$BACKGROUND" >/dev/null 2>&1; then
    BACKGROUND="$WORK_DIR/background.png"
    cp "$ASSETS_DIR/background.png" "$BACKGROUND"
fi

if [[ ! -x "$VENV_DIR/bin/dmgbuild" ]]; then
    rm -rf "$VENV_DIR"
    if python3 -m venv "$VENV_DIR" >/dev/null 2>&1; then
        "$VENV_DIR/bin/pip" install --quiet --disable-pip-version-check "dmgbuild>=1.6,<2" >/dev/null 2>&1 || true
    fi
fi

if [[ -x "$VENV_DIR/bin/dmgbuild" ]] && "$VENV_DIR/bin/dmgbuild" \
    -s "$ASSETS_DIR/dmg-settings.py" \
    -D app="$APP_PATH" \
    -D background="$BACKGROUND" \
    -D icon="$ROOT_DIR/Support/Icons/AppIcon.icns" \
    "$VOLUME_NAME" "$OUT_PATH"; then
    echo "✅ Styled DMG ready: $OUT_PATH"
else
    echo "⚠️ dmgbuild unavailable, building a plain DMG"
    rm -f "$OUT_PATH"
    plain_dmg
    echo "✅ DMG ready: $OUT_PATH"
fi

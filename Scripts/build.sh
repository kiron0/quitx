#!/usr/bin/env bash
# Build and run QuitX (SPM-based, no Xcode needed)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."

echo "▶ Building QuitX..."
cd "$ROOT"
swift build -c release 2>&1

BINARY=".build/release/QuitX"

echo "▶ Running QuitX..."
exec "$BINARY"

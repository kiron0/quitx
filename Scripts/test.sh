#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PHASE="${1:-regression}"
[[ $# -eq 0 ]] || shift
ARGS=(test --build-system native)
FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
[[ ! -d "$FRAMEWORKS" ]] || ARGS+=(-Xswiftc -F -Xswiftc "$FRAMEWORKS")

case "$PHASE" in
    regression) ;;
    integration) ARGS+=(--filter 'PortKillIntegrationTests') ;;
    ui) ARGS+=(--filter 'WindowLayoutTests') ;;
    snapshots)
        mkdir -p "$ROOT_DIR/.qa/snapshots"
        ARGS+=(--filter 'SnapshotTests')
        ;;
    *) echo "Unknown test phase: $PHASE. Use regression, integration, ui, or snapshots." >&2; exit 2 ;;
esac

export QUITX_TEST_PHASE="$PHASE"
unset QUITX_LAST_WINDOW_FIXTURE QUITX_INSTANCE_FIXTURE_APP
cd "$ROOT_DIR"
swift "${ARGS[@]}" "$@" 2>&1 | LC_ALL=C sed -E '/warning:.*build-system native.*deprecated/d'

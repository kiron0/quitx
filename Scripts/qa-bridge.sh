#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/Scripts/qa-bridge.sh"
QA_DIR="$ROOT_DIR/.qa"
PID_FILE="$QA_DIR/bridge.pid"
TIMEOUT="${QA_TIMEOUT:-2400}"
LABEL="dev.kiron.quitx.qa-bridge"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
TEST_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
CURRENT_JOB=""

mkdir -p "$QA_DIR"
cd "$ROOT_DIR" || exit 1

now() { date +%s; }
set_status() { printf '%s %s pid=%s\n' "$1" "$(now)" "$$" > "$QA_DIR/status"; }
heartbeat() { now > "$QA_DIR/heartbeat"; }

bridge_pid() {
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null) || return 1
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    ps -p "$pid" -o command= 2>/dev/null | grep -q "qa-bridge.sh" || return 1
    echo "$pid"
}

swift_test() {
    local args=(test --build-system native)
    [[ -d "$TEST_FRAMEWORKS" ]] && args+=(-Xswiftc -F -Xswiftc "$TEST_FRAMEWORKS")
    [[ -n "${1:-}" ]] && args+=(--filter "$1")
    set -o pipefail
    swift "${args[@]}" 2>&1 | LC_ALL=C sed -E '/warning:.*build-system native.*deprecated/d'
}

run_job() {
    local name="$1"
    shift
    set_status "running $name"
    printf '$ %s\n' "$*" > "$QA_DIR/$name.log"
    set -m
    ( "$@" ) >> "$QA_DIR/$name.log" 2>&1 < /dev/null &
    local job=$!
    CURRENT_JOB=$job
    set +m
    local started
    started=$(now)
    while kill -0 "$job" 2>/dev/null; do
        if (( $(now) - started > TIMEOUT )); then
            echo "qa-bridge: timed out after ${TIMEOUT}s" >> "$QA_DIR/$name.log"
            kill -TERM -- "-$job" 2>/dev/null
            sleep 5
            kill -KILL -- "-$job" 2>/dev/null
        fi
        heartbeat
        sleep 1
    done
    wait "$job"
    local rc=$?
    CURRENT_JOB=""
    echo "$rc" > "$QA_DIR/$name.exit"
    printf '%s %s %s\n' "$name" "$rc" "$(now)" > "$QA_DIR/last"
    echo "finished: $name exit $rc"
    return "$rc"
}

handle() {
    local req="$1" cmd arg=""
    cmd=${req%% *}
    [[ "$req" != "$cmd" ]] && arg=${req#* }
    if [[ -n "$arg" && ! "$arg" =~ ^[A-Za-z0-9_./]+$ ]]; then
        echo "rejected argument: $arg" > "$QA_DIR/rejected.log"
        return
    fi
    case "$cmd" in
        ping) printf 'pong %s\n' "$(now)" > "$QA_DIR/pong" ;;
        build) run_job build ./Scripts/build.sh ;;
        test) run_job test swift_test "$arg" ;;
        check) run_job build ./Scripts/build.sh && run_job test swift_test "$arg" ;;
        last-window) run_job last-window ./Scripts/test-last-window.sh ;;
        *) echo "rejected command: $cmd" > "$QA_DIR/rejected.log" ;;
    esac
}

shutdown() {
    [[ -n "$CURRENT_JOB" ]] && kill -TERM -- "-$CURRENT_JOB" 2>/dev/null
    set_status stopped
    rm -f "$PID_FILE"
    exit 0
}

run_loop() {
    local existing
    if existing=$(bridge_pid) && [[ "$existing" != "$$" ]]; then
        echo "qa-bridge already running (pid $existing)"
        exit 0
    fi
    echo "$$" > "$PID_FILE"
    trap '' HUP
    trap 'shutdown' INT TERM
    set_status idle
    echo "QA bridge watching $QA_DIR/request (pid $$, Ctrl-C to stop)"
    while true; do
        if [[ -s "$QA_DIR/request" ]]; then
            local req
            req=$(head -n1 "$QA_DIR/request" | tr -d '\r')
            rm -f "$QA_DIR/request"
            [[ -n "$req" ]] && handle "$req"
            set_status idle
        fi
        heartbeat
        sleep 1
    done
}

start_background() {
    local pid
    if pid=$(bridge_pid); then
        echo "qa-bridge already running (pid $pid)"
        return 0
    fi
    nohup "$SCRIPT_PATH" run >> "$QA_DIR/bridge.log" 2>&1 < /dev/null &
    disown 2>/dev/null || true
    sleep 1
    if pid=$(bridge_pid); then
        echo "qa-bridge started (pid $pid), log: $QA_DIR/bridge.log"
    else
        echo "qa-bridge failed to start, see $QA_DIR/bridge.log" >&2
        return 1
    fi
}

stop_bridge() {
    local pid
    if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
        launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    fi
    if pid=$(bridge_pid); then
        kill -TERM "$pid"
        echo "qa-bridge stopped (pid $pid)"
    else
        echo "qa-bridge is not running"
    fi
}

show_status() {
    local pid
    if pid=$(bridge_pid); then
        echo "running (pid $pid)"
    else
        echo "not running"
    fi
    [[ -f "$QA_DIR/status" ]] && echo "status: $(cat "$QA_DIR/status")"
    [[ -f "$QA_DIR/last" ]] && echo "last: $(cat "$QA_DIR/last")"
}

install_agent() {
    stop_bridge >/dev/null
    mkdir -p "$(dirname "$PLIST")"
    cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>/bin/bash</string><string>$SCRIPT_PATH</string><string>run</string></array>
    <key>WorkingDirectory</key><string>$ROOT_DIR</string>
    <key>EnvironmentVariables</key>
    <dict><key>PATH</key><string>$PATH</string></dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>$QA_DIR/bridge.log</string>
    <key>StandardErrorPath</key><string>$QA_DIR/bridge.log</string>
</dict>
</plist>
PLIST
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    sleep 2
    show_status
}

uninstall_agent() {
    stop_bridge
    rm -f "$PLIST"
    echo "LaunchAgent removed"
}

case "${1:-run}" in
    run) run_loop ;;
    start) start_background ;;
    stop) stop_bridge ;;
    status) show_status ;;
    install) install_agent ;;
    uninstall) uninstall_agent ;;
    *) echo "usage: $0 [run|start|stop|status|install|uninstall]" >&2; exit 2 ;;
esac

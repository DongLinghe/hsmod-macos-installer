#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
HEARTHSTONE_APP="${HEARTHSTONE_APP:-/Applications/Hearthstone/Hearthstone.app}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"
PORT="${HSMOD_PORT:-58744}"

fail() {
    echo "error: $1" >&2
    exit 1
}

[ -d "$HEARTHSTONE_APP" ] || fail "Hearthstone app not found: $HEARTHSTONE_APP"

MACOS_DIR="$HEARTHSTONE_APP/Contents/MacOS"
INFO_PLIST="$HEARTHSTONE_APP/Contents/Info.plist"
EXE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST" 2>/dev/null || echo Hearthstone)"
EXE_PATH="$MACOS_DIR/$EXE_NAME"
REAL_PATH="$MACOS_DIR/$EXE_NAME.real"

if /usr/bin/pgrep -f "$MACOS_DIR/$EXE_NAME" >/dev/null 2>&1 || /usr/bin/pgrep -f "$MACOS_DIR/$EXE_NAME.real" >/dev/null 2>&1; then
    fail "Hearthstone is already running. Quit it before starting the watcher."
fi

"$ROOT_DIR/scripts/reinject_current_install.sh"
open -a /Applications/Battle.net.app >/dev/null 2>&1 || true

echo "Battle.net is open. Click the blue Play button for Hearthstone."
echo "This watcher will re-apply the wrapper if Battle.net restores the official executable before launch."

deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
while [ "$(date +%s)" -lt "$deadline" ]; do
    if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/alive" >/dev/null 2>&1; then
        echo "HsMod is running: http://127.0.0.1:$PORT/pack"
        exit 0
    fi

    if /usr/bin/pgrep -f "$REAL_PATH" >/dev/null 2>&1; then
        echo "Hearthstone launched through the wrapper. Waiting for HsMod web server..."
        for _ in {1..45}; do
            if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/alive" >/dev/null 2>&1; then
                echo "HsMod is running: http://127.0.0.1:$PORT/pack"
                exit 0
            fi
            sleep 2
        done
        fail "Hearthstone launched, but HsMod did not answer on port $PORT"
    fi

    if /usr/bin/pgrep -f "$EXE_PATH -launch" >/dev/null 2>&1; then
        fail "Hearthstone launched without the wrapper. Quit Hearthstone and run this watcher again."
    fi

    exe_desc="$(/usr/bin/file -b "$EXE_PATH")"
    if [[ "$exe_desc" == *"universal binary"* ]] || [[ "$exe_desc" == *"arm64"* ]]; then
        echo "Battle.net restored the official executable; re-injecting wrapper..."
        "$ROOT_DIR/scripts/reinject_current_install.sh"
    fi

    sleep 2
done

fail "timed out waiting for Hearthstone launch"

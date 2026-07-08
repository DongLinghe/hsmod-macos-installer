#!/bin/zsh
set -uo pipefail

LOG="$HOME/Library/Logs/HsModReinject.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

alert() {
    /usr/bin/osascript -e "display alert \"HsMod Reinject\" message \"$1\" as informational" >/dev/null 2>&1 || true
}

fail() {
    echo "[$(timestamp)] ERROR: $1"
    alert "$1\n\n日志：$LOG"
    exit 1
}

run() {
    echo "+ $*"
    "$@"
}

echo ""
echo "===== HsMod reinject started at $(timestamp) ====="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
RESOURCES_DIR="$(cd "$SCRIPT_DIR/../Resources" && pwd -P)"
HEARTHSTONE_APP="${1:-/Applications/Hearthstone/Hearthstone.app}"

if [ ! -d "$HEARTHSTONE_APP" ]; then
    fail "找不到炉石应用：$HEARTHSTONE_APP"
fi

ROOT_DIR="$(cd "$HEARTHSTONE_APP/.." && pwd -P)"
MACOS_DIR="$HEARTHSTONE_APP/Contents/MacOS"
INFO_PLIST="$HEARTHSTONE_APP/Contents/Info.plist"
EXE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST" 2>/dev/null || echo Hearthstone)"
EXE_PATH="$MACOS_DIR/$EXE_NAME"
REAL_PATH="$MACOS_DIR/$EXE_NAME.real"

if [ ! -e "$EXE_PATH" ]; then
    fail "找不到炉石主程序：$EXE_PATH"
fi

if /usr/bin/pgrep -f "$MACOS_DIR/$EXE_NAME" >/dev/null 2>&1 || /usr/bin/pgrep -f "$MACOS_DIR/$EXE_NAME.real" >/dev/null 2>&1; then
    fail "炉石还在运行。请先退出炉石，再重新打开这个注入器。"
fi

for required in HsModLauncher.c HsMod.dll libdoorstop.dylib BepInEx_macos_universal_5.4.23.5.zip; do
    [ -e "$RESOURCES_DIR/$required" ] || fail "注入器资源缺失：$required"
done

command -v clang >/dev/null 2>&1 || fail "找不到 clang。请先安装 Xcode Command Line Tools。"
command -v codesign >/dev/null 2>&1 || fail "找不到 codesign。"

BACKUP_DIR="$ROOT_DIR/HsModBackups/$(date +%Y%m%d-%H%M%S)"
run mkdir -p "$BACKUP_DIR"

echo "Hearthstone app: $HEARTHSTONE_APP"
echo "Root dir: $ROOT_DIR"
echo "Executable: $EXE_PATH"
echo "Real executable: $REAL_PATH"
echo "Backup dir: $BACKUP_DIR"

if [ -e "$EXE_PATH" ]; then
    run cp -p "$EXE_PATH" "$BACKUP_DIR/$EXE_NAME.before-reinject"
fi
if [ -e "$REAL_PATH" ]; then
    run cp -p "$REAL_PATH" "$BACKUP_DIR/$EXE_NAME.real.before-reinject"
fi

EXE_DESC="$(/usr/bin/file -b "$EXE_PATH")"
echo "Current executable file type: $EXE_DESC"

if [[ "$EXE_DESC" == *"shell script"* ]]; then
    if [ -e "$MACOS_DIR/$EXE_NAME.original" ]; then
        echo "Found old shell wrapper; using $EXE_NAME.original as real executable."
        run cp -p "$MACOS_DIR/$EXE_NAME.original" "$REAL_PATH"
    elif [ ! -e "$REAL_PATH" ]; then
        fail "当前主程序是 shell wrapper，但找不到可恢复的原始二进制。"
    fi
elif [[ "$EXE_DESC" == *"universal binary"* ]] || [[ "$EXE_DESC" == *"arm64"* ]]; then
    echo "Current executable looks like the game binary; refreshing .real copy."
    run cp -p "$EXE_PATH" "$REAL_PATH"
elif [ -e "$REAL_PATH" ]; then
    echo "Current executable looks like an existing wrapper; keeping .real copy."
else
    echo "Unknown executable shape; saving it as .real before wrapping."
    run cp -p "$EXE_PATH" "$REAL_PATH"
fi

echo "Installing BepInEx if needed..."
if [ ! -d "$ROOT_DIR/BepInEx/core" ]; then
    run /usr/bin/ditto -x -k "$RESOURCES_DIR/BepInEx_macos_universal_5.4.23.5.zip" "$ROOT_DIR"
fi

run mkdir -p "$ROOT_DIR/BepInEx/plugins"
run cp -p "$RESOURCES_DIR/HsMod.dll" "$ROOT_DIR/BepInEx/plugins/HsMod.dll"

if [ -d "$RESOURCES_DIR/unstripped_corlib" ]; then
    run mkdir -p "$ROOT_DIR/BepInEx/unstripped_corlib"
    run /usr/bin/ditto "$RESOURCES_DIR/unstripped_corlib" "$ROOT_DIR/BepInEx/unstripped_corlib"
fi

run cp -p "$RESOURCES_DIR/libdoorstop.dylib" "$ROOT_DIR/libdoorstop.dylib"
run codesign -f -s - "$ROOT_DIR/libdoorstop.dylib"

echo "Compiling signed x86_64 launcher wrapper..."
run clang -arch x86_64 -Os "-DHSMOD_REAL_GAME=\"$REAL_PATH\"" "$RESOURCES_DIR/HsModLauncher.c" -o "$EXE_PATH"
run chmod +x "$EXE_PATH" "$REAL_PATH"

run rm -f "$MACOS_DIR"/preloader_*.log(N)
run xattr -cr "$HEARTHSTONE_APP"
run codesign -f -s - "$EXE_PATH"
run codesign -f -s - "$REAL_PATH"
run codesign -f -s - --deep "$HEARTHSTONE_APP"
run codesign --verify --verbose=2 "$HEARTHSTONE_APP"

echo "===== HsMod reinject finished at $(timestamp) ====="
alert "注入完成。以后从 Battle.net 点“进入游戏”即可启用 HsMod。\n\n日志：$LOG"
exit 0

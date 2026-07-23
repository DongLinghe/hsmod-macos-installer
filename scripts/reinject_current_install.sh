#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
HEARTHSTONE_APP="${HEARTHSTONE_APP:-/Applications/Hearthstone/Hearthstone.app}"

fail() {
    echo "error: $1" >&2
    exit 1
}

[ -d "$HEARTHSTONE_APP" ] || fail "Hearthstone app not found: $HEARTHSTONE_APP"
command -v clang >/dev/null 2>&1 || fail "clang not found"
command -v codesign >/dev/null 2>&1 || fail "codesign not found"

ROOT="$(cd "$HEARTHSTONE_APP/.." && pwd -P)"
MACOS_DIR="$HEARTHSTONE_APP/Contents/MacOS"
INFO_PLIST="$HEARTHSTONE_APP/Contents/Info.plist"
EXE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST" 2>/dev/null || echo Hearthstone)"
EXE_PATH="$MACOS_DIR/$EXE_NAME"
REAL_PATH="$MACOS_DIR/$EXE_NAME.real"

[ -e "$EXE_PATH" ] || fail "Hearthstone executable not found: $EXE_PATH"
[ -e "$ROOT/libdoorstop.dylib" ] || fail "libdoorstop.dylib not found: $ROOT/libdoorstop.dylib"
[ -e "$ROOT/BepInEx/core/BepInEx.Preloader.dll" ] || fail "BepInEx is not installed under: $ROOT/BepInEx"
[ -e "$ROOT/BepInEx/plugins/HsMod.dll" ] || fail "HsMod.dll is not installed under: $ROOT/BepInEx/plugins"

if /usr/bin/pgrep -f "$MACOS_DIR/$EXE_NAME" >/dev/null 2>&1 || /usr/bin/pgrep -f "$MACOS_DIR/$EXE_NAME.real" >/dev/null 2>&1; then
    fail "Hearthstone is still running. Quit it before reinjecting."
fi

mkdir -p "$ROOT/HsModBackups"
BACKUP_DIR="$ROOT/HsModBackups/$(date +%Y%m%d-%H%M%S)-quick"
mkdir -p "$BACKUP_DIR"
cp -p "$EXE_PATH" "$BACKUP_DIR/$EXE_NAME.before-reinject"
[ ! -e "$REAL_PATH" ] || cp -p "$REAL_PATH" "$BACKUP_DIR/$EXE_NAME.real.before-reinject"

EXE_DESC="$(/usr/bin/file -b "$EXE_PATH")"
if [[ "$EXE_DESC" == *"universal binary"* ]] || [[ "$EXE_DESC" == *"arm64"* ]]; then
    cp -p "$EXE_PATH" "$REAL_PATH"
elif [ ! -e "$REAL_PATH" ]; then
    fail "current executable looks like a wrapper but $REAL_PATH does not exist"
fi

clang -arch x86_64 -mmacosx-version-min=11.0 -Os "-DHSMOD_REAL_GAME=\"$REAL_PATH\"" "$ROOT_DIR/src/HsModLauncher.c" -o "$EXE_PATH"
chmod +x "$EXE_PATH" "$REAL_PATH"
xattr -cr "$HEARTHSTONE_APP"
codesign -f -s - "$ROOT/libdoorstop.dylib" >/dev/null
codesign -f -s - "$EXE_PATH" >/dev/null
codesign -f -s - "$REAL_PATH" >/dev/null
codesign -f -s - --deep "$HEARTHSTONE_APP" >/dev/null

echo "re-injected launcher wrapper into: $EXE_PATH"
echo "real game binary: $REAL_PATH"

#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
HEARTHSTONE_APP="${HEARTHSTONE_APP:-/Applications/Hearthstone/Hearthstone.app}"
HSMOD_SOURCE="${HSMOD_SOURCE:-}"
BEPINEX_ZIP="${BEPINEX_ZIP:-}"
WORK_ROOT="${HSMOD_WORK_ROOT:-$ROOT_DIR/build}"
WORK_DIR="$WORK_ROOT/install-from-archives"

fail() {
    echo "error: $1" >&2
    exit 1
}

choose_file() {
    local prompt="$1"
    local result
    result="$(/usr/bin/osascript -e "POSIX path of (choose file with prompt \"$prompt\")" 2>/dev/null || true)"
    [ -n "$result" ] || fail "file selection cancelled: $prompt"
    echo "$result"
}

[ -d "$HEARTHSTONE_APP" ] || fail "Hearthstone app not found: $HEARTHSTONE_APP"
command -v dotnet >/dev/null 2>&1 || fail "dotnet not found"
command -v clang >/dev/null 2>&1 || fail "clang not found"

if [ -z "$HSMOD_SOURCE" ]; then
    HSMOD_SOURCE="$(choose_file '请选择 HsMod-bepinex5.zip 或 HsMod 源码压缩包')"
fi

if [ -z "$BEPINEX_ZIP" ]; then
    BEPINEX_ZIP="$(choose_file '请选择 BepInEx_macos_universal_5.4.23.5.zip')"
fi

[ -e "$HSMOD_SOURCE" ] || fail "HsMod source not found: $HSMOD_SOURCE"
[ -e "$BEPINEX_ZIP" ] || fail "BepInEx zip not found: $BEPINEX_ZIP"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/resources"

HSMOD_BUILD_DIR="$WORK_ROOT/hsmod-source" "$ROOT_DIR/scripts/build_patched_hsmod.sh" "$HSMOD_SOURCE" "$WORK_DIR/resources/HsMod.dll"

mkdir -p "$WORK_DIR/hsmod-src"
if [ -d "$HSMOD_SOURCE" ]; then
    /usr/bin/ditto "$HSMOD_SOURCE" "$WORK_DIR/hsmod-src/source"
else
    /usr/bin/ditto -x -k "$HSMOD_SOURCE" "$WORK_DIR/hsmod-src"
fi
HSMOD_SLN_PATH="$(find "$WORK_DIR/hsmod-src" -maxdepth 3 -name HsMod.sln -print -quit)"
HSMOD_ROOT="${HSMOD_SLN_PATH:+$(dirname "$HSMOD_SLN_PATH")}"
[ -n "$HSMOD_ROOT" ] || fail "could not locate HsMod.sln after extraction"

if [ -d "$HSMOD_ROOT/HsMod/UnstrippedCorlibUinx" ]; then
    /usr/bin/ditto "$HSMOD_ROOT/HsMod/UnstrippedCorlibUinx" "$WORK_DIR/resources/unstripped_corlib"
elif [ -d "$HSMOD_ROOT/HsMod/UnstrippedCorlib" ]; then
    /usr/bin/ditto "$HSMOD_ROOT/HsMod/UnstrippedCorlib" "$WORK_DIR/resources/unstripped_corlib"
else
    fail "could not find UnstrippedCorlibUinx or UnstrippedCorlib in HsMod source"
fi

mkdir -p "$WORK_DIR/bepinex"
/usr/bin/ditto -x -k "$BEPINEX_ZIP" "$WORK_DIR/bepinex"
[ -e "$WORK_DIR/bepinex/libdoorstop.dylib" ] || fail "libdoorstop.dylib not found in BepInEx zip"

APP_PATH="$WORK_DIR/HsMod macOS Runtime.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$ROOT_DIR/templates/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$ROOT_DIR/scripts/apply_current_install.sh" "$APP_PATH/Contents/MacOS/apply_current_install.sh"
cp "$ROOT_DIR/scripts/restore_original_hearthstone.sh" "$APP_PATH/Contents/Resources/restore_original_hearthstone.sh"
cp "$ROOT_DIR/src/HsModLauncher.c" "$APP_PATH/Contents/Resources/HsModLauncher.c"
cp "$WORK_DIR/resources/HsMod.dll" "$APP_PATH/Contents/Resources/HsMod.dll"
cp "$WORK_DIR/bepinex/libdoorstop.dylib" "$APP_PATH/Contents/Resources/libdoorstop.dylib"
cp "$BEPINEX_ZIP" "$APP_PATH/Contents/Resources/BepInEx_macos_universal_5.4.23.5.zip"
/usr/bin/ditto "$WORK_DIR/resources/unstripped_corlib" "$APP_PATH/Contents/Resources/unstripped_corlib"
chmod +x "$APP_PATH/Contents/MacOS/apply_current_install.sh" "$APP_PATH/Contents/Resources/restore_original_hearthstone.sh"
xattr -cr "$APP_PATH"
codesign -f -s - "$APP_PATH"

"$APP_PATH/Contents/MacOS/apply_current_install.sh" "$HEARTHSTONE_APP"

echo "installed patched HsMod into: $HEARTHSTONE_APP"
echo "temporary runtime app: $APP_PATH"

#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
HEARTHSTONE_ROOT="${HEARTHSTONE_ROOT:-/Applications/Hearthstone}"
BEPINEX_ZIP="${BEPINEX_ZIP:-$HOME/Downloads/BepInEx_macos_universal_5.4.23.5.zip}"
APP_PATH="$ROOT_DIR/dist/HsMod macOS Helper.app"

fail() {
    echo "error: $1" >&2
    exit 1
}

need_file() {
    [ -e "$1" ] || fail "missing: $1"
}

need_dir() {
    [ -d "$1" ] || fail "missing directory: $1"
}

need_file "$ROOT_DIR/src/HsModLauncher.c"
need_file "$ROOT_DIR/scripts/apply_current_install.sh"
need_file "$ROOT_DIR/scripts/restore_original_hearthstone.sh"
need_file "$ROOT_DIR/templates/Info.plist"
need_file "$BEPINEX_ZIP"
need_file "$HEARTHSTONE_ROOT/BepInEx/plugins/HsMod.dll"
need_file "$HEARTHSTONE_ROOT/libdoorstop.dylib"
need_dir "$HEARTHSTONE_ROOT/BepInEx/unstripped_corlib"

command -v codesign >/dev/null 2>&1 || fail "codesign not found"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources/unstripped_corlib"

cp "$ROOT_DIR/templates/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$ROOT_DIR/scripts/apply_current_install.sh" "$APP_PATH/Contents/MacOS/apply_current_install.sh"
cp "$ROOT_DIR/scripts/restore_original_hearthstone.sh" "$APP_PATH/Contents/Resources/restore_original_hearthstone.sh"
cp "$ROOT_DIR/src/HsModLauncher.c" "$APP_PATH/Contents/Resources/HsModLauncher.c"
cp "$HEARTHSTONE_ROOT/BepInEx/plugins/HsMod.dll" "$APP_PATH/Contents/Resources/HsMod.dll"
cp "$HEARTHSTONE_ROOT/libdoorstop.dylib" "$APP_PATH/Contents/Resources/libdoorstop.dylib"
cp "$BEPINEX_ZIP" "$APP_PATH/Contents/Resources/BepInEx_macos_universal_5.4.23.5.zip"
/usr/bin/ditto "$HEARTHSTONE_ROOT/BepInEx/unstripped_corlib" "$APP_PATH/Contents/Resources/unstripped_corlib"

chmod +x "$APP_PATH/Contents/MacOS/apply_current_install.sh"
chmod +x "$APP_PATH/Contents/Resources/restore_original_hearthstone.sh"
xattr -cr "$APP_PATH"
codesign -f -s - "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH"

echo "built: $APP_PATH"

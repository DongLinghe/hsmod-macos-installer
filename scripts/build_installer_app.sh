#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
APP_PATH="$ROOT_DIR/dist/HsMod macOS Installer.app"
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

fail() {
    echo "error: $1" >&2
    exit 1
}

command -v swiftc >/dev/null 2>&1 || fail "swiftc not found"
command -v codesign >/dev/null 2>&1 || fail "codesign not found"

[ -e "$ROOT_DIR/src/HsModInstallerApp.swift" ] || fail "missing src/HsModInstallerApp.swift"
[ -e "$ROOT_DIR/src/HsModLauncher.c" ] || fail "missing src/HsModLauncher.c"
[ -e "$ROOT_DIR/templates/InstallerInfo.plist" ] || fail "missing templates/InstallerInfo.plist"

export MACOSX_DEPLOYMENT_TARGET=11.0

rm -rf "$APP_PATH"
mkdir -p "$MACOS" "$RESOURCES/scripts" "$RESOURCES/src" "$RESOURCES/templates" "$RESOURCES/patches"

cp "$ROOT_DIR/templates/InstallerInfo.plist" "$CONTENTS/Info.plist"
printf "APPL????" > "$CONTENTS/PkgInfo"
swiftc -O -target arm64-apple-macos11.0 -framework Cocoa "$ROOT_DIR/src/HsModInstallerApp.swift" -o "$MACOS/HsModInstaller"

cp "$ROOT_DIR/src/HsModLauncher.c" "$RESOURCES/src/HsModLauncher.c"
cp "$ROOT_DIR/templates/Info.plist" "$RESOURCES/templates/Info.plist"
cp "$ROOT_DIR/patches/hsmod-macos-compat.patch" "$RESOURCES/patches/hsmod-macos-compat.patch"

for script in \
    apply_current_install.sh \
    build_patched_hsmod.sh \
    install_from_archives.sh \
    reinject_current_install.sh \
    restore_original_hearthstone.sh \
    watch_current_install.sh; do
    cp "$ROOT_DIR/scripts/$script" "$RESOURCES/scripts/$script"
    chmod +x "$RESOURCES/scripts/$script"
done

chmod +x "$MACOS/HsModInstaller"
xattr -cr "$APP_PATH"
codesign -f -s - "$APP_PATH"
xattr -cr "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "built: $APP_PATH"

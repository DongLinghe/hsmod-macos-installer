#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
FINAL_APP_PATH="${HSMOD_INSTALLER_APP_PATH:-$ROOT_DIR/dist/HsMod macOS Installer.app}"
if [ -n "${HSMOD_INSTALLER_APP_PATH:-}" ]; then
    APP_PATH="$FINAL_APP_PATH"
else
    BUILD_ROOT="$(mktemp -d /tmp/hsmod-installer-build.XXXXXX)"
    APP_PATH="$BUILD_ROOT/HsMod macOS Installer.app"
fi
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

fail() {
    echo "error: $1" >&2
    exit 1
}

clean_metadata() {
    local target="$1"
    xattr -cr "$target" 2>/dev/null || true
    while IFS= read -r item; do
        xattr -d com.apple.FinderInfo "$item" 2>/dev/null || true
        xattr -d 'com.apple.fileprovider.fpfs#P' "$item" 2>/dev/null || true
    done < <(/usr/bin/find "$target" -print)
}

command -v swiftc >/dev/null 2>&1 || fail "swiftc not found"
command -v codesign >/dev/null 2>&1 || fail "codesign not found"

[ -e "$ROOT_DIR/src/HsModInstallerApp.swift" ] || fail "missing src/HsModInstallerApp.swift"
[ -e "$ROOT_DIR/src/HsModLauncher.c" ] || fail "missing src/HsModLauncher.c"
[ -e "$ROOT_DIR/templates/InstallerInfo.plist" ] || fail "missing templates/InstallerInfo.plist"
[ -e "$ROOT_DIR/assets/AppIcon.png" ] || fail "missing assets/AppIcon.png"

export MACOSX_DEPLOYMENT_TARGET=11.0

rm -rf "$APP_PATH"
mkdir -p "$(dirname "$APP_PATH")"
mkdir -p "$MACOS" "$RESOURCES/scripts" "$RESOURCES/src" "$RESOURCES/templates" "$RESOURCES/patches"

cp "$ROOT_DIR/templates/InstallerInfo.plist" "$CONTENTS/Info.plist"
printf "APPL????" > "$CONTENTS/PkgInfo"
swiftc -O -target arm64-apple-macos11.0 -framework Cocoa "$ROOT_DIR/src/HsModInstallerApp.swift" -o "$MACOS/HsModInstaller"

cp "$ROOT_DIR/src/HsModLauncher.c" "$RESOURCES/src/HsModLauncher.c"
cp "$ROOT_DIR/templates/Info.plist" "$RESOURCES/templates/Info.plist"
cp "$ROOT_DIR/patches/hsmod-macos-compat.patch" "$RESOURCES/patches/hsmod-macos-compat.patch"
cp "$ROOT_DIR/assets/AppIcon.png" "$RESOURCES/AppIcon.png"

ICONSET_ROOT="$(mktemp -d /tmp/hsmod-installer-iconset.XXXXXX)"
ICONSET="$ICONSET_ROOT/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ROOT_DIR/assets/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" "$ROOT_DIR/assets/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

for script in \
    apply_current_install.sh \
    build_patched_hsmod.sh \
    install_from_archives.sh \
    patch_hsmod_source.sh \
    reinject_current_install.sh \
    restore_original_hearthstone.sh \
    watch_current_install.sh; do
    cp "$ROOT_DIR/scripts/$script" "$RESOURCES/scripts/$script"
    chmod +x "$RESOURCES/scripts/$script"
done

chmod +x "$MACOS/HsModInstaller"
clean_metadata "$APP_PATH"
codesign -f -s - "$APP_PATH"
clean_metadata "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [ "$APP_PATH" != "$FINAL_APP_PATH" ]; then
    rm -rf "$FINAL_APP_PATH"
    mkdir -p "$(dirname "$FINAL_APP_PATH")"
    /usr/bin/ditto --norsrc --noextattr --noqtn --noacl "$APP_PATH" "$FINAL_APP_PATH"
    clean_metadata "$FINAL_APP_PATH"
fi

echo "built: $FINAL_APP_PATH"

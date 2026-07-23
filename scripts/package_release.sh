#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
ZIP_PATH="$ROOT_DIR/dist/HsMod-macOS-Installer.zip"
TMP_ROOT="$(mktemp -d /tmp/hsmod-installer-package.XXXXXX)"
APP_PATH="$TMP_ROOT/HsMod macOS Installer.app"

clean_metadata() {
    local target="$1"
    xattr -cr "$target" 2>/dev/null || true
    while IFS= read -r item; do
        xattr -d com.apple.FinderInfo "$item" 2>/dev/null || true
        xattr -d 'com.apple.fileprovider.fpfs#P' "$item" 2>/dev/null || true
    done < <(/usr/bin/find "$target" -print)
}

HSMOD_INSTALLER_APP_PATH="$APP_PATH" "$ROOT_DIR/scripts/build_installer_app.sh"

mkdir -p "$(dirname "$ZIP_PATH")"
rm -f "$ZIP_PATH"
clean_metadata "$APP_PATH"
/usr/bin/ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$APP_PATH" "$ZIP_PATH"
clean_metadata "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "packaged: $ZIP_PATH"

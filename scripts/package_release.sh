#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
APP_PATH="$ROOT_DIR/dist/HsMod macOS Installer.app"
ZIP_PATH="$ROOT_DIR/dist/HsMod-macOS-Installer.zip"

"$ROOT_DIR/scripts/build_installer_app.sh"

rm -f "$ZIP_PATH"
xattr -cr "$APP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "packaged: $ZIP_PATH"

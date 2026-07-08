#!/bin/zsh
set -uo pipefail

HEARTHSTONE_APP="${1:-/Applications/Hearthstone/Hearthstone.app}"
MACOS_DIR="$HEARTHSTONE_APP/Contents/MacOS"
INFO_PLIST="$HEARTHSTONE_APP/Contents/Info.plist"
EXE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST" 2>/dev/null || echo Hearthstone)"
EXE_PATH="$MACOS_DIR/$EXE_NAME"
REAL_PATH="$MACOS_DIR/$EXE_NAME.real"

if [ ! -e "$REAL_PATH" ]; then
    echo "No .real executable found: $REAL_PATH" >&2
    exit 1
fi

if /usr/bin/pgrep -f "$MACOS_DIR/$EXE_NAME" >/dev/null 2>&1 || /usr/bin/pgrep -f "$MACOS_DIR/$EXE_NAME.real" >/dev/null 2>&1; then
    echo "Hearthstone is running. Quit it first." >&2
    exit 1
fi

backup_dir="$(cd "$HEARTHSTONE_APP/.." && pwd -P)/HsModBackups/restore-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
cp -p "$EXE_PATH" "$backup_dir/$EXE_NAME.wrapper.before-restore"
cp -p "$REAL_PATH" "$EXE_PATH"
rm -f "$REAL_PATH"
rm -f "$MACOS_DIR"/preloader_*.log(N)
xattr -cr "$HEARTHSTONE_APP"
codesign -f -s - --deep "$HEARTHSTONE_APP"
codesign --verify --verbose=2 "$HEARTHSTONE_APP"
echo "Restored original Hearthstone executable."

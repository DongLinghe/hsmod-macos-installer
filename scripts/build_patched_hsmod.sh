#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
PATCH_SCRIPT="$ROOT_DIR/scripts/patch_hsmod_source.sh"
INPUT="${1:-}"
OUTPUT="${2:-$ROOT_DIR/dist/HsMod.dll}"
BUILD_DIR="${HSMOD_BUILD_DIR:-$ROOT_DIR/build/hsmod-source}"

fail() {
    echo "error: $1" >&2
    exit 1
}

fail_bad_hsmod_input() {
    if find "$BUILD_DIR" -maxdepth 4 -name libdoorstop.dylib -print -quit | grep -q .; then
        fail "HsMod input looks like a BepInEx package. Select an HsMod source zip or a source folder that contains HsMod/HsMod.csproj."
    fi

    fail "could not find HsMod/HsMod.csproj in input. Select an HsMod source zip, not the BepInEx zip."
}

usage() {
    cat <<'USAGE'
Usage:
  ./scripts/build_patched_hsmod.sh /path/to/HsMod-source.zip [output.dll]
  ./scripts/build_patched_hsmod.sh /path/to/HsMod-source-dir [output.dll]

The script applies idempotent macOS compatibility edits, restores the .NET
project, builds Release, and copies HsMod.dll to output.dll.
USAGE
}

[ -n "$INPUT" ] || {
    usage
    exit 2
}

[ -e "$INPUT" ] || fail "input not found: $INPUT"
[ -x "$PATCH_SCRIPT" ] || fail "patch script not found or not executable: $PATCH_SCRIPT"
command -v dotnet >/dev/null 2>&1 || fail "dotnet not found"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

if [ -d "$INPUT" ]; then
    /usr/bin/ditto "$INPUT" "$BUILD_DIR/source"
else
    case "$INPUT" in
        *.zip)
            mkdir -p "$BUILD_DIR/extracted"
            /usr/bin/ditto -x -k "$INPUT" "$BUILD_DIR/extracted"
            ;;
        *)
            fail "input must be a zip file or source directory"
            ;;
    esac
fi

if [ -d "$BUILD_DIR/source" ]; then
    SOURCE_ROOT="$BUILD_DIR/source"
else
    SLN_PATH="$(find "$BUILD_DIR/extracted" -maxdepth 3 -name HsMod.sln -print -quit)"
    SOURCE_ROOT="${SLN_PATH:+$(dirname "$SLN_PATH")}"
fi

[ -n "${SOURCE_ROOT:-}" ] && [ -f "$SOURCE_ROOT/HsMod/HsMod.csproj" ] || fail_bad_hsmod_input

echo "source: $SOURCE_ROOT"

(
    cd "$SOURCE_ROOT"
    "$PATCH_SCRIPT" "$SOURCE_ROOT"

    dotnet restore HsMod/HsMod.csproj
    dotnet build HsMod/HsMod.csproj --configuration Release --no-restore
)

BUILT_DLL="$(find "$SOURCE_ROOT/HsMod" -path '*/Release/HsMod.dll' -print -quit)"
[ -n "$BUILT_DLL" ] || fail "build finished but HsMod.dll was not found"

mkdir -p "$(dirname "$OUTPUT")"
cp -p "$BUILT_DLL" "$OUTPUT"
echo "built: $OUTPUT"

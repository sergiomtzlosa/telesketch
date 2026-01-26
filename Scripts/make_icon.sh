#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -d "Telesketch.xcodeproj" ]; then
    "$ROOT/Scripts/generate_project.sh"
fi

xcodebuild -project Telesketch.xcodeproj \
    -scheme IconGen \
    -configuration Release \
    -derivedDataPath build-icon \
    build

ICONGEN="$ROOT/build-icon/Build/Products/Release/TelesketchIconGen"
if [ ! -x "$ICONGEN" ]; then
    echo "error: icon generator was not built." >&2
    exit 1
fi

mkdir -p build/icon
MASTER="$ROOT/build/icon/AppIcon-1024.png"
"$ICONGEN" "$MASTER" 1024

ICONSET="$ROOT/build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

emit() {
    local size="$1"
    local name="$2"
    if [ "$size" -eq 1024 ]; then
        cp "$MASTER" "$ICONSET/$name.png"
    else
        sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$name.png" >/dev/null
    fi
}

emit 16   icon_16x16
emit 32   icon_16x16@2x
emit 32   icon_32x32
emit 64   icon_32x32@2x
emit 128  icon_128x128
emit 256  icon_128x128@2x
emit 256  icon_256x256
emit 512  icon_256x256@2x
emit 512  icon_512x512
emit 1024 icon_512x512@2x

mkdir -p Telesketch/Resources
iconutil -c icns "$ICONSET" -o Telesketch/Resources/AppIcon.icns

VERIFY="$ROOT/build/verified.iconset"
rm -rf "$VERIFY"
iconutil -c iconset Telesketch/Resources/AppIcon.icns -o "$VERIFY"
sips -g pixelWidth -g pixelHeight "$VERIFY/icon_512x512@2x.png"

# The .icns is copied as a bundle resource, so regenerate the project now that
# the file exists (XcodeGen includes resources found on disk).
"$ROOT/Scripts/generate_project.sh"

echo
echo "Icon written: $ROOT/Telesketch/Resources/AppIcon.icns"
echo "Preview:      $MASTER"

#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -f "Telesketch/Resources/AppIcon.icns" ]; then
    "$ROOT/Scripts/make_icon.sh"
else
    "$ROOT/Scripts/generate_project.sh"
fi

xcodebuild -project Telesketch.xcodeproj \
    -scheme Telesketch \
    -configuration Debug \
    -derivedDataPath build \
    build

echo
echo "Built: $ROOT/build/Build/Products/Debug/Telesketch.app"

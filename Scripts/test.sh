#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

"$ROOT/Scripts/generate_project.sh"

xcodebuild -project Telesketch.xcodeproj \
    -scheme Telesketch \
    -configuration Debug \
    -derivedDataPath build \
    test

echo
echo "Tests passed."

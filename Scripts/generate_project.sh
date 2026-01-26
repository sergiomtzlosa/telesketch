#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

XCODEGEN="${XCODEGEN:-/opt/homebrew/bin/xcodegen}"
if [ ! -x "$XCODEGEN" ]; then
    XCODEGEN="$(command -v xcodegen || true)"
fi
if [ -z "$XCODEGEN" ] || [ ! -x "$XCODEGEN" ]; then
    echo "error: XcodeGen was not found. Install it with 'brew install xcodegen'." >&2
    exit 1
fi

"$XCODEGEN" generate --spec project.yml
echo "Generated Telesketch.xcodeproj"

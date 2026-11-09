#!/usr/bin/env bash
# Export the Web build (same command CI uses) and serve it locally for testing,
# without pushing to GitHub Pages.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot binary not found at $GODOT_BIN -- set GODOT_BIN=/path/to/Godot" >&2
	exit 1
fi

mkdir -p build/web
"$GODOT_BIN" --headless --export-release "Web" "build/web/index.html"

echo "Serving build/web at http://127.0.0.1:8060"
cd build/web
exec python3 ../../scripts/serve_web.py

#!/usr/bin/env bash
# Runs the GUT test suite headlessly. Extra args are passed to GUT (e.g. -gselect=test_smoke).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

# Make sure imports/class caches exist (first run on a fresh clone).
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
exec "$GODOT" --headless --path "$ROOT/game" -s addons/gut/gut_cmdln.gd "$@"

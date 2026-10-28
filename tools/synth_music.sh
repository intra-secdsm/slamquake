#!/usr/bin/env bash
# Renders music and crowd loops with Blender's bundled Python (it ships numpy).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/versions.env"
PY=$(ls -d "$HOME"/.local/opt/blender/"$BLENDER_VERSION"/*/python/bin/python3* 2>/dev/null | head -1)
[[ -x "$PY" ]] || { echo "Blender's Python not found; run tools/setup.sh" >&2; exit 1; }
"$PY" "$ROOT/tools/synth_music.py"

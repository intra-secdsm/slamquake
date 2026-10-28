#!/usr/bin/env bash
# Regenerates game/assets/generated/* with Blender, then lets Godot import them.
#   tools/build_assets.sh [wrestler|ring|props|arena ...] [--quick]
# Each target runs in a fresh Blender process with a fixed hash seed so outputs are
# byte-identical between runs (keeps Git LFS from storing churn).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLENDER="${BLENDER:-blender}"
GODOT="${GODOT:-godot}"
ALL_TARGETS=(wrestler ring props arena)

targets=(); flags=()
for a in "$@"; do [[ $a == --* ]] && flags+=("$a") || targets+=("$a"); done
[[ ${#targets[@]} -eq 0 ]] && targets=("${ALL_TARGETS[@]}")

for t in "${targets[@]}"; do
  PYTHONHASHSEED=0 "$BLENDER" -b --factory-startup --python-use-system-env \
    -P "$ROOT/blender/build.py" -- "$t" "${flags[@]}" 2>&1 \
    | { grep -E '^(\[build\]|exported|unchanged|wrote|Traceback|  File|[A-Za-z]*Error)' || true; }
done
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true

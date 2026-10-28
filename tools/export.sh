#!/usr/bin/env bash
# Exports standalone builds into build/ (git-ignored).
#   tools/export.sh [Linux|Windows ...]     default: Linux
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
presets=("$@")
[[ ${#presets[@]} -eq 0 ]] && presets=(Linux)

"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
for p in "${presets[@]}"; do
  case "$p" in
    Linux) out="$ROOT/build/linux/slamquake.x86_64" ;;
    Windows) out="$ROOT/build/windows/slamquake.exe" ;;
    *) echo "unknown preset $p" >&2; exit 1 ;;
  esac
  mkdir -p "$(dirname "$out")"
  "$GODOT" --headless --path "$ROOT/game" --export-release "$p" "$out" 2>&1 | grep -E 'ERROR|error' || true
  ls -lh "$out"
done

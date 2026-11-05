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
  # --python-exit-code: a Python exception in the generator must fail Blender, which
  # otherwise exits 0; pipefail then carries Blender's status through the log filter
  status=0
  PYTHONHASHSEED=0 "$BLENDER" -b --factory-startup --python-use-system-env --python-exit-code 1 \
    -P "$ROOT/blender/build.py" -- "$t" "${flags[@]}" 2>&1 \
    | { grep -E '^(\[build\]|exported|unchanged|wrote|Traceback|  File|[A-Za-z]*Error)' || true; } \
    || status=$?
  if [[ $status -ne 0 ]]; then
    echo "build_assets: $t failed (Blender exit $status)" >&2
    exit 1
  fi
done
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
if ! "$GODOT" --headless --path "$ROOT/game" --import >"$log" 2>&1; then
  cat "$log" >&2
  echo "build_assets: Godot import failed" >&2
  exit 1
fi

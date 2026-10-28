#!/usr/bin/env bash
# Contact sheet of single poses (no ring, side or front view), one tile per pose.
#   tools/pose_sheet.sh <out.png> <side|front> <pose> [pose...]
#   pose = anim@seconds, or pair:<move>@seconds for both halves of a paired move
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$(realpath -m "$1")"; view="$2"; shift 2
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
files=()
for p in "$@"; do
  f="$tmp/$(echo "$p" | tr ':@/' '___').png"
  "$ROOT/tools/screenshot.sh" res://dev/pose_lineup.tscn "$f" 12 --poses="$p" --view="$view" \
    --zoom=1.1 --look=1.15 --ring=0 >/dev/null 2>&1 || true
  [[ -f "$f" ]] && files+=("$f") || echo "no frame for $p" >&2
done
[[ ${#files[@]} -gt 0 ]] || exit 1
python3 "$ROOT/tools/grid.py" "$out" --crop 350,50,1250,850 -- "${files[@]}"
echo "$out"

#!/usr/bin/env bash
# Contact sheet of a move performed in a real match, frozen at several moments.
#   tools/move_sheet.sh <out.png> <move_id> <t1,t2,...> [extra args, e.g. --cam=front]
# Each tile is a separate run of res://dev/env_shots.tscn --setup=move --at=<t>
# (t = seconds after the move starts, in game time). Needs a graphical session.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$(realpath -m "$1")"; move="$2"; IFS=',' read -ra times <<< "$3"; shift 3
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
files=()
for t in "${times[@]}"; do
  f="$tmp/$t.png"
  "$ROOT/tools/screenshot.sh" res://dev/env_shots.tscn "$f" 1200 --setup=move --move="$move" --at="$t" "$@" \
    >/dev/null 2>&1 || true
  [[ -f "$f" ]] || { echo "no frame at t=$t (does $move exist in this build?)" >&2; continue; }
  files+=("$f")
done
[[ ${#files[@]} -gt 0 ]] || exit 1
python3 "$ROOT/tools/grid.py" "$out" --crop 260,40,1340,860 --labels "${times[@]/#/t=}" -- "${files[@]}"
echo "$out"

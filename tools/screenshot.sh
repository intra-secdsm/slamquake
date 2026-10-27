#!/usr/bin/env bash
# Renders a scene with the real GPU renderer and saves a PNG.
#   tools/screenshot.sh <res://scene.tscn> <out.png> [frames] [extra --key=value args...]
# Needs a graphical session; falls back to the local Wayland/X display if none is set.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
scene="$1"; out="$(realpath -m "$2")"; frames="${3:-30}"; shift $(( $# >= 3 ? 3 : $# ))

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
driver=()
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" && -S "$XDG_RUNTIME_DIR/wayland-0" ]]; then
  export WAYLAND_DISPLAY=wayland-0
fi
[[ -n "${WAYLAND_DISPLAY:-}" ]] && driver=(--display-driver wayland)

mkdir -p "$(dirname "$out")"
exec "$GODOT" --path "$ROOT/game" "${driver[@]}" --resolution 1600x900 \
  -- --scene="$scene" --screenshot="$out" --frames="$frames" "$@"

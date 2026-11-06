#!/usr/bin/env bash
# Exports standalone builds into build/ (git-ignored).
#   tools/export.sh [Linux|Windows ...]     default: Linux
# Fails if Godot fails; a build is only replaced by a successful export of this run.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
presets=("$@")
[[ ${#presets[@]} -eq 0 ]] && presets=(Linux)

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if ! "$GODOT" --headless --path "$ROOT/game" --import >"$log" 2>&1; then
  cat "$log" >&2
  echo "export: Godot import failed" >&2
  exit 1
fi
for p in "${presets[@]}"; do
  case "$p" in
    Linux) out="$ROOT/build/linux/slamquake.x86_64" ;;
    Windows) out="$ROOT/build/windows/slamquake.exe" ;;
    *) echo "unknown preset $p" >&2; exit 1 ;;
  esac
  mkdir -p "$(dirname "$out")"
  # export into a scratch dir next to the final file, then swap it in, so an old build
  # never passes for a new one
  stage="$(mktemp -d "$(dirname "$out")/.export.XXXXXX")"
  status=0
  "$GODOT" --headless --path "$ROOT/game" --export-release "$p" "$stage/$(basename "$out")" >"$log" 2>&1 \
    || status=$?
  if [[ $status -ne 0 || ! -s "$stage/$(basename "$out")" ]]; then
    tail -n 40 "$log" >&2
    rm -rf "$stage"
    echo "export: $p failed (exit $status); the previous build was left untouched" >&2
    exit 1
  fi
  grep -E 'ERROR|error' "$log" || true
  mv -f "$stage"/* "$(dirname "$out")/"   # the binary and any companion files (console wrapper)
  rm -rf "$stage"
  ls -lh "$out"
done

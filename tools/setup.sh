#!/usr/bin/env bash
# Installs the pinned toolchain (Godot, Blender, git-lfs) into ~/.local without sudo,
# verifying published checksums, and installs the GUT addon into the Godot project.
#
#   tools/setup.sh            install everything missing
#   tools/setup.sh --force    reinstall even if present
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=versions.env
source "$ROOT/tools/versions.env"

OPT="$HOME/.local/opt"
BIN="$HOME/.local/bin"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wrestle-setup"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

mkdir -p "$OPT" "$BIN" "$CACHE"

# Looks up a file's hash in a "<hash>  <file>" or "<hash> *<file>" sums file.
sum_for() { # sums_file filename
  awk -v f="$2" '{ n=$2; sub(/^\*/, "", n); if (n == f) { print $1; exit } }' "$1"
}

log() { printf '\033[1;35m[setup]\033[0m %s\n' "$*"; }

fetch() { # url dest
  local url="$1" dest="$2"
  if [[ ! -s "$dest" ]]; then
    log "downloading $(basename "$dest")"
    curl -fsSL --retry 3 -o "$dest.part" "$url"
    mv "$dest.part" "$dest"
  fi
}

verify() { # algo file expected_hash
  local algo="$1" file="$2" expected="$3" actual
  actual="$("${algo}sum" "$file" | cut -d' ' -f1)"
  if [[ "$actual" != "$expected" ]]; then
    echo "checksum mismatch for $file" >&2
    echo "  expected $expected" >&2
    echo "  actual   $actual" >&2
    rm -f "$file"
    exit 1
  fi
}

install_godot() {
  local dir="$OPT/godot/$GODOT_VERSION"
  local tag="${GODOT_VERSION}-stable"
  local base="https://github.com/godotengine/godot/releases/download/$tag"
  local zip="Godot_v${tag}_linux.x86_64.zip"
  local tpz="Godot_v${tag}_export_templates.tpz"
  local tpl_dir="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

  if [[ $FORCE == 0 && -x "$dir/godot" && -d "$tpl_dir" ]]; then
    log "godot $GODOT_VERSION already installed"; return
  fi
  local dl="$CACHE/godot-$GODOT_VERSION"; mkdir -p "$dl"
  fetch "$base/SHA512-SUMS.txt" "$dl/SHA512-SUMS.txt"
  fetch "$base/$zip" "$dl/$zip"
  fetch "$base/$tpz" "$dl/$tpz"
  verify sha512 "$dl/$zip" "$(sum_for "$dl/SHA512-SUMS.txt" "$zip")"
  verify sha512 "$dl/$tpz" "$(sum_for "$dl/SHA512-SUMS.txt" "$tpz")"

  rm -rf "$dir"; mkdir -p "$dir"
  unzip -q -o "$dl/$zip" -d "$dir"
  mv "$dir/Godot_v${tag}_linux.x86_64" "$dir/godot"
  chmod +x "$dir/godot"
  ln -sfn "$dir/godot" "$BIN/godot"

  log "installing godot export templates"
  rm -rf "$tpl_dir"; mkdir -p "$tpl_dir"
  local tmp; tmp="$(mktemp -d "$CACHE/tpz.XXXX")"
  unzip -q "$dl/$tpz" -d "$tmp"
  mv "$tmp/templates/"* "$tpl_dir/"
  rm -rf "$tmp"
  log "godot $GODOT_VERSION installed"
}

install_blender() {
  local dir="$OPT/blender/$BLENDER_VERSION"
  local series="${BLENDER_VERSION%.*}"
  local base="https://download.blender.org/release/Blender$series"
  local tarball="blender-${BLENDER_VERSION}-linux-x64.tar.xz"

  if [[ $FORCE == 0 && -x "$dir/blender" ]]; then
    log "blender $BLENDER_VERSION already installed"; return
  fi
  local dl="$CACHE/blender-$BLENDER_VERSION"; mkdir -p "$dl"
  fetch "$base/blender-${BLENDER_VERSION}.sha256" "$dl/sums.sha256"
  fetch "$base/$tarball" "$dl/$tarball"
  verify sha256 "$dl/$tarball" "$(sum_for "$dl/sums.sha256" "$tarball")"

  rm -rf "$dir"; mkdir -p "$dir"
  tar -xJf "$dl/$tarball" -C "$dir" --strip-components=1
  ln -sfn "$dir/blender" "$BIN/blender"
  log "blender $BLENDER_VERSION installed"
}

install_git_lfs() {
  local dir="$OPT/git-lfs/$GIT_LFS_VERSION"
  local tag="v$GIT_LFS_VERSION"
  local base="https://github.com/git-lfs/git-lfs/releases/download/$tag"
  local tarball="git-lfs-linux-amd64-${tag}.tar.gz"

  if [[ $FORCE == 0 && -x "$dir/git-lfs" ]]; then
    log "git-lfs $GIT_LFS_VERSION already installed"; return
  fi
  local dl="$CACHE/git-lfs-$GIT_LFS_VERSION"; mkdir -p "$dl"
  fetch "$base/sha256sums.asc" "$dl/sha256sums.asc"
  fetch "$base/$tarball" "$dl/$tarball"
  verify sha256 "$dl/$tarball" "$(sum_for "$dl/sha256sums.asc" "$tarball")"

  rm -rf "$dir"; mkdir -p "$dir"
  tar -xzf "$dl/$tarball" -C "$dir" --strip-components=1
  ln -sfn "$dir/git-lfs" "$BIN/git-lfs"
  git lfs install --skip-repo >/dev/null
  log "git-lfs $GIT_LFS_VERSION installed"
}

install_gut() {
  local dest="$ROOT/game/addons/gut"
  if [[ $FORCE == 0 && -f "$dest/plugin.cfg" ]] && grep -q "version=\"$GUT_VERSION\"" "$dest/plugin.cfg"; then
    log "GUT $GUT_VERSION already installed"; return
  fi
  local dl="$CACHE/gut-$GUT_VERSION"; mkdir -p "$dl"
  fetch "https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.tar.gz" "$dl/gut.tar.gz"
  local tmp; tmp="$(mktemp -d "$CACHE/gut.XXXX")"
  tar -xzf "$dl/gut.tar.gz" -C "$tmp"
  rm -rf "$dest"; mkdir -p "$(dirname "$dest")"
  mv "$tmp"/Gut-*/addons/gut "$dest"
  rm -rf "$tmp"
  log "GUT $GUT_VERSION installed into game/addons/gut"
}

install_godot
install_blender
install_git_lfs
install_gut

log "done:"
"$BIN/godot" --version
"$BIN/blender" --version 2>/dev/null | head -1
"$BIN/git-lfs" version

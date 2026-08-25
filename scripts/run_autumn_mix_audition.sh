#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ $# -ne 1 || ( "$1" != "explore" && "$1" != "boss" ) ]]; then
  echo "Usage: scripts/run_autumn_mix_audition.sh <explore|boss>" >&2
  exit 64
fi
mode=$1

if [[ $(uname -s) != "Darwin" ]]; then
  echo "This listening launcher currently requires macOS CoreAudio." >&2
  exit 69
fi

if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin=$GODOT_BIN
elif command -v godot >/dev/null 2>&1; then
  godot_bin=$(command -v godot)
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin=$(command -v godot4)
elif [[ -x "/Applications/Godot 2.app/Contents/MacOS/Godot" ]]; then
  godot_bin="/Applications/Godot 2.app/Contents/MacOS/Godot"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot 4.6.2 was not found. Set GODOT_BIN to the exact executable." >&2
  exit 127
fi

godot_version=$("$godot_bin" --version)
if [[ "$godot_version" != 4.6.2.* ]]; then
  echo "Expected Godot 4.6.2, found: $godot_version" >&2
  exit 70
fi

worktree_state=$(git -C "$project_root" status --porcelain --untracked-files=normal)
if [[ -n "$worktree_state" ]]; then
  echo "Refusing a dirty worktree; commit, stash, or remove untracked files first." >&2
  exit 73
fi

node "$project_root/scripts/generate_build_provenance.mjs"

exec "$godot_bin" \
  --path "$project_root/godot" \
  --audio-driver CoreAudio \
  --script res://tools/autumn_mix_audition.gd \
  -- "$mode"

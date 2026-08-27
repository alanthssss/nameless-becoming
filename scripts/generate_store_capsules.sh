#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_EXECUTABLE="${GODOT_BIN:-/Applications/Godot 2.app/Contents/MacOS/Godot}"
SOURCE="$PROJECT_ROOT/marketing/key-art/see-you-at-the-hive-key-art-base-v1.png"

if [[ ! -x "$GODOT_EXECUTABLE" ]]; then
  echo "Godot executable is unavailable: $GODOT_EXECUTABLE" >&2
  exit 1
fi
if [[ ! -f "$SOURCE" ]]; then
  echo "Missing commercial key-art input: $SOURCE" >&2
  exit 1
fi

"$GODOT_EXECUTABLE" \
  --path "$PROJECT_ROOT/godot" \
  --script res://tools/generate_store_capsules.gd

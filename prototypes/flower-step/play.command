#!/bin/bash
set -euo pipefail
prototype_dir=$(cd "$(dirname "$0")" && pwd)
if [[ -n "${GODOT_BIN:-}" ]]; then
  flower_godot="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  flower_godot=$(command -v godot)
elif [[ -x "/Applications/Godot 2.app/Contents/MacOS/Godot" ]]; then
  flower_godot="/Applications/Godot 2.app/Contents/MacOS/Godot"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  flower_godot="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo '需要 Godot 4.6.2。请设置 GODOT_BIN 或用 Godot 打开同目录 project.godot。'
  exit 1
fi
exec "$flower_godot" --path "$prototype_dir" "$@"

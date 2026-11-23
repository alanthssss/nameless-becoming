#!/usr/bin/env bash
set -euo pipefail
task_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -n "${GODOT_BIN:-}" ]]; then
  task_godot=$GODOT_BIN
elif [[ -x '/Applications/Godot 2.app/Contents/MacOS/Godot' ]]; then
  task_godot='/Applications/Godot 2.app/Contents/MacOS/Godot'
elif command -v godot >/dev/null 2>&1; then
  task_godot=$(command -v godot)
else
  echo '需要 Godot 4.6.2；请设置 GODOT_BIN。' >&2
  exit 127
fi
exec "$task_godot" --path "$task_root/prototypes/swarm-flight" res://pond_tilemap/main.tscn "$@"

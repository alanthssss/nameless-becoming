#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin=$GODOT_BIN
elif command -v godot >/dev/null 2>&1; then
  godot_bin=$(command -v godot)
elif [[ -x '/Applications/Godot 2.app/Contents/MacOS/Godot' ]]; then
  godot_bin='/Applications/Godot 2.app/Contents/MacOS/Godot'
elif [[ -x '/Applications/Godot.app/Contents/MacOS/Godot' ]]; then
  godot_bin='/Applications/Godot.app/Contents/MacOS/Godot'
else
  echo '需要 Godot 4.6.2。请设置 GODOT_BIN 后重新启动。' >&2
  exit 127
fi
printf 'Rain route experiment | %s | %s | %s\n' "$project_root" "$(git -C "$project_root" branch --show-current)" "$(git -C "$project_root" rev-parse --short HEAD)"
if [[ -n "$(git -C "$project_root" status --porcelain --untracked-files=normal)" ]]; then
  echo 'Source includes uncommitted changes.'
fi
"$godot_bin" --path "$project_root/godot" --headless --import > /tmp/see-you-hive-rain-route-import.log 2>&1
if grep -q 'SCRIPT ERROR:' /tmp/see-you-hive-rain-route-import.log; then
  cat /tmp/see-you-hive-rain-route-import.log >&2
  exit 1
fi
exec "$godot_bin" --path "$project_root/godot" res://playtest/rain_route/rain_route.tscn

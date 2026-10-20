#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
if [[ -x "/Applications/Godot 2.app/Contents/MacOS/Godot" ]]; then
  exec "/Applications/Godot 2.app/Contents/MacOS/Godot" --path "$PWD" "$@"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD" "$@"
else
  print "需要 Godot 4.6.2；也可以直接打开已导出的试玩盒 App。"
  read -k 1
fi

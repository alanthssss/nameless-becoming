#!/bin/zsh
set -e
cd -- "$(dirname -- "$0")"
for engine in '/Applications/Godot 2.app/Contents/MacOS/Godot' '/Applications/Godot.app/Contents/MacOS/Godot'; do
  if [[ -x "$engine" ]]; then exec "$engine" --path "$PWD" "$@"; fi
done
print '未找到 Godot。请安装 Godot 4.6，或打开已交付的 雨来之前.app。'
exit 1

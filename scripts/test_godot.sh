#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin=$GODOT_BIN
elif command -v godot >/dev/null 2>&1; then
  godot_bin=$(command -v godot)
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin=$(command -v godot4)
else
  echo "Godot 4.6.2+ was not found. Set GODOT_BIN or add godot to PATH." >&2
  exit 127
fi

echo "Using $($godot_bin --version)"

for test_file in smoke_test.gd flow_test.gd fix_boss_term_test.gd; do
  echo "Running $test_file"
  "$godot_bin" \
    --path "$project_root/godot" \
    --headless \
    --script "res://tests/$test_file"
done

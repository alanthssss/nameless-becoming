#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
bin=${GODOT_BIN:-/Applications/Godot 2.app/Contents/MacOS/Godot}
out=${1:-/tmp/hive-year-profile}
python3 "$root/scripts/run_with_timeout.py" 90 "$bin" --headless --path "$root/godot" --import > /tmp/hive-year-profile-import.log 2>&1
if grep -q 'SCRIPT ERROR:' /tmp/hive-year-profile-import.log; then cat /tmp/hive-year-profile-import.log; exit 1; fi
python3 "$root/scripts/run_with_timeout.py" 120 "$bin" --path "$root/godot" --script res://tools/year_profile.gd -- "$out" > "$out.log" 2>&1
if grep -q 'SCRIPT ERROR:' "$out.log"; then cat "$out.log"; exit 1; fi
grep 'YEAR PROFILE PASSED' "$out.log"

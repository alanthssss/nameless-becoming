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
  echo "Godot 4.6.2 was not found. Set GODOT_BIN or add godot to PATH." >&2
  exit 127
fi

output_dir=${1:-"$project_root/marketing/screenshots"}
if [[ "$output_dir" != /* ]]; then
  output_dir="$project_root/$output_dir"
fi
mkdir -p "$output_dir"

capture_ids=(hive spring summer autumn winter finale)
capture_files=(
  01-hive-developer-capture.png
  02-spring-developer-capture.png
  03-summer-developer-capture.png
  04-autumn-developer-capture.png
  05-winter-developer-capture.png
  06-finale-developer-capture.png
)

for index in "${!capture_ids[@]}"; do
  capture_id=${capture_ids[$index]}
  capture_path="$output_dir/${capture_files[$index]}"
  "$godot_bin" \
    --path "$project_root/godot" \
    --script res://tools/capture_journey_marketing.gd \
    -- \
    "--capture=$capture_id" \
    "--output=$capture_path"
done

"$godot_bin" \
  --path "$project_root/godot" \
  --headless \
  --script res://tools/verify_journey_marketing_screenshots.gd \
  -- \
  "--directory=$output_dir"

echo "Developer runtime captures written to $output_dir"

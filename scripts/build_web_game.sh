#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ -n ${GODOT_BIN:-} ]]; then
  godot_bin=$GODOT_BIN
elif command -v godot >/dev/null 2>&1; then
  godot_bin=$(command -v godot)
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin=$(command -v godot4)
else
  echo "Godot 4.6.2 was not found. Set GODOT_BIN or add godot to PATH." >&2
  exit 1
fi

godot_version=$("$godot_bin" --version)
if [[ $godot_version != 4.6.2.* ]]; then
  echo "Web candidate export requires Godot 4.6.2; found $godot_version." >&2
  exit 1
fi

mkdir -p "$project_root/public/game"
node "$project_root/scripts/generate_build_provenance.mjs"
"$project_root/scripts/with_commercial_godot_cache.sh" \
  "$godot_bin" --path "$project_root/godot" --headless --export-release Web \
  "$project_root/public/game/index.html"
"$project_root/scripts/verify_godot_export_contents.sh" \
  --pack "$project_root/public/game/index.pck"
node "$project_root/scripts/prepare_web_export.mjs"

for required_file in index.html index.js index.pck index.wasm.gz index.wasm.part0; do
  test -s "$project_root/public/game/$required_file"
done

echo "Web game payload prepared and verified from the commercial resource closure."

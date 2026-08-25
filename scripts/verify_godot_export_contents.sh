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

godot_version=$("$godot_bin" --version)
if [[ $godot_version != 4.6.2.* ]]; then
  echo "Export-content verification requires Godot 4.6.2; found $godot_version." >&2
  exit 1
fi

verification_root=$(mktemp -d "${TMPDIR:-/tmp}/nameless-export-contents.XXXXXX")
trap 'rm -rf "$verification_root"' EXIT HUP INT TERM
inspector_project="$verification_root/inspector-project"
mkdir -p "$inspector_project"
printf '%s\n' '[application]' 'config/name="Nameless Export Pack Inspector"' > "$inspector_project/project.godot"

run_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout --foreground 90s "$@"
  else
    "$@"
  fi
}

verify_pack() {
  local pack_path=$1
  local label=$2
  local report_path=${3:-}
  local log_path="$verification_root/${label//[^a-zA-Z0-9_-]/-}-inspect.log"
  local inspector_arguments=("$pack_path")
  if [[ -n $report_path ]]; then
    inspector_arguments+=(--report "$report_path")
  fi
  echo "Inspecting exported contents: $label"
  if ! run_with_timeout \
    "$godot_bin" \
    --path "$inspector_project" \
    --headless \
    --script "$project_root/scripts/verify_godot_pack.gd" \
    -- "${inspector_arguments[@]}" > "$log_path" 2>&1; then
    cat "$log_path" >&2
    exit 1
  fi
  if grep -q "SCRIPT ERROR:" "$log_path"; then
    cat "$log_path" >&2
    exit 1
  fi
  if ! grep -q "EXPORT PACK CONTENTS VERIFIED" "$log_path"; then
    cat "$log_path" >&2
    echo "Pack inspector did not report its success marker for $label." >&2
    exit 1
  fi
  grep "EXPORT PACK CONTENTS VERIFIED" "$log_path"
  if [[ -n $report_path && ! -s $report_path ]]; then
    cat "$log_path" >&2
    echo "Pack inspector did not create its machine-readable report for $label." >&2
    exit 1
  fi
}

if [[ ${1:-} == --pack-report ]]; then
  if [[ $# -ne 3 ]]; then
    echo "Usage: $0 --pack-report <PCK-or-embedded-executable> <absolute-report-path>" >&2
    exit 2
  fi
  pack_path=$2
  report_path=$3
  if [[ $report_path != /* ]]; then
    echo "Pack inspection report path must be absolute: $report_path" >&2
    exit 2
  fi
  verify_pack "$(cd "$(dirname "$pack_path")" && pwd)/$(basename "$pack_path")" "reported-pack" "$report_path"
  exit 0
fi

if [[ ${1:-} == --pack ]]; then
  shift
  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 --pack <PCK-or-embedded-executable> [...]" >&2
    exit 2
  fi
  pack_number=0
  for pack_path in "$@"; do
    pack_number=$((pack_number + 1))
    verify_pack "$(cd "$(dirname "$pack_path")" && pwd)/$(basename "$pack_path")" "provided-pack-$pack_number"
  done
  exit 0
fi

if [[ $# -eq 0 ]]; then
  presets=("macOS" "Windows Desktop" "Web")
else
  presets=("$@")
fi

for preset in "${presets[@]}"; do
  case "$preset" in
    macOS)
      slug=macos
      ;;
    "Windows Desktop")
      slug=windows
      ;;
    Web)
      slug=web
      ;;
    *)
      echo "Unknown export preset: $preset" >&2
      exit 2
      ;;
  esac
  pack_path="$verification_root/$slug.pck"
  export_log="$verification_root/$slug-export.log"
  echo "Exporting resource pack with Godot 4.6.2: $preset"
  if ! run_with_timeout \
    "$godot_bin" \
    --path "$project_root/godot" \
    --headless \
    --export-pack "$preset" \
    "$pack_path" > "$export_log" 2>&1; then
    cat "$export_log" >&2
    exit 1
  fi
  if grep -q "SCRIPT ERROR:" "$export_log"; then
    cat "$export_log" >&2
    exit 1
  fi
  if [[ ! -s $pack_path ]]; then
    cat "$export_log" >&2
    echo "Godot did not create a non-empty resource pack for $preset." >&2
    exit 1
  fi
  verify_pack "$pack_path" "$slug"
done

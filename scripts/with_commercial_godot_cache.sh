#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_godot_root="$project_root/godot"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <Godot export command and arguments>" >&2
  exit 2
fi

command_args=("$@")
export_mode_index=-1
project_path_index=-1
for index in "${!command_args[@]}"; do
  case "${command_args[$index]}" in
    --export-pack|--export-release|--export-debug)
      if [[ $export_mode_index -ge 0 ]]; then
        echo "Commercial cache wrapper accepts exactly one Godot export mode." >&2
        exit 2
      fi
      export_mode_index=$index
      ;;
    --path)
      project_path_index=$index
      ;;
  esac
done
if [[ $export_mode_index -lt 0 ]]; then
  echo "Commercial cache wrapper only accepts a Godot export command." >&2
  exit 2
fi
if [[ $project_path_index -lt 0 || $((project_path_index + 1)) -ge ${#command_args[@]} ]]; then
  echo "Commercial cache wrapper requires --path pointing to the repository Godot project." >&2
  exit 2
fi
if [[ $((export_mode_index + 2)) -ge ${#command_args[@]} || ${command_args[$((export_mode_index + 2))]} == --* ]]; then
  echo "Commercial exports must provide an explicit output path outside the temporary stage." >&2
  exit 2
fi

requested_project_path=${command_args[$((project_path_index + 1))]}
if [[ $requested_project_path != /* ]]; then
  requested_project_path="$PWD/$requested_project_path"
fi
requested_project_path=$(cd "$requested_project_path" && pwd)
if [[ $requested_project_path != "$source_godot_root" ]]; then
  echo "Commercial cache wrapper refuses a different Godot project: $requested_project_path" >&2
  exit 2
fi

temporary_base=${TMPDIR:-/tmp}
temporary_base=${temporary_base%/}
staging_root=$(mktemp -d "$temporary_base/see-you-at-hive-export.XXXXXX")
staging_godot_root="$staging_root/godot"
cleanup() {
  local status=$?
  trap - EXIT HUP INT TERM
  case "$staging_root" in
    "$temporary_base"/see-you-at-hive-export.*)
      rm -rf "$staging_root"
      ;;
    *)
      echo "Refusing to remove unexpected staging path: $staging_root" >&2
      status=1
      ;;
  esac
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

node "$project_root/scripts/create_commercial_godot_stage.mjs" "$source_godot_root" "$staging_godot_root"
command_args[$((project_path_index + 1))]=$staging_godot_root
"${command_args[@]}"

# Fail if Godot changed the exact registry during its staging-only file scan. The
# immutable artifact verifier repeats the semantic check inside the resulting PCK.
node "$project_root/scripts/prepare_commercial_script_class_cache.mjs" \
  --godot-root "$staging_godot_root" \
  --check

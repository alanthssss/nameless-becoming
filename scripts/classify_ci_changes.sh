#!/usr/bin/env bash
set -euo pipefail

# Read a NUL-delimited changed-path list from stdin. Only Markdown changes can
# skip the expensive game/application jobs; an empty or unfamiliar change set
# deliberately falls back to full CI.
changed_count=0
full_ci=false

while IFS= read -r -d '' changed_path; do
  changed_count=$((changed_count + 1))
  case "$changed_path" in
    *.md|*.mdx|*.markdown|*.MD|*.MDX|*.MARKDOWN)
      ;;
    *)
      full_ci=true
      ;;
  esac
done

if [[ "$changed_count" -eq 0 ]]; then
  full_ci=true
fi

printf '%s\n' "$full_ci"

#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
valid_commit() {
  [[ "$1" =~ ^[0-9a-fA-F]{40}$|^[0-9a-fA-F]{64}$ ]] && git cat-file -e "$1^{commit}" 2>/dev/null
}
base=''; head=''; diff_spec=''; reason=unknown_history
case "${EVENT_NAME:-}" in
  pull_request)
    base=${PR_BASE_SHA:-}; head=${PR_HEAD_SHA:-}
    if valid_commit "$base" && valid_commit "$head" && git merge-base "$base" "$head" >/dev/null; then
      diff_spec="$base...$head"; reason=pr_diff
    fi ;;
  push)
    base=${PUSH_BEFORE_SHA:-}; head=${CURRENT_SHA:-}
    if valid_commit "$base" && valid_commit "$head"; then
      diff_spec="$base..$head"; reason=push_diff
    fi ;;
  workflow_dispatch) reason=manual_full ;;
  merge_group) reason=merge_queue_full ;;
esac
paths=$(mktemp)
trap 'rm -f "$paths"' EXIT
if [[ -n "$diff_spec" ]] && git diff --name-only -z --no-renames "$diff_spec" -- > "$paths"; then
  git diff --check "$diff_spec" --
  if [[ ! -s "$paths" ]]; then reason=empty_diff_full; fi
else
  # Use the checked-out revision for whitespace checking when event metadata
  # or history is unavailable. A failed diff can never become an empty pass.
  : > "$paths"
  git show --check --format= HEAD --
fi
bash "$script_dir/classify_ci_changes.sh" < "$paths"
printf 'reason=%s\n' "$reason"

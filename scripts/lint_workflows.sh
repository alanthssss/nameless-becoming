#!/usr/bin/env bash
set -euo pipefail
# Pinned official Linux x86_64 release; no executing a floating installer.
archive=actionlint_1.7.12_linux_amd64.tar.gz
checksum=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
lint_dir=$(mktemp -d)
trap 'rm -rf "$lint_dir"' EXIT
curl --fail --silent --show-error --location --retry 2 --connect-timeout 15 --max-time 60 \
  "https://github.com/rhysd/actionlint/releases/download/v1.7.12/$archive" --output "$lint_dir/$archive"
printf '%s  %s\n' "$checksum" "$lint_dir/$archive" | sha256sum --check --strict
tar -xzf "$lint_dir/$archive" -C "$lint_dir" actionlint
"$lint_dir/actionlint" -shellcheck= .github/workflows/*.yml

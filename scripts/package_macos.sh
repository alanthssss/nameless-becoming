#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
archive="$project_dir/builds/NamelessBecoming-macOS.zip"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

ditto -x -k "$archive" "$staging"
app="$staging/无名：成蜂.app"
launcher="$staging/无名：成蜂.command"

codesign --force --deep --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"

if ! grep -q 'com.apple.quarantine' "$launcher"; then
  perl -0pi -e 's~(BASE_PATH=.*?\n)~$1xattr -dr com.apple.quarantine "\$BASE_PATH/无名：成蜂.app" 2>/dev/null || true\n~' "$launcher"
fi
chmod +x "$launcher"

rm -f "$archive"
ditto -c -k --sequesterRsrc "$staging" "$archive"

#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
check() {
  local expected="$1"; shift
  local actual
  actual=$(printf '%s\0' "$@" | bash "$root/scripts/classify_ci_changes.sh")
  [[ "$actual" == "$expected" ]] || { printf 'Unexpected CI scope: %s\n%s\n' "$*" "$actual"; exit 1; }
}
light=$'web=false\ngodot=false\nexport_game=false\ngodot_suite=routes'
routes=$'web=false\ngodot=true\nexport_game=false\ngodot_suite=routes'
engine=$'web=false\ngodot=true\nexport_game=false\ngodot_suite=full'
web=$'web=true\ngodot=false\nexport_game=false\ngodot_suite=routes'
full=$'web=true\ngodot=true\nexport_game=true\ngodot_suite=full'
check "$light" README.md 'docs/有 空格.md' .github/workflows/quality.yml scripts/classify_ci_changes.sh tests/ci-scope.test.sh
check "$routes" godot/playtest/year/year_model.gd godot/playtest/year/year_route.tscn godot/tests/year_route_test.gd docs/plan.md
check "$engine" godot/playtest/spring/spring_model.gd godot/fonts/font.otf
check "$engine" scripts/run_with_timeout.py
check "$web" src/app/page.tsx
check "$web" src/app/article.mdx
check "$full" godot/project.godot README.md
check "$full" scripts/unknown.sh
check "$full" godot/unknown.gd docs/renamed.md
[[ "$(bash "$root/scripts/classify_ci_changes.sh" </dev/null)" == "$full" ]]
printf 'CI SCOPE TEST PASSED\n'

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
check "$light" prototypes/flower-step/project.godot prototypes/flower-step/game_model.gd prototypes/flower-step/verify.gd prototypes/flower-step/assets/leaf.svg .github/workflows/flower-step.yml
check "$routes" prototypes/flower-step/game_model.gd godot/playtest/year/year_model.gd
check "$web" prototypes/flower-step/main.gd src/app/page.tsx
check "$light" prototypes/swarm-flight/project.godot prototypes/swarm-flight/world_view.gd prototypes/swarm-flight/icon.svg .github/workflows/swarm-flight.yml
check "$light" scripts/check_swarm_regressions.py tests/test_swarm_regressions.py tools/check_delivery.py tests/test_delivery_gate.py
check "$routes" scripts/check_swarm_regressions.py godot/playtest/year/year_model.gd
check "$web" tools/check_delivery.py src/app/page.tsx
check "$routes" prototypes/swarm-flight/main.gd godot/playtest/year/year_model.gd
check "$web" prototypes/swarm-flight/main.gd src/app/page.tsx
check "$light" prototypes/garden-puzzles/project.godot prototypes/garden-puzzles/main.gd .github/workflows/garden-puzzles.yml
check "$routes" prototypes/garden-puzzles/main.gd godot/playtest/year/year_model.gd
check "$web" prototypes/garden-puzzles/main.gd src/app/page.tsx
check "$full" prototypes/some-other-game/project.godot
check "$routes" godot/playtest/year/year_model.gd godot/playtest/year/year_route.tscn godot/tests/year_route_test.gd docs/plan.md
check "$engine" godot/playtest/spring/spring_model.gd godot/fonts/font.otf
check "$routes" scripts/play_year_film.command godot/playtest/year/guyu/guyu-wide.png
check "$engine" scripts/run_with_timeout.py
check "$web" src/app/page.tsx
check "$web" src/app/article.mdx
check "$full" godot/project.godot README.md
check "$full" scripts/unknown.sh
check "$full" godot/unknown.gd docs/renamed.md
[[ "$(bash "$root/scripts/classify_ci_changes.sh" </dev/null)" == "$full" ]]
printf 'CI SCOPE TEST PASSED\n'

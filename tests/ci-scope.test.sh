#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
check() {
  local expected="$1"; shift
  local actual
  actual=$(printf '%s\0' "$@" | bash "$root/scripts/classify_ci_changes.sh")
  [[ "$actual" == "$expected" ]] || { printf 'Unexpected CI scope: %s\n%s\n' "$*" "$actual"; exit 1; }
}
expected() {
  printf 'web=%s\ngodot=%s\nexport_game=%s\ngodot_suite=%s\nswarm=%s\nflower=%s\ngarden=%s\ncontent=%s' "$@"
}
light=$(expected false false false routes false false false false)
content=$(expected false false false routes false false false true)
routes=$(expected false true false routes false false false false)
engine=$(expected false true false full false false false false)
web=$(expected true false false routes false false false false)
shared=$(expected true true false full false false false false)
legacy=$(expected true true true full false false false false)
full=$(expected true true true full true true true true)
swarm=$(expected false false false routes true false false false)
flower=$(expected false false false routes false true false false)
garden=$(expected false false false routes false false true false)
check "$light" 'docs/有 空格.md' docs/CI_PERFORMANCE_2026-11-01.md docs/a.mdx docs/UPPER.MD
check "$content" README.md marketing/README.md docs/STEAM_NEXT_FEST_2026_PLAN.md docs/design/art-source-register.md
check "$full" .github/workflows/quality.yml
check "$full" scripts/classify_ci_changes.sh tests/ci-scope.test.sh scripts/ci_scope.sh scripts/check_ci_results.py tests/test_ci_routing.py
check "$flower" prototypes/flower-step/project.godot prototypes/flower-step/verify.gd .github/workflows/flower-step.yml
check "$swarm" prototypes/swarm-flight/project.godot .github/workflows/swarm-flight.yml prototypes/swarm-flight/review-evidence/2026-10-30/leaf-canopy/g1/legacy-stage-5.json
for file in scripts/check_swarm_regressions.py scripts/check_swarm_supply_regressions.py tests/test_swarm_regressions.py tools/check_delivery.py tools/spring_review_gate.py tools/package_spring_review.py tests/test_delivery_gate.py tests/test_spring_review_gate.py tests/test_spring_package.py; do
  check "$swarm" "$file"
done
check "$garden" prototypes/garden-puzzles/project.godot .github/workflows/garden-puzzles.yml
check "$(expected false true false routes true false false false)" scripts/check_swarm_supply_regressions.py godot/playtest/year/year_model.gd
check "$(expected true false false routes true false false false)" tools/package_spring_review.py src/app/page.tsx
check "$(expected false false false routes true true true false)" prototypes/swarm-flight/main.gd prototypes/flower-step/main.gd prototypes/garden-puzzles/main.gd
check "$routes" godot/playtest/year/year_model.gd godot/tests/year_route_test.gd docs/design/year-play-matrix.md
check "$engine" scripts/run_with_timeout.py godot/tests/smoke_test.gd
check "$shared" godot/fonts/font.otf godot/scripts/player/bee_player.gd godot/assets/music/autumn_explore.wav godot/assets/audio/commercial/handoff.wav
check "$web" src/app/page.tsx app/article.mdx tests/prepare-web-export.test.mjs
check "$legacy" godot/project.godot scripts/prepare_web_export.mjs package.json
check "$full" scripts/unknown.sh
check "$full" prototypes/some-other-game/project.godot
check "$full" godot/unknown.gd
check "$full" .github/workflows/desktop-build.yml
[[ "$(bash "$root/scripts/classify_ci_changes.sh" </dev/null)" == "$full" ]]
printf 'CI SCOPE TEST PASSED\n'

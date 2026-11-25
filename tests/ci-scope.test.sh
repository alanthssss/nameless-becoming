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
  local swarm_suite=${9:-none}
  if [[ "$5" == true && "$#" == 8 ]]; then swarm_suite=full; fi
  printf 'web=%s\ngodot=%s\nexport_game=%s\ngodot_suite=%s\nswarm=%s\nflower=%s\ngarden=%s\ncontent=%s\nswarm_suite=%s' "${@:1:8}" "$swarm_suite"
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
check "$full" scripts/ci_reuse.py
check "$full" tests/test_ci_reuse.py
check "$full" scripts/check_ci_evidence.py
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
region=$(expected false false false routes true false false false region)
snapshot=docs/production/evidence/honey-stamina-419/native-dials.png
regional_ui=prototypes/swarm-flight/region_game/ui.gd
shared_view=prototypes/swarm-flight/world_view.gd
check "$light" "$snapshot" docs/production/evidence/a/b/screenshot.jpeg docs/production/evidence/a/native.log docs/production/honey-music/growth-journal-dizi-jianpu.pdf
check "$region" "$regional_ui" prototypes/swarm-flight/region_game/ui.gd.uid "$snapshot"
check "$swarm" "$snapshot" "$regional_ui" "$shared_view"
check "$swarm" "$shared_view" "$regional_ui"
check "$swarm" prototypes/swarm-flight/region_game/review-contract.json prototypes/swarm-flight/region_game/review-readme.txt
check "$light" docs/production/evidence/trip/receipt.json
check "$light" docs/production/evidence/trip/events.jsonl
# Same file format, different consumers: discussion, regional game, shared game and site.
discussion=docs/art/honey-courtyard-house-concepts-427.jpg
raw_art=docs/art/honey-basin-visitors-429.png
regional_fish=prototypes/swarm-flight/art/basin-fish.webp
check "$light" "$discussion" docs/art/honey-basin-green-koi-native.jpg docs/art/discussion/new/plan.webp
check "$light" docs/design/concepts/target.png docs/design/screenshots/menu.png docs/design/region-map-drafts/pond.svg
check "$light" docs/design/region-map-drafts/pond.json docs/production/nectar-demo-024-evidence.json
check "$light" docs/research/shelldiver-atlas/windows-route-costs.csv docs/research/shelldiver-evidence-ledger.json
check "$light" docs/art/nectar-demo-art-review.json docs/art/nectar-oblique-preview/courtyard.png docs/art/nectar-oblique-preview/manifest.json
check "$region" "$raw_art" docs/art/collection-fields/pond-source.png docs/art/collection-fields/pond-registration.json docs/art/collection-fields/register.py
check "$region" prototypes/swarm-flight/art/region-water.png.import prototypes/swarm-flight/art/region-ground.png
check "$region" "$regional_fish" "$regional_fish.import" prototypes/swarm-flight/region_game/basin_pigment.gdshader.uid
check "$region" prototypes/swarm-flight/region_game/music/growth_journal_dizi.ogg.import prototypes/swarm-flight/region_game/hub_depth.svg
check "$region" docs/design/honey-growth-tree-v2.json "$discussion"
check "$region" "$discussion" "$regional_fish"  # Moving between runtime and documentation must retain coverage.
check "$region" "$regional_fish" "$discussion"
check "$swarm" "$regional_fish" prototypes/swarm-flight/art/honey-bee.png "$discussion"
check "$flower" "$discussion" prototypes/flower-step/icon.png
check "$garden" prototypes/garden-puzzles/tiles.png "$discussion"
check "$web" "$discussion" public/demo.jpg
check "$content" "$discussion" marketing/key-art/cover.png
check "$shared" "$discussion" godot/assets/art/commercial/target.png scripts/commercial_audio_sources.json
check "$legacy" godot/campaign.tscn godot/journey.tscn godot/bootstrap.tscn
check "$full" docs/art/unclassified/new.png
check "$full" docs/art/collection-fields/new-input.bin
check "$full" docs/design/concepts/renderer.py
check "$full" docs/research/shelldiver-atlas/nectar_choice.gd
check "$full" docs/production/evidence/trip/new-tool.py
check "$full" docs/production/other/native.png
check "$full" "$regional_ui" scripts/unknown.sh
check "$full" scripts/unknown.sh "$regional_ui"
check "$full" scripts/unknown.sh
check "$full" prototypes/some-other-game/project.godot
check "$full" godot/unknown.gd
check "$full" .github/workflows/desktop-build.yml
[[ "$(bash "$root/scripts/classify_ci_changes.sh" </dev/null)" == "$full" ]]
printf 'CI SCOPE TEST PASSED\n'

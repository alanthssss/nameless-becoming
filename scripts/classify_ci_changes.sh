#!/usr/bin/env bash
set -euo pipefail
# The only path-to-check mapping. Input is NUL-delimited, including deletions
# and both sides of renames. Unknown paths/history fail broad, never silently skip.
count=0
web=false; godot=false; export_game=false; suite=routes
swarm=false; flower=false; garden=false; content=false
full() {
  web=true; godot=true; export_game=true; suite=full
  swarm=true; flower=true; garden=true; content=true
}
while IFS= read -r -d '' path; do
  count=$((count + 1))
  case "$path" in
    .github/workflows/quality.yml|scripts/classify_ci_changes.sh|scripts/ci_scope.sh|scripts/check_ci_results.py|scripts/lint_workflows.sh|tests/ci-scope.test.sh|tests/test_ci_routing.py)
      full ;;
    prototypes/swarm-flight/*|.github/workflows/swarm-flight.yml|scripts/check_swarm_regressions.py|scripts/check_swarm_supply_regressions.py|tests/test_swarm_regressions.py|tools/check_delivery.py|tools/spring_review_gate.py|tools/package_spring_review.py|tests/test_delivery_gate.py|tests/test_spring_review_gate.py|tests/test_spring_package.py)
      # Evidence includes JSON fixtures loaded by leaf_canopy_verify.gd.
      swarm=true ;;
    prototypes/flower-step/*|.github/workflows/flower-step.yml)
      flower=true ;;
    prototypes/garden-puzzles/*|.github/workflows/garden-puzzles.yml)
      garden=true ;;
    godot/project.godot|godot/export_presets.cfg|godot/commercial_title.tscn|godot/main.tscn|scripts/build_web_game.sh|scripts/prepare_web_export.mjs|scripts/verify_godot_export_contents.sh|scripts/create_commercial_godot_stage.mjs|scripts/generate_build_provenance.mjs|package.json|package-lock.json)
      web=true; godot=true; export_game=true; suite=full ;;
    godot/playtest/*|godot/tools/spring_*|godot/tools/rain_*|godot/tools/year_*|godot/tools/capture_spring.gd|godot/tests/spring_*|godot/tests/rain_*|godot/tests/bee_social_*|godot/tests/year_*|scripts/play_spring.command|scripts/play_year.command|scripts/play_year_film.command|scripts/audit_year_content.py|scripts/profile_year.sh|docs/design/year-play-matrix.md)
      godot=true ;;
    godot/fonts/*|godot/scripts/*|godot/assets/*|godot/world/*|godot/data/*)
      # Node tests also inspect audio hashes, game copy and exported asset closure.
      web=true; godot=true; suite=full ;;
    godot/tests/*|scripts/test_godot.sh|scripts/run_with_timeout.py)
      godot=true; suite=full ;;
    README.md|marketing/*|docs/STEAM_NEXT_FEST_2026_PLAN.md|docs/ART_REVIEW_HANDOFF.md|docs/design/commercial-product-requirements.md|docs/design/solar-term-campaign-production-spec.md|docs/design/narrative-framework.md|docs/design/art-source-register.md)
      # These documents/assets are inputs to existing Node copy/material tests.
      # They need no npm install, site build or engine export on their own.
      content=true ;;
    src/*|app/*|public/*|tests/*.mjs|*.config.*|tsconfig.json|wrangler.*)
      web=true ;;
    *.md|*.mdx|*.markdown|*.MD|*.MDX|*.MARKDOWN)
      ;;
    *) full ;;
  esac
done
if [[ "$count" -eq 0 ]]; then full; fi
printf 'web=%s\ngodot=%s\nexport_game=%s\ngodot_suite=%s\nswarm=%s\nflower=%s\ngarden=%s\ncontent=%s\n' \
  "$web" "$godot" "$export_game" "$suite" "$swarm" "$flower" "$garden" "$content"

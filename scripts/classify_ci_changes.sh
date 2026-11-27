#!/usr/bin/env bash
set -euo pipefail
# The only path-to-check mapping. Input is NUL-delimited, including deletions
# and both sides of renames. Unknown paths/history fail broad, never silently skip.
count=0
web=false; godot=false; export_game=false; suite=routes
swarm_suite=none; flower=false; garden=false; content=false
full() {
  web=true; godot=true; export_game=true; suite=full
  swarm_suite=full; flower=true; garden=true; content=true
}
# A directory records the role of an attachment. Bash '*' also matches '/',
# so compare the parent explicitly before treating a loose art image as a note.
review_attachment() {
  local parent=${1%/*} ext=${1##*.}
  case "$parent" in
    docs/art|docs/art/discussion|docs/art/discussion/*|docs/art/nectar-oblique-preview|\
      docs/design/concepts|docs/design/screenshots|docs/design/region-map-drafts)
      case "$ext" in png|PNG|jpg|JPG|jpeg|JPEG|webp|WEBP|svg|SVG) return 0 ;; esac ;;
    docs/research|docs/research/*)
      case "$ext" in csv|json|jsonl|png|jpg|jpeg|webp|svg) return 0 ;; esac ;;
  esac
  return 1
}

# The pond preview inherits the regional renderer and is covered in the same job.
regional_resource() {
  local file=${1%.import}
  file=${file%.uid}
  case "$file" in
    region_game/*.gd|region_game/*.gdshader|region_game/*.gdshaderinc|\
      region_game/*_depth.svg|region_game/music/*.ogg|region_game/art-provenance.json)
      return 0 ;;
    art/region-ground.png|art/region-water.png|art/basin-fish.webp|art/basin-frog.webp|\
      art/collection-pond.webp|art/collection-meadow.webp|art/collection-blue-bloom.webp|art/collection-violet-bloom.webp|\
      art/collection-fiber-source.webp|art/collection-resin-source.webp|art/collection-home-sign.webp|\
      art/honey-inner-courtyard.webp|art/honey-steelyard-goods.webp|art/honey-flight-sheet-meadow.webp|art/honey-flight-sheet-pond.webp)
      return 0 ;;
  esac
  return 1
}

while IFS= read -r -d '' path; do
  count=$((count + 1))
  case "$path" in
    .github/workflows/quality.yml|scripts/classify_ci_changes.sh|scripts/ci_scope.sh|scripts/check_ci_evidence.py|scripts/check_ci_results.py|scripts/ci_reuse.py|scripts/lint_workflows.sh|tests/ci-scope.test.sh|tests/test_ci_routing.py|tests/test_ci_reuse.py)
      full ;;
    docs/art/collection-fields/*-source.png|docs/art/collection-fields/collection-home-sign.png|\
      docs/art/collection-fields/*-registration.json|docs/art/collection-fields/register.py|docs/art/honey-basin-visitors-429.png|\
      docs/design/honey-growth-tree-v2.json|tools/sync_honey_native_growth_catalog.py|tools/split_honey_courtyard.py)
      # Editable inputs of the regional runtime, even when kept alongside notes.
      if [[ "$swarm_suite" == none ]]; then swarm_suite=region; fi ;;
    prototypes/swarm-flight/README.md|prototypes/flower-step/README.md|prototypes/garden-puzzles/README.md)
      ;;
    prototypes/swarm-flight/*)
      if regional_resource "${path#prototypes/swarm-flight/}"; then
        if [[ "$swarm_suite" == none ]]; then swarm_suite=region; fi
      else
        swarm_suite=full
      fi ;;
    .github/workflows/swarm-flight.yml|scripts/check_swarm_regressions.py|scripts/check_swarm_supply_regressions.py|tests/test_swarm_regressions.py|tools/check_delivery.py|tools/spring_review_gate.py|tools/package_spring_review.py|tests/test_delivery_gate.py|tests/test_spring_review_gate.py|tests/test_spring_package.py)
      swarm_suite=full ;;
    prototypes/flower-step/*|.github/workflows/flower-step.yml)
      flower=true ;;
    prototypes/garden-puzzles/*|.github/workflows/garden-puzzles.yml)
      garden=true ;;
    godot/project.godot|godot/export_presets.cfg|godot/commercial_title.tscn|godot/main.tscn|godot/bootstrap.tscn|godot/campaign.tscn|godot/journey.tscn|scripts/build_web_game.sh|scripts/prepare_web_export.mjs|scripts/verify_godot_export_contents.sh|scripts/create_commercial_godot_stage.mjs|scripts/generate_build_provenance.mjs|package.json|package-lock.json)
      web=true; godot=true; export_game=true; suite=full ;;
    godot/playtest/*|godot/tools/spring_*|godot/tools/rain_*|godot/tools/year_*|godot/tools/capture_spring.gd|godot/tests/spring_*|godot/tests/rain_*|godot/tests/bee_social_*|godot/tests/year_*|scripts/play_spring.command|scripts/play_year.command|scripts/play_year_film.command|scripts/audit_year_content.py|scripts/profile_year.sh|docs/design/year-play-matrix.md)
      godot=true ;;
    godot/fonts/*|godot/scripts/*|godot/assets/*|godot/world/*|godot/data/*|scripts/commercial_audio_sources.json)
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
    docs/production/evidence/*.png|docs/production/evidence/*.jpg|docs/production/evidence/*.jpeg|docs/production/evidence/*.webp|docs/production/evidence/*.log|docs/production/evidence/*.json|docs/production/evidence/*.jsonl|docs/production/honey-music/growth-journal-dizi-jianpu.pdf)
      # Archived review outputs. ci_scope.sh validates changed structured receipts.
      ;;
    docs/art/collection-fields/pond-guide.png|docs/art/collection-fields/meadow-guide.png|\
      docs/art/collection-fields/prompts.json|docs/art/collection-fields/retouch-prompts.json|docs/art/collection-fields/far-retouch.txt|\
      docs/art/nectar-demo-art-review.json|docs/art/nectar-oblique-preview/manifest.json|docs/design/region-map-drafts/*.json|\
      docs/production/nectar-demo-023-evidence.json|docs/production/nectar-demo-024-evidence.json)
      # Documentation inputs and records; ci_scope.sh checks structured documents.
      ;;
    *.md|*.mdx|*.markdown|*.MD|*.MDX|*.MARKDOWN)
      ;;
    *) if ! review_attachment "$path"; then full; fi ;;
  esac
done
if [[ "$count" -eq 0 ]]; then full; fi
swarm=false
if [[ "$swarm_suite" != none ]]; then swarm=true; fi
printf 'web=%s\ngodot=%s\nexport_game=%s\ngodot_suite=%s\nswarm=%s\nflower=%s\ngarden=%s\ncontent=%s\nswarm_suite=%s\n' \
  "$web" "$godot" "$export_game" "$suite" "$swarm" "$flower" "$garden" "$content" "$swarm_suite"

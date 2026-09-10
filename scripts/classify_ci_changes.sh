#!/usr/bin/env bash
set -euo pipefail
# NUL paths, including both sides of renames. Unknown/missing scope fails broad.
count=0
web=false
godot=false
export_game=false
suite=routes
while IFS= read -r -d '' path; do
  count=$((count + 1))
  case "$path" in
    godot/project.godot|godot/export_presets.cfg|godot/commercial_title.tscn|godot/main.tscn|scripts/build_web_game.sh|scripts/verify_godot_export_contents.sh|scripts/create_commercial_godot_stage.mjs|scripts/generate_build_provenance.mjs)
      web=true; godot=true; export_game=true; suite=full ;;
    godot/playtest/*|godot/tools/spring_*|godot/tools/rain_*|godot/tools/year_*|godot/tools/capture_spring.gd|godot/tests/spring_*|godot/tests/rain_*|godot/tests/bee_social_*|godot/tests/year_*|scripts/play_spring.command|scripts/play_year.command|scripts/audit_year_content.py|scripts/profile_year.sh)
      godot=true ;;
    godot/fonts/*|godot/tests/*|godot/scripts/*|godot/assets/*|godot/world/*)
      godot=true; suite=full ;;
    godot/data/*)
      web=true; godot=true; suite=full ;;
    scripts/test_godot.sh|scripts/run_with_timeout.py)
      godot=true; suite=full ;;
    src/*|app/*|public/*|tests/*.mjs|package.json|package-lock.json|*.config.*|tsconfig.json|wrangler.*)
      web=true ;;
    .github/workflows/quality.yml|scripts/classify_ci_changes.sh|tests/ci-scope.test.sh|*.md|*.mdx|*.markdown|*.MD|*.MDX|*.MARKDOWN)
      ;;
    *) web=true; godot=true; export_game=true; suite=full ;;
  esac
done
if [[ "$count" -eq 0 ]]; then
  web=true; godot=true; export_game=true; suite=full
fi
printf 'web=%s\ngodot=%s\nexport_game=%s\ngodot_suite=%s\n' "$web" "$godot" "$export_game" "$suite"

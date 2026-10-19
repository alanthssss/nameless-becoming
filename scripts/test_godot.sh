#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin=$GODOT_BIN
elif command -v godot >/dev/null 2>&1; then
  godot_bin=$(command -v godot)
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin=$(command -v godot4)
else
  echo "Godot 4.6.2 was not found. Set GODOT_BIN or add godot to PATH." >&2
  exit 127
fi

echo "Using $("$godot_bin" --version)"

node "$project_root/scripts/generate_build_provenance.mjs"

run_with_timeout() {
  python3 "$project_root/scripts/run_with_timeout.py" 90 "$@"
}

if [[ -f "$project_root/scripts/audit_year_content.py" ]]; then
  python3 "$project_root/scripts/audit_year_content.py" --check
fi

echo "Preparing Godot imports and global class cache"
import_log="$project_root/godot/.godot/import-test.log"
mkdir -p "$(dirname "$import_log")"
run_with_timeout \
  "$godot_bin" \
  --path "$project_root/godot" \
  --headless \
  --log-file "$import_log" \
  --import
if grep -q "SCRIPT ERROR:" "$import_log"; then
  echo "Godot import emitted SCRIPT ERROR; inspect $import_log" >&2
  exit 1
fi

test_files=(bee_social_test.gd spring_route_test.gd spring_persistence_test.gd rain_route_test.gd rain_chapter_test.gd rain_calendar_persistence_test.gd smoke_test.gd playtest_ticket_validator_test.gd playtest_bootstrap_test.gd playtest_save_isolation_test.gd commercial_persistence_test.gd evade_runtime_test.gd b01_evade_slice_test.gd flow_test.gd fix_boss_term_test.gd music_test.gd commercial_audio_test.gd journey_audio_director_test.gd journey_solar_term_chronicle_test.gd journey_level_catalog_test.gd journey_event_matrix_runtime_test.gd journey_campaign_state_test.gd campaign_systemic_contract_test.gd boss_encounter_director_test.gd season_mechanics_test.gd relay_hive_test.gd mentor_tutorial_test.gd hud_responsive_test.gd journey_campaign_hud_test.gd journey_world_test.gd)
if [[ "${GODOT_TEST_SCOPE:-full}" == routes ]]; then
  test_files=(bee_social_test.gd spring_route_test.gd spring_persistence_test.gd rain_route_test.gd rain_chapter_test.gd rain_calendar_persistence_test.gd)
fi
for year_test in "$project_root"/godot/tests/year_*_test.gd; do
  if [[ -f "$year_test" ]]; then test_files+=("$(basename "$year_test")"); fi
done
for test_file in "${test_files[@]}"; do
  echo "Running $test_file"
  test_log="$project_root/godot/.godot/${test_file%.gd}.log"
  test_command=(
    "$godot_bin"
    --path "$project_root/godot"
    --headless
    --log-file "$test_log"
    --script "res://tests/$test_file"
  )
  run_with_timeout "${test_command[@]}"
  # Godot may exit 0 when a --script fails to parse, so the process status alone
  # is not a sufficient test result. Every test owns an explicit success marker.
  if grep -q "SCRIPT ERROR:" "$test_log"; then
    echo "$test_file emitted SCRIPT ERROR; inspect $test_log" >&2
    exit 1
  fi
  if ! grep -q "TEST PASSED" "$test_log"; then
    echo "$test_file did not report TEST PASSED; inspect $test_log" >&2
    exit 1
  fi
done

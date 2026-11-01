# Known-answer driver handoff

Production implementation tested before parent commit `9611660f0acfabc53ddf92c5215b37d7942cfc89`; all ten source hashes match that commit. Use the final parent-provided SHA for native runs; neither these dry runs nor their old revision labels are relabelled as later executions.

- A: `route_a.gd`, full observation/feed → upper shield → deliberate upward wind entry → share, real menus and disk/scene cold resume. Fast headless 107/0, 6554 model ticks, 109.233 seconds. One explicitly intentional R after first opening, no automatic recovery.
- B: `route_b.gd`, skip feed → low route → ordinary back route → no share, same real menu/disk coverage. Fast headless 98/0, 5952 ticks, 99.200 seconds. Zero recovery, zero wind contact. Original first launch remains2190,465.
- Both use ordinary InputEventKey events; neither seeds position/opening facts for the complete route. Target-arrival settle waits are6ticks. Native draws one frame per2 model ticks at1/60 simulation. Rendering-only screenshot waits add frames without advancing the model; approximate movies are110 and100seconds plus scene/photo overhead.
- `SWARM_DRY_FAST=1` only skips per-sample rendering waits when DisplayServer is headless. It does not replace native per-frame UI/render verification. A's initial fast-run trace omitted the mode field; `dry-a-wind-final/run-mode.json` records the actual command/mode without rewriting its trace. Current A/B scripts include the mode field.
- `cold_resume` recreates the scene and reads actual disk via actual menu; it is not a separate executable/process restart. Parent owns packaged launch/relaunch coverage.
- C has been handed to root; do not overwrite or infer its results here. Previous C partial renderer failure is retained.

Native invocation (replace `FINAL_SHA`, choose a fresh isolated folder; do not set `SWARM_DRY_FAST`):

```sh
SWARM_PRODUCTION_REVISION=FINAL_SHA SWARM_SPRING_QA_DIR=/private/tmp/pond-mvp-native-a \
  '/Applications/Godot 2.app/Contents/MacOS/Godot' \
  --path /private/tmp/nameless-pond-mvp-candidate/prototypes/swarm-flight \
  --script /private/tmp/pond-mvp-final-drivers/route_a.gd \
  --write-movie /private/tmp/pond-mvp-native-a.avi --fixed-fps 30
```

Use route_b.gd with separate output/save/movie paths for B. Parent is responsible for native window, final source freeze and export. These are developer known-answer checks, not first-time exploration, subjective listening or product acceptance.

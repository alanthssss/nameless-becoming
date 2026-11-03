# NH-RG / 0.21 independent review — final limited review

Reviewer: `/root/nectar_regions_independent_review`, independent of implementation authors. Scope: M3 #285 / GDD§13.8 / NH-RG-v1. Reviewed working tree `/private/tmp/nameless-nectar-region-mvp`, branch `codex/nectar-region-mvp`, base `fdb042d`. Initial review was performed before freeze. Final follow-up reviewed freeze `28d7e8295411471e916deca50d775227a06113c1` / PR #287; details and evidence boundaries are recorded below. This is code review, independent targeted developer probing, and inspection of developer-generated native screenshots, not uncoached or external human playtesting.

## Findings and resolution

1. **P2 — Focus loss during a scene transition resumed the field in the background.** `_notification` previously paused only `mode == play`, while `_advance_transition` always returned to play. An independent headless scene probe invoked ordinary transition APIs and a focus-loss notification during fade, then advanced one second. It reproduced `area=pond`, `mode=play`, `energy=84.51/85` despite empty controls. Source fix adds `pause_after_transition`, completing successful/failed transitions into pause and requiring explicit continuation. The same independent probe on the fix returned `mode=pause`, `energy=85/85`, empty controls. Resolved in reviewed working tree.
   - Original reproduction: `focus_probe.gd`, `focus-result.json`, `focus.log`.
   - Fix verification: `focus_fixed_probe.gd`, `focus-fixed-result.json`, `focus-fixed.log`.
   - These scripts create isolated saves under this temporary review directory, never the real shared player profile.
2. **Route-label occlusion and clipping.** Earlier native screenshots showed the right-hand route title under a flower stem/leaf and the lock-condition caption extending beyond the viewport. Root moved the gate labels after flowers/creatures; `region-ui-fixed/02-pond-entry.png` confirms the main title is readable. The subtitle in that capture predates root's additional clamp change; final fresh screenshot must confirm the complete caption. The final frozen `evidence/region-ui/02-pond-entry.png` has now been inspected: both title and subtitle are visible inside the viewport. Resolved in final capture; the older capture is not retrospectively counted as passing.
3. The initial `region-ui/region-ui-result.json` contained two failed targeted fixture assertions (warning and contact). Its warning screenshot had no warning. Root corrected the positioning/timing fixture to approach the live creature position and await the observable hit. Reviewed `region-ui-fixed/region-ui-result.json` is **21 checks / 0 failures**; `03-warning.png` visibly shows the warning marker and arc. Preserve the failed round and do not count it as a pass.

## Independent technical review

Read AGENTS, the NH-RG design, model, encounter state machine, frozen legacy validator, migration boundary, scene driver, UI/view, targeted tests, export filtering, package schema change, and CI/contract diff. No additional actionable P1/P2 found in the reviewed worktree after the focus fix, subject to the final label capture and final frozen-media review.

Observed design/code relationships:
- hub/pond/meadow have separate PackedScene instances and valid explicit adjacency; player movement cannot silently enter another area.
- Hub functions use disjoint interaction ranges; shop and growth require their respective points in the scene driver. Destination selection exposes locked meadow rather than silently selecting it.
- Transition candidates retain the original live state until atomic persistence succeeds; failure returns to the original area with a visible message. Successful transitions clear velocity/charge/burst, load the matching scene, and preserve current-trip stock/population except an actual hub departure.
- Safe entrances, finite population, warning before pursuit, leash/disengagement, global hurt protection, dash priority, and no enemy currency/drop creation match the stated adaptation. Inactive region creatures freeze. The shortcut still reaches meadow's far section and changes return travel despite the direct destination option.
- v1/v2 are validated using a frozen old-schema model before exact-byte backup and v3 conversion. Current transactions accept v3 only. Economic values/flower stocks survive; added creatures are gone for the migrated trip. Invalid/unknown metadata is rejected before live state mutation.
- The package contract retains NH-C01–08 and adds region/scene expectations; v3 save identity is required. Export filters exclude `_verify.gd` and `_probe.gd`, while runtime legacy validation remains included.
- Shelldiver research explicitly separates author statements/screenshots from our algorithm/parameters, and does not claim undisclosed spawn rates or exact internal generation code. No source assets were copied into this change.

## Independent probe beyond author tests

`state_probe.gd` performs **24,000 deterministic model frames**, including alternating region starts, controlled positions around creature habitats, varied movement, collect/charge/release, contact, depletion and rescue; every 11 frames it JSON-roundtrips into a fresh strict v3 model. **2,182 checks / 0 failures** (`state-result.json`, `state.log`). This is a deliberately positioned model stress fixture. It verifies serializable reachable state under its exercised inputs; it does not measure player behavior, fun, difficulty, or complete visual quality.

## Native image inspection completed

Actual images inspected via image viewer:
- Initial `native-ui/02-first-garden.png`, `02b-destination-board.png`, `03-harvesting.png`, `10-purple-meadow.png` from root's developer UI run. The courtyard has three distinct visual/function addresses, readable full-screen destination choices, and an independent field presentation. Earlier gate-label defects were recorded above.
- `region-ui/02-pond-entry.png`, `03-warning.png`, `04-repel-flight.png` from the failed fixture run; the no-warning state was explicitly recognized as failure.
- `region-ui-fixed/02-pond-entry.png`, `03-warning.png`, `07-small-destinations.png`; the fixed warning is visible and the 960×600 destination panel retains readable destination/cancel controls.
- Read root's pre-freeze ordinary-input shortcut result: **144 checks / 0 failures**, 163.7 game seconds, six purchases with 426 earned / 397 spent. This is a known-route developer recording, not independent navigation. Continuous video and final frozen replay have not yet been reviewed by this reviewer.

## Interim handoff (superseded by follow-up below)

Root will provide the frozen SHA, final fresh gate-label frames, both same-version continuous route media and associated receipts. Recheck the final delta and sampled motion/transition/encounter evidence before promoting this interim review to final limited acceptance. Native export launch, actual shared-profile isolation, CI, final packaging and user acceptance are outside this interim review's completed scope and must be reported separately.


## Final frozen-source follow-up — 2026-11-03

**Conclusion:** no remaining actionable P1/P2 found in this limited final review. The focus-loss defect and gate-label defects are resolved in the reviewed source/captures. This supports handing over the 0.21 candidate for user playtesting; it does not establish player enjoyment, validate the intended long-term pacing, or close a product milestone/user acceptance by itself.

### Source and provenance

- HEAD is `28d7e8295411471e916deca50d775227a06113c1`; tracked source was clean when checked. Independently hashed all **31 files** listed by `evidence/frozen-source-manifest.json` and compared each with both current worktree bytes and `git show 28d7e829:<path>`: all match. Receipt: `frozen-source-check.json`. This manifest covers the enumerated changed files; it is not a claim to have rehashed every pre-existing asset or every exported binary.
- Read author source/rules/export records. Rules/migration/regions/legacy/packager recorded exit 0. The export record declares ZIP SHA-256 `f900be1d16d39c1eff3c5edde3ebd0c745e65156542bc8379699a6c470156534`, but this reviewer has not independently launched or verified that packaged app/ZIP. Export launch, profile isolation, packaging acceptance, CI, and final issue bookkeeping remain the root's evidence responsibility.
- Independently verified the SHA-256 of final `region-ui`, `shortcut`, and `twin` MP4 files against their `video-integrity.json` receipts. Independently decoded each full MP4 video stream to a null sink using the static FFmpeg binary: exit 0 and **211 / 5,631 / 8,768 frames** respectively. Logs: `region-ui-independent-decode.log`, `shortcut-independent-decode.log`, `twin-independent-decode.log`. Decode success proves stream integrity; it is not full visual or audio review. Route scripts record 5,627 / 8,764 active script frames; four teardown video frames are additional.
- Permanent evidence root used: `/Users/alanthssss/Library/CloudStorage/SynologyDrive-on-demand-sync/ChatGPT/nameless-becoming/outputs/nectar-harvest-0.21.0/evidence`.

### Two purchase routes and persistence

Independently compared purchase plans, confirmed-purchase trace entries, economic totals, frame state sequences, and events in the author's known-route native input recordings:

| Route | Purchase sequence | Checks | Earned / spent / remaining | Full cargo sales | Area changes | Hits | Lowest energy |
|---|---|---:|---|---:|---:|---:|---:|
| shortcut | gather1 → bag1 → gather2 → meadow → shortcut → reserve | 144 / 0 failed | 426 / 397 / 29 | 9 | 24 | 4 | 51.13 |
| twin | gather1 → reach → gather2 → meadow → twin → reserve | 229 / 0 failed | 468 / 447 / 21 | 16 | 38 | 0 | 76.04 |

Both recorded successful completion and no forced rescue. All six purchase costs and coin deltas agree with event records; earned minus spent equals final coins. The twin trace records both `rose_0` and `rose_1` dropping stock 16 → 15 at script frame 6,990 after the twin purchase, consistent with the displayed double-source harvest. Shortcut events/positions and sampled video show pond → far meadow and meadow → pond returns through the shortcut rather than ordinary entrance relocation. The normal shortcut route did not record a repel; the separate positioned region fixture provides that evidence.

Cold continuation records are **3 checks / 0 failures each**. Independently compared `save-before.json` to `cold-loaded.json` recursively, including creatures, flower stock, cargo, area, position, and economy, using 1e-7 absolute numeric tolerance: no differences. `save-after.json` intentionally describes the later continued movement and is not the cold load snapshot. Receipt: `cold-independent-check.json`. Known routes are author-controlled ordinary inputs, not independent player navigation or an unbiased comparison of branch efficiency; the 163.7 / 254.57 active game seconds cannot establish preferred balance or player completion time.

### Scene, encounter, and UI observations

- Final author native UI result is **59 / 0**, region UI **21 / 0**. Read the targeted probe source and event/state trace. Cancel returns to hub without travel; failed persistence leaves pond unchanged; successful fades commit matching area; focus loss during fade ends paused with energy 85 through trace indices 186–206 until explicit resume.
- Region fixture trace shows patrol → warn (52–66) → gone (67–96) after dash/repel; the later warn/chase/contact sequence deliberately reintroduces the insect as a second fixture. The latter is not spontaneous same-trip respawn. Recorded events contain dash then repel, and a separate 8-energy hurt event. The freeze has visible warning arc/mark, fly-away feedback, and hurt energy reduction; the root's sample is a positioned developer fixture using ordinary keyboard interaction.
- Independently inspected final screenshots: `ui/02-first-garden.png` at 1280×800; `ui/08-small-tree.png`, `ui/09-small-shop.png`, and `region-ui/07-small-destinations.png` at 960×600; `region-ui/02-pond-entry.png`, `03-warning.png`, `04-repel-flight.png`; `twin/08b-two-source-harvest.png`. The three hub function addresses are distinct; destination/lock/cancel text and growth/shop controls remain visible at 960. No final 640-wide capture was supplied or inspected; no 640 support claim is made.
- `ui-initial-fixedfps` is a preserved failed fixture: fixed simulation rate outran wall-clock input debounce. It is not the final 59/0 real-time UI run and is not counted as passing.

### Exact visual sampling boundary

The following **zero-based raw MP4 frame indices** were extracted into contact sheets and actually inspected. Script trace frame numbers can have initialization offsets; no exact one-to-one frame identity is inferred merely from similarly numbered script events.

| MP4 | Raw frame indices inspected | What was checked |
|---|---|---|
| region-ui | 0–210, step 6 (36 frames) | cancel, fade, failed transition, warning, fly-away, separate contact fixture, return, small destination UI, focus pause |
| shortcut | 60–84 step 2; 3558–3578 step 2; 4208–4232 step 2; 4238–4266 step 2; 4440–4464 step 2; 5448–5472 step 2 (78 frames) | first departure, normal meadow gate, shortcut outward travel, visible hit/energy reduction, loaded return, reserve completion |
| twin | 6638–6666 step 2; 6960–7016 step 4; 8400–8428 step 2; 8584–8612 step 2 (60 frames) | purchase, double harvest and full cargo, return selector/fade to hub, completion |

These are **174 sampled frames**, not an uninterrupted viewing of all three videos. Unsampled moments, audio, subjective motion comfort, first-time understanding, pacing fatigue, and branch desirability remain unreviewed here. Contact sheets are saved in this review directory with matching `shortcut-*`, `twin-*`, and `region-frames-0-210-step6.png` names. The model stress test and focus regression remain independent probes; the native media remains author-recorded evidence inspected by this reviewer. No native Godot window was started during this follow-up, and no implementation source was changed.


### Additional read-only export-entry check

At root's request, inspected `boot.gd`, `project.godot`, the Nectar export preset, `nectar_harvest_main.gd` input handlers and `nectar_harvest_ui.gd` title button wiring. Both `--nectar-harvest` and custom feature `nectar_mvp` select the same `nectar_harvest.tscn`. The title's native Button is connected to `start_game` and grabs focus in `show_mode`; Enter uses ordinary Godot UI acceptance. There is no export-only input branch. `--nectar-qa` only bypasses application-focus-out pausing, not title button behavior. No source-level entry difference was found that explains root's reported CUA window targeting/input problem. This is not evidence that native OS input reaches the packaged app: the final exported-app ordinary-input check remains unverified by this reviewer and must not be replaced by source probes. The root-reported multi-minute FileAccess stall is also outside this review's reproduced findings; its cause is not established here.

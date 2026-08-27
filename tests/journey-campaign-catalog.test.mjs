import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const catalogPath = resolve(repositoryRoot, "godot/data/journey_levels.json");
const chroniclePath = resolve(repositoryRoot, "godot/data/journey_solar_term_chronicles.json");

const seasons = ["spring", "summer", "autumn", "winter"];
const expectedTermIds = [
  "spring_lichun",
  "spring_yushui",
  "spring_jingzhe",
  "spring_chunfen",
  "spring_qingming",
  "spring_guyu",
  "summer_lixia",
  "summer_xiaoman",
  "summer_mangzhong",
  "summer_xiazhi",
  "summer_xiaoshu",
  "summer_dashu",
  "autumn_liqiu",
  "autumn_chushu",
  "autumn_bailu",
  "autumn_qiufen",
  "autumn_hanlu",
  "autumn_shuangjiang",
  "winter_lidong",
  "winter_xiaoxue",
  "winter_daxue",
  "winter_dongzhi",
  "winter_xiaohan",
  "winter_dahan",
];
const expectedClimaxes = [
  { id: "spring_guyu", order: 5, sceneKey: "spring_climax" },
  { id: "summer_dashu", order: 11, sceneKey: "summer_climax" },
  { id: "autumn_shuangjiang", order: 17, sceneKey: "autumn_climax" },
  { id: "winter_dahan", order: 23, sceneKey: "winter_climax" },
];
const requiredLevelKeys = [
  "dialogue",
  "energy_drain",
  "hazard",
  "id",
  "intro",
  "kind",
  "map_variant",
  "objectives",
  "order",
  "reward_honey",
  "scenario_id",
  "scene_key",
  "season_id",
  "target_minutes",
  "time_limit_seconds",
  "world_trace",
];
const allowedObjectiveTypes = new Set([
  "anchor",
  "carry",
  "climax",
  "collect",
  "event",
  "frighten",
  "observe",
  "pollinate",
  "repair",
  "seed",
  "shell",
  "warmth",
]);

async function readJson(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

function assertNonEmptySingleLine(value, label) {
  assert.equal(typeof value, "string", `${label} must be a string`);
  assert.equal(value, value.trim(), `${label} may not have surrounding whitespace`);
  assert.ok(value.length > 0, `${label} may not be empty`);
  assert.doesNotMatch(value, /[\r\n]/u, `${label} must stay on one line`);
}

test("24-level campaign catalog is an exact one-to-one solar-term sequence", async () => {
  const [catalog, chronicle] = await Promise.all([readJson(catalogPath), readJson(chroniclePath)]);

  assert.deepEqual(Object.keys(catalog).sort(), ["campaign_id", "levels", "schema_version", "total_levels"]);
  assert.equal(catalog.schema_version, 1);
  assert.equal(catalog.campaign_id, "solar-term-campaign-v3");
  assert.equal(catalog.total_levels, 24);
  assert.equal(catalog.levels.length, catalog.total_levels);
  assert.deepEqual(catalog.levels.map(({ order }) => order), Array.from({ length: 24 }, (_, index) => index));
  assert.deepEqual(catalog.levels.map(({ id }) => id), expectedTermIds);
  assert.equal(new Set(catalog.levels.map(({ id }) => id)).size, 24, "level ids must be unique");
  assert.equal(new Set(catalog.levels.map(({ scenario_id: scenarioId }) => scenarioId)).size, 24, "scenario ids must be unique");

  assert.equal(chronicle.schema_version, 1);
  assert.equal(chronicle.terms.length, 24);
  assert.deepEqual(
    chronicle.terms.map(({ id, order }) => ({ id, order })),
    catalog.levels.map(({ id, order }) => ({ id, order })),
    "every playable level must own exactly one chronicle entry at the same order",
  );
});

test("each season has five regular levels followed by one three-phase climax", async () => {
  const { levels } = await readJson(catalogPath);
  const climaxes = levels.filter(({ kind }) => kind === "climax");

  assert.equal(levels.filter(({ kind }) => kind === "standard").length, 20);
  assert.deepEqual(
    climaxes.map(({ id, order, scene_key: sceneKey }) => ({ id, order, sceneKey })),
    expectedClimaxes,
  );

  for (const [seasonIndex, season] of seasons.entries()) {
    const seasonLevels = levels.filter(({ season_id: seasonId }) => seasonId === season);
    const firstOrder = seasonIndex * 6;
    assert.equal(seasonLevels.length, 6, `${season} must contain six levels`);
    assert.deepEqual(seasonLevels.map(({ order }) => order), Array.from({ length: 6 }, (_, index) => firstOrder + index));
    assert.deepEqual(seasonLevels.map(({ map_variant: mapVariant }) => mapVariant), [0, 1, 2, 3, 4, 5]);
    assert.deepEqual(seasonLevels.map(({ kind }) => kind), ["standard", "standard", "standard", "standard", "standard", "climax"]);

    const regularSceneKey = `${season}_term_field`;
    for (const level of seasonLevels.slice(0, 5)) {
      const isOpeningPrologue = level.order === 0 && level.scene_key === "spring_prologue";
      assert.ok(isOpeningPrologue || level.scene_key === regularSceneKey, `${level.id} uses an unreviewed regular scene key`);
      assert.equal(Object.hasOwn(level, "phases"), false, `${level.id} may not leak climax phases into a regular level`);
    }

    const climax = seasonLevels.at(-1);
    assert.equal(climax.scene_key, `${season}_climax`);
    assert.equal(climax.objectives.length, 1);
    assert.deepEqual(climax.objectives[0], { type: "climax", label: climax.objectives[0].label, goal: 3 });
    assert.equal(climax.phases.length, 3, `${climax.id} must be a real three-phase level`);
    assert.equal(new Set(climax.phases.map(({ id }) => id)).size, 3, `${climax.id} phase ids must be unique`);
    for (const [phaseIndex, phase] of climax.phases.entries()) {
      assertNonEmptySingleLine(phase.id, `${climax.id}.phases[${phaseIndex}].id`);
      assertNonEmptySingleLine(phase.label, `${climax.id}.phases[${phaseIndex}].label`);
      assert.equal(phase.goal, 1, `${climax.id}.phases[${phaseIndex}] must resolve exactly once`);
    }
  }
});

test("campaign content manifest is bounded, varied, and settlement-ready", async () => {
  const { levels } = await readJson(catalogPath);
  const observedObjectiveTypes = new Set();
  const traces = new Set();
  let totalTargetMinutes = 0;

  for (const level of levels) {
    for (const key of requiredLevelKeys) assert.ok(Object.hasOwn(level, key), `${level.id ?? "unknown level"} is missing ${key}`);
    for (const key of ["id", "season_id", "kind", "scene_key", "scenario_id", "hazard", "intro", "dialogue", "world_trace"]) {
      assertNonEmptySingleLine(level[key], `${level.id}.${key}`);
    }

    assert.ok(seasons.includes(level.season_id), `${level.id} has an unknown season`);
    assert.ok(["standard", "climax"].includes(level.kind), `${level.id} has an unknown kind`);
    assert.ok(Number.isInteger(level.reward_honey) && level.reward_honey >= 0 && level.reward_honey <= 12, `${level.id} reward is out of bounds`);
    assert.deepEqual(
      Object.keys(level).filter((key) => key.startsWith("reward_")).sort(),
      ["reward_honey"],
      `${level.id} may declare at most one permanent reward mutation`,
    );
    assert.ok(Number.isInteger(level.target_minutes) && level.target_minutes >= 8 && level.target_minutes <= 18, `${level.id} target duration is out of bounds`);
    assert.ok(Number.isInteger(level.time_limit_seconds), `${level.id} time limit must be an integer`);
    assert.ok(level.time_limit_seconds >= level.target_minutes * 60, `${level.id} time limit is shorter than its target`);
    assert.ok(level.time_limit_seconds <= level.target_minutes * 60 + 180, `${level.id} time limit has an unreviewed excess margin`);
    assert.ok(Number.isFinite(level.energy_drain) && level.energy_drain >= 0.6 && level.energy_drain <= 1.1, `${level.id} energy drain is out of bounds`);
    assert.ok(Number.isInteger(level.map_variant) && level.map_variant >= 0 && level.map_variant <= 5, `${level.id} map variant is out of bounds`);
    assert.ok(Array.isArray(level.objectives) && level.objectives.length >= 1 && level.objectives.length <= 3, `${level.id} objective list is invalid`);

    const objectiveLabels = new Set();
    for (const [objectiveIndex, objective] of level.objectives.entries()) {
      assert.deepEqual(Object.keys(objective).sort(), ["goal", "label", "type"], `${level.id} objective schema drifted`);
      assert.ok(allowedObjectiveTypes.has(objective.type), `${level.id} has unknown objective type ${objective.type}`);
      assertNonEmptySingleLine(objective.label, `${level.id}.objectives[${objectiveIndex}].label`);
      assert.ok(Number.isInteger(objective.goal) && objective.goal > 0, `${level.id} objective goal must be a positive integer`);
      assert.equal(objectiveLabels.has(objective.label), false, `${level.id} repeats an objective label`);
      objectiveLabels.add(objective.label);
      observedObjectiveTypes.add(objective.type);
    }
    if (level.kind === "standard") {
      assert.ok(level.objectives.length >= 2, `${level.id} needs more than a one-action checklist`);
      assert.equal(level.objectives.some(({ type }) => type === "climax"), false, `${level.id} uses the climax objective in a regular level`);
    }

    assert.equal(traces.has(level.world_trace), false, `${level.id} repeats another level's world trace`);
    traces.add(level.world_trace);
    totalTargetMinutes += level.target_minutes;
  }

  assert.deepEqual([...observedObjectiveTypes].sort(), [...allowedObjectiveTypes].sort(), "the campaign must retain the reviewed multi-action vocabulary");
  assert.equal(traces.size, 24, "every level must leave exactly one distinct persistent world trace");
  // This is only the configured effective-action budget. The separate six-to-eight-hour
  // first-clear goal still requires full-route evidence from independent players.
  assert.ok(totalTargetMinutes >= 240 && totalTargetMinutes <= 300, "designer action targets must retain the reviewed 240-to-300-minute budget");
});

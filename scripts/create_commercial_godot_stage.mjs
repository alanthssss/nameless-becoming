#!/usr/bin/env node

import { cp, lstat, readFile, readdir, rm } from "node:fs/promises";
import { basename, dirname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { writeCanonicalCommercialClassCache } from "./prepare_commercial_script_class_cache.mjs";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const reviewedSourceRoot = resolve(repositoryRoot, "godot");

export const commercialArtFilenames = Object.freeze([
  "autumn_world_ground_v1.png",
  "bear_helper_states_v1.png",
  "dahan_result_hero_v1.png",
  "dashu_result_hero_v1.png",
  "flower_states_topdown_v1.png",
  "guyu_result_hero_v1.png",
  "hive_threshold_interior_v1.png",
  "listening_seed_shell_states_v1.png",
  "main_hive_exterior_v1.png",
  "mentor_bee_topdown_v1.png",
  "mosquito_keeper_states_v1.png",
  "oil_cricket_repairer_states_v2.png",
  "player_bee_topdown_states_v1.png",
  "rest_hive_exterior_v1.png",
  "seasonal_work_props_v1.png",
  "shuangjiang_result_hero_v1.png",
  "spring_world_ground_v1.png",
  "summer_world_ground_v1.png",
  "thrush_neighbor_states_v3.png",
  "winter_world_ground_v1.png",
  "worker_bee_topdown_v1.png",
]);

function fail(message) {
  throw new Error(`Commercial Godot staging refused: ${message}`);
}

async function pathExists(path) {
  try {
    await lstat(path);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

async function collectGdScripts(directoryPath, output) {
  for (const entry of await readdir(directoryPath, { withFileTypes: true })) {
    const entryPath = resolve(directoryPath, entry.name);
    if (entry.isDirectory()) await collectGdScripts(entryPath, output);
    else if (entry.isFile() && entry.name.endsWith(".gd")) output.push(entryPath);
  }
}

export async function validateCommercialArtClosure(godotRoot) {
  const artRoot = resolve(godotRoot, "assets/art/commercial");
  const entries = (await readdir(artRoot)).sort();
  const pngs = entries.filter((name) => name.endsWith(".png")).sort();
  const imports = entries.filter((name) => name.endsWith(".png.import")).sort();
  const expectedPngs = [...commercialArtFilenames].sort();
  const expectedImports = expectedPngs.map((name) => `${name}.import`);
  const expectedEntries = [...expectedPngs, ...expectedImports].sort();
  const unreviewedEntries = entries.filter((name) => !expectedEntries.includes(name));
  if (unreviewedEntries.length > 0) {
    fail(`staged commercial art contains unreviewed entries: ${unreviewedEntries.join(", ")}`);
  }
  if (JSON.stringify(pngs) !== JSON.stringify(expectedPngs)) {
    fail(`staged commercial art is not the exact reviewed source set: ${pngs.join(", ")}`);
  }
  if (JSON.stringify(imports) !== JSON.stringify(expectedImports)) {
    fail(`staged commercial art imports are not the exact reviewed sidecar set: ${imports.join(", ")}`);
  }
}

export async function createCommercialGodotStage({ sourceRoot, destinationRoot }) {
  sourceRoot = resolve(sourceRoot);
  destinationRoot = resolve(destinationRoot);
  if (sourceRoot !== reviewedSourceRoot) {
    fail(`source must be the reviewed repository project: ${reviewedSourceRoot}`);
  }
  if (basename(destinationRoot) !== "godot" || !basename(dirname(destinationRoot)).startsWith("see-you-at-hive-export.")) {
    fail("destination must be a godot directory inside a see-you-at-hive-export.* temporary root");
  }
  if (await pathExists(destinationRoot)) {
    fail(`destination already exists: ${destinationRoot}`);
  }

  await cp(sourceRoot, destinationRoot, { recursive: true, errorOnExist: true, force: false });
  // A commercial stage must not inherit the development UID registry or retain
  // source files for art that was explicitly rejected. Godot rebuilds a fresh
  // UID cache while scanning this reduced stage, so rejected paths cannot leak
  // into the immutable PCK as stale binary strings.
  for (const excludedPath of [
    ".godot/uid_cache.bin",
    "assets/art/commercial/oil_cricket_states_v1.png",
    "assets/art/commercial/oil_cricket_states_v1.png.import",
    "assets/art/commercial/thrush_tuner_states_v1.png",
    "assets/art/commercial/thrush_tuner_states_v1.png.import",
    "assets/audio/commercial/trichord_echo.wav",
    "assets/audio/commercial/trichord_echo.wav.import",
    "assets/art/launch",
    "assets/art/seasonal",
    "assets/art/field_textile_overlay.svg",
    "assets/art/field_textile_overlay.svg.import",
    "assets/art/flower_textile_common.svg",
    "assets/art/flower_textile_common.svg.import",
    "assets/art/flower_textile_high_value.svg",
    "assets/art/flower_textile_high_value.svg.import",
    "assets/art/hive_textile_entrance.svg",
    "assets/art/hive_textile_entrance.svg.import",
    "assets/art/player_bee_textile.svg",
    "assets/art/player_bee_textile.svg.import",
  ]) {
    await rm(resolve(destinationRoot, excludedPath), { recursive: true, force: true });
  }
  await validateCommercialArtClosure(destinationRoot);
  const allowlist = JSON.parse(await readFile(resolve(destinationRoot, "data/commercial_script_class_allowlist.json"), "utf8"));
  if (allowlist?.schema_version !== 1 || !Array.isArray(allowlist.entries) || allowlist.entries.length === 0) {
    fail("copied project has no schema-v1 commercial script-class allowlist");
  }
  const allowedScripts = new Set(allowlist.entries.map((entry) => entry.path));
  const stagedScripts = [];
  await collectGdScripts(resolve(destinationRoot, "scripts"), stagedScripts);
  let removedScripts = 0;
  for (const scriptPath of stagedScripts) {
    const sourcePath = `res://${relative(destinationRoot, scriptPath).split(sep).join("/")}`;
    if (allowedScripts.has(sourcePath)) continue;
    await rm(scriptPath);
    await rm(`${scriptPath}.uid`, { force: true });
    removedScripts += 1;
  }
  const remainingScripts = [];
  await collectGdScripts(resolve(destinationRoot, "scripts"), remainingScripts);
  const remainingPaths = remainingScripts.map((scriptPath) => `res://${relative(destinationRoot, scriptPath).split(sep).join("/")}`).sort();
  const expectedPaths = [...allowedScripts].sort();
  if (JSON.stringify(remainingPaths) !== JSON.stringify(expectedPaths)) {
    fail("staging script closure is not the exact commercial allowlist");
  }

  for (const excludedPath of [
    "bootstrap.tscn",
    "main.tscn",
    "playtest",
    "tests",
    "tools",
  ]) {
    await rm(resolve(destinationRoot, excludedPath), { recursive: true, force: true });
  }

  await writeCanonicalCommercialClassCache({ godotRoot: destinationRoot });
  console.log(`Commercial Godot stage prepared with ${remainingPaths.length} scripts and ${commercialArtFilenames.length} reviewed art sources; ${removedScripts} non-commercial scripts removed.`);
  return { destinationRoot, remainingPaths, removedScripts };
}

async function main() {
  if (process.argv.length !== 4) {
    fail("usage: create_commercial_godot_stage.mjs <source-godot-root> <temporary-destination-godot-root>");
  }
  await createCommercialGodotStage({ sourceRoot: process.argv[2], destinationRoot: process.argv[3] });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}

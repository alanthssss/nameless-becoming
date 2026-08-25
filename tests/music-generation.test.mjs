import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFile, mkdir, mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryPath = fileURLToPath(new URL("../", import.meta.url));
const generatorPath = join(repositoryPath, "scripts/generate_music_variations.py");
const musicPath = join(repositoryPath, "godot/assets/music");

const UNCHANGED_TRACK_HASHES = Object.freeze({
  "spring_boss.wav": "df1b22d280ba3e3d18627d48bea1ad02cb1f2164007176180e6d39b1f438b3ed",
  "spring_explore.wav": "b443b5efe895bb5365c2b66d135def4656a6b2a409bbd3757c4784ce5bea4f6c",
  "summer_boss.wav": "7fcdbc2d35242f8981ce11d48844443621fd1a3ad00104d44fe721c1bf7e634e",
  "summer_explore.wav": "9ea49bc76c610dc0fcad3c74d3a308662637d48558a68cf2d7f216c1d239f353",
  "winter_boss.wav": "a11aaca193b51483d572e9411854970940e7d12e43b86001f6226e3cc915eeaa",
  "winter_explore.wav": "26f5e344a6f83fb8beba8574b2db687c8b7015927113c3d21af750e294902910",
});

const PRIOR_AUTUMN_HASHES = Object.freeze({
  "autumn_boss.wav": "d9ff59d8de8fb35c9200251dc7ce18eb7740dd71d17cb5f44004eb51c92c6d84",
  "autumn_explore.wav": "e22b01786dfb50041aa76f3fb43ea769ce5239bd9f2c7f7e9bafb74bb3dd1d66",
});

const FINAL_AUTUMN_HASHES = Object.freeze({
  "autumn_boss.wav": "b571d75a05be755422214ddf7fd851fa31148c3a7feae7fa896d558340d95701",
  "autumn_explore.wav": "de25c797c9dcb49eabee9adc61630dba21493a985ec2dc79ddb115f2d8f4b23a",
});

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex");
}

async function renderAutumnPair(root) {
  const scripts = join(root, "scripts");
  await mkdir(scripts, { recursive: true });
  const temporaryGenerator = join(scripts, "generate_music_variations.py");
  await copyFile(generatorPath, temporaryGenerator);
  const result = spawnSync(process.env.PYTHON || "python3", [
    temporaryGenerator,
    "--track", "autumn_explore",
    "--track", "autumn_boss",
  ], { encoding: "utf8" });
  assert.equal(result.status, 0, `music generator failed:\n${result.stdout}\n${result.stderr}`);
  return join(root, "godot/assets/music");
}

test("formal autumn candidate leaves all six out-of-scope arrangements byte-identical", async () => {
  for (const [name, expectedHash] of Object.entries(UNCHANGED_TRACK_HASHES)) {
    assert.equal(await sha256(join(musicPath, name)), expectedHash, `${name} is outside the autumn gate`);
  }
  for (const [name, priorHash] of Object.entries(PRIOR_AUTUMN_HASHES)) {
    assert.notEqual(await sha256(join(musicPath, name)), priorHash, `${name} still contains the rejected baseline`);
  }
});

test("autumn Boss keeps Z as the full-loop majority spine and T as a bounded counterphrase", () => {
  const result = spawnSync(process.env.PYTHON || "python3", [
    "-c",
    "import json,runpy,sys; data=runpy.run_path(sys.argv[1]); print(json.dumps(data['AUTUMN_BOSS_STRUCTURE']))",
    generatorPath,
  ], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  const structure = JSON.parse(result.stdout);
  assert.deepEqual(structure.z_backbone_bars, Array.from({ length: 16 }, (_, index) => index));
  assert.ok(structure.z_full_bars.length > structure.t_counter_bars.length, "Z must own more full bars than T");
  assert.deepEqual([...structure.z_full_bars, ...structure.t_counter_bars].sort((a, b) => a - b),
    Array.from({ length: 16 }, (_, index) => index));
  assert.equal(structure.t_counter_bars.at(-1), 15, "T may punctuate the final closure bar");
  assert.ok(!structure.t_counter_bars.includes(14), "the Boss reprise must return to Z before the last stop");
  assert.ok(structure.dub_send_bars.every((bar) => structure.z_full_bars.includes(bar)));
});

test("formal autumn generator reproduces both checked-in loops deterministically", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-autumn-full-loop-"));
  try {
    const first = await renderAutumnPair(join(temporaryRoot, "first"));
    const second = await renderAutumnPair(join(temporaryRoot, "second"));
    for (const [name, expectedHash] of Object.entries(FINAL_AUTUMN_HASHES)) {
      assert.equal(await sha256(join(musicPath, name)), expectedHash, `${name} checked-in hash changed`);
      assert.equal(await sha256(join(first, name)), expectedHash, `${name} is stale relative to the generator`);
      assert.equal(await sha256(join(second, name)), expectedHash, `${name} changed across deterministic renders`);
    }
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

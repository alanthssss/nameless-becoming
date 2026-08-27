import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { buildCanonicalCommercialClassCache } from "../scripts/prepare_commercial_script_class_cache.mjs";

const repositoryPath = fileURLToPath(new URL("../", import.meta.url));
const preparerPath = join(repositoryPath, "scripts/prepare_commercial_script_class_cache.mjs");
const allowlistPath = join(repositoryPath, "godot/data/commercial_script_class_allowlist.json");

const forbiddenText = [
  "nameless",
  "boss",
  "b01",
  "playtest",
  "/main.gd",
  "/bootstrap.gd",
  "production_hud",
  "productionhud",
];

function runPreparer(...arguments_) {
  return spawnSync(process.execPath, [preparerPath, ...arguments_], {
    cwd: repositoryPath,
    encoding: "utf8",
  });
}

test("commercial class cache is an exact deterministic projection of reviewed runtime sources", async () => {
  const canonical = await buildCanonicalCommercialClassCache();
  const allowlist = JSON.parse(await readFile(allowlistPath, "utf8"));
  assert.equal(allowlist.schema_version, 1);
  assert.ok(allowlist.entries.length > 0);
  assert.equal((canonical.match(/^"class":/gm) ?? []).length, allowlist.entries.length);

  const lowerCanonical = canonical.toLowerCase();
  for (const term of forbiddenText) assert.ok(!lowerCanonical.includes(term), `cache leaked forbidden text: ${term}`);
  for (const entry of allowlist.entries) {
    assert.match(canonical, new RegExp(`^"class": &"${entry.class}"`, "m"));
    assert.match(canonical, new RegExp(`^"path": "${entry.path.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}"`, "m"));
  }
  assert.equal(await buildCanonicalCommercialClassCache(), canonical, "cache generation must be byte-deterministic");
});

test("check mode fails closed and generation atomically removes a contaminated cache", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "see-you-hive-class-cache-"));
  const cachePath = join(temporaryRoot, "global_script_class_cache.cfg");
  const contaminated = 'list=[{\n"base": &"RefCounted",\n"class": &"NamelessSaveManager",\n"path": "res://scripts/save_manager.gd"\n}]\n';
  try {
    await writeFile(cachePath, contaminated, "utf8");
    const rejected = runPreparer("--check", "--cache", cachePath);
    assert.notEqual(rejected.status, 0);
    assert.match(rejected.stderr, /not the exact commercial allowlist/u);
    assert.equal(await readFile(cachePath, "utf8"), contaminated, "failed check may not mutate its input");

    const prepared = runPreparer("--cache", cachePath);
    assert.equal(prepared.status, 0, prepared.stderr);
    const first = await readFile(cachePath, "utf8");
    assert.equal(first, await buildCanonicalCommercialClassCache());
    const verified = runPreparer("--check", "--cache", cachePath);
    assert.equal(verified.status, 0, verified.stderr);
    const repeated = runPreparer("--cache", cachePath);
    assert.equal(repeated.status, 0, repeated.stderr);
    assert.equal(await readFile(cachePath, "utf8"), first, "repeated preparation must be byte-identical");
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

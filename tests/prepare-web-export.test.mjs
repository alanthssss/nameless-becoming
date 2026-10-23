import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile, copyFile, readdir, access, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gunzipSync } from "node:zlib";
import { spawnSync } from "node:child_process";

async function fixture(run) {
  const root = await mkdtemp(join(tmpdir(), "web-export-move-"));
  try {
    const scripts = join(root, "scripts");
    const game = join(root, "public", "game");
    const backup = join(root, "backup");
    await Promise.all([mkdir(scripts), mkdir(game, { recursive: true }), mkdir(backup)]);
    await copyFile(new URL("../scripts/prepare_web_export.mjs", import.meta.url), join(scripts, "prepare_web_export.mjs"));
    const payload = Buffer.from("synthetic WASM bytes for transport verification");
    await writeFile(join(game, "index.wasm"), payload);
    await writeFile(join(game, "index.js"), 'loadPromise = preloader.loadPromise(`${loadPath}.wasm`, size, true);');
    await writeFile(join(game, "index.html"), "\t\tconsole.error(err);\n\t\t\tsetStatusMode('hidden');");
    await run({ root, game, backup, payload, script: join(scripts, "prepare_web_export.mjs") });
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

test("prepared web payload preserves a temporary original before removing the hosted raw file", () => fixture(async ({ root, game, backup, payload, script }) => {
  const result = spawnSync(process.execPath, [script], { cwd: root, env: { ...process.env, TMPDIR: backup }, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(gunzipSync(await readFile(join(game, "index.wasm.gz"))), payload);
  assert.deepEqual(await readFile(join(game, "index.wasm.part0")), payload);
  const originals = await readdir(backup);
  assert.equal(originals.length, 1);
  assert.deepEqual(await readFile(join(backup, originals[0])), payload);
  await assert.rejects(access(join(game, "index.wasm")), { code: "ENOENT" });
  assert.match(await readFile(join(game, "index.js"), "utf8"), /DecompressionStream/);
  assert.match(await readFile(join(game, "index.html"), "utf8"), /see-you-at-the-hive-ready/);
}));

test("failed temporary copy leaves the exported raw WASM intact", () => fixture(async ({ root, game, payload, script }) => {
  const result = spawnSync(process.execPath, [script], { cwd: root, env: { ...process.env, TMPDIR: join(root, "missing-parent") }, encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.deepEqual(await readFile(join(game, "index.wasm")), payload);
  assert.doesNotMatch(await readFile(join(game, "index.js"), "utf8"), /DecompressionStream/);
}));

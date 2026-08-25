import assert from "node:assert/strict";
import { readFile, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  BLIND_TRACKS,
  generateAutumnFullLoopAb,
  validateFinalAnswers,
} from "../scripts/prepare_autumn_full_loop_ab.mjs";

test("final autumn A/B requires a role choice and explains unresolved outcomes", () => {
  assert.match(validateFinalAnswers({}), /采集/);
  assert.match(validateFinalAnswers({ explore_choice: "C" }), /Boss/);
  assert.match(validateFinalAnswers({ explore_choice: "tie", boss_choice: "M" }), /原因/);
  assert.match(validateFinalAnswers({ explore_choice: "Y", boss_choice: "neither" }), /原因/);
  assert.equal(validateFinalAnswers({
    explore_choice: "tie",
    explore_note: "两条各有优点",
    boss_choice: "neither",
    boss_note: "都太挤",
  }), "");
});

test("final autumn A/B is loudness-matched and keeps the answer outside listener", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-autumn-final-ab-"));
  const output = join(temporaryRoot, "package");
  try {
    const result = await generateAutumnFullLoopAb(output);
    const html = await readFile(join(output, "listener", "index.html"), "utf8");
    const manifestText = await readFile(join(output, "listener", "manifest.json"), "utf8");
    const manifest = JSON.parse(manifestText);
    const key = JSON.parse(await readFile(join(output, "reviewer", "answer-key.json"), "utf8"));

    assert.equal(result.packageSha, manifest.package_identity_sha256);
    assert.equal(key.package_identity_sha256, manifest.package_identity_sha256);
    assert.doesNotMatch(`${html}\n${manifestText}`, /candidate|baseline|autumn_(?:explore|boss)\.wav|codex\//iu);
    assert.match(html, /采集 \/ 探索组/);
    assert.match(html, /遭遇 \/ Boss 组/);
    assert.deepEqual(manifest.tracks.map(({ id }) => id), BLIND_TRACKS.map(({ id }) => id));
    assert.deepEqual(key.tracks.map(({ id, version }) => [id, version]), [
      ["C", "baseline"],
      ["Y", "candidate"],
      ["M", "candidate"],
      ["R", "baseline"],
    ]);
    for (const role of ["explore", "boss"]) {
      const pair = manifest.tracks.filter((track) => track.role === role);
      assert.equal(pair.length, 2);
      assert.ok(Math.abs(pair[0].integrated_lufs - pair[1].integrated_lufs) <= 0.3);
      assert.ok(pair.every((track) => track.true_peak_dbtp <= -1));
    }
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

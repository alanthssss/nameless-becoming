import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { lstat, mkdir, mkdtemp, readFile, readdir, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { runInNewContext } from "node:vm";

import {
  BLIND_SKETCHES,
  LISTENER_JAVASCRIPT,
  OFFICIAL_WAV_SHA256,
  generateAutumnDirectionPackage,
  validateDirectionAnswers,
} from "../scripts/prepare_autumn_direction_sketches.mjs";


const repositoryRoot = fileURLToPath(new URL("../", import.meta.url));

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex");
}

function renderResult(output) {
  return spawnSync("python3", [
    join(repositoryRoot, "scripts", "generate_autumn_direction_sketches.py"),
    "--output", output,
  ], { cwd: repositoryRoot, encoding: "utf8", maxBuffer: 4 * 1024 * 1024 });
}

function render(output) {
  const result = renderResult(output);
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

async function allFiles(root) {
  const result = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) result.push(...await allFiles(path));
    else result.push(path);
  }
  return result;
}

function sampledMonoCorrelation(firstBytes, secondBytes) {
  function dataRange(bytes) {
    let offset = 12;
    while (offset + 8 <= bytes.length) {
      const id = bytes.toString("ascii", offset, offset + 4);
      const size = bytes.readUInt32LE(offset + 4);
      if (id === "data") return [offset + 8, size];
      offset += 8 + size + (size % 2);
    }
    throw new Error("WAV data chunk missing");
  }
  const [firstStart, firstSize] = dataRange(firstBytes);
  const [secondStart, secondSize] = dataRange(secondBytes);
  const frames = Math.min(firstSize, secondSize) / 4;
  let dot = 0;
  let firstEnergy = 0;
  let secondEnergy = 0;
  for (let frame = 0; frame < frames; frame += 128) {
    const firstOffset = firstStart + frame * 4;
    const secondOffset = secondStart + frame * 4;
    const first = (firstBytes.readInt16LE(firstOffset) + firstBytes.readInt16LE(firstOffset + 2)) * 0.5;
    const second = (secondBytes.readInt16LE(secondOffset) + secondBytes.readInt16LE(secondOffset + 2)) * 0.5;
    dot += first * second;
    firstEnergy += first * first;
    secondEnergy += second * second;
  }
  return dot / Math.sqrt(firstEnergy * secondEnergy);
}

function exerciseListener(savedSnapshot = null, packageSha = "b".repeat(64)) {
  class FakeTarget {
    constructor(extra = {}) { this.listeners = new Map(); Object.assign(this, extra); }
    addEventListener(name, callback) {
      const callbacks = this.listeners.get(name) || [];
      callbacks.push(callback);
      this.listeners.set(name, callbacks);
    }
    dispatch(name) { for (const callback of this.listeners.get(name) || []) callback(); }
  }
  const ids = ["K", "Q", "T", "Z"];
  const controls = [
    ...["K", "Q", "both", "neither"].map((value) => ({ name: "explore_direction", type: "radio", value, checked: false })),
    ...["T", "Z", "both", "neither"].map((value) => ({ name: "boss_direction", type: "radio", value, checked: false })),
    { name: "explore_note", type: "textarea", value: "", required: false },
    { name: "boss_note", type: "textarea", value: "", required: false },
  ];
  controls.explore_note = controls.find((control) => control.name === "explore_note");
  controls.boss_note = controls.find((control) => control.name === "boss_note");
  const form = new FakeTarget({ elements: controls, reportValidityCalls: 0, reportValidity() { this.reportValidityCalls += 1; } });
  const status = { textContent: "" };
  const exportButton = new FakeTarget();
  const audios = Object.fromEntries(ids.map((id) => [id, new FakeTarget({ currentTime: 0, paused: true, pause() { this.paused = true; } })]));
  const stats = Object.fromEntries(ids.map((id) => [id, { textContent: "" }]));
  let downloads = 0;
  const document = {
    body: { dataset: { schema: "nameless-autumn-direction-choice/v1", packageSha256: packageSha } },
    querySelector(selector) {
      if (selector === "#direction-form") return form;
      if (selector === "#status") return status;
      if (selector === "#export") return exportButton;
      const audioId = selector.match(/^\[data-audio="([KQTZ])"\]$/)?.[1];
      if (audioId) return audios[audioId];
      const statsId = selector.match(/^\[data-stats="([KQTZ])"\]$/)?.[1];
      if (statsId) return stats[statsId];
      throw new Error(`Unexpected selector: ${selector}`);
    },
    querySelectorAll(selector) {
      if (selector === "audio") return Object.values(audios);
      throw new Error(`Unexpected selectorAll: ${selector}`);
    },
    createElement(name) {
      assert.equal(name, "a");
      return { href: "", download: "", click() { downloads += 1; } };
    },
  };
  const localStorage = {
    saved: savedSnapshot ? JSON.stringify(savedSnapshot) : null,
    getItem() { return this.saved; },
    setItem(_key, value) { this.saved = value; },
  };
  class FakeFormData {
    constructor(target) { this.target = target; }
    *entries() {
      for (const control of this.target.elements) {
        if (control.type === "radio" && !control.checked) continue;
        yield [control.name, control.value];
      }
    }
  }
  const fakeUrl = { createObjectURL: () => "blob:test", revokeObjectURL() {} };
  runInNewContext(LISTENER_JAVASCRIPT, {
    Blob,
    clearTimeout() {},
    document,
    FormData: FakeFormData,
    localStorage,
    setTimeout(callback) { callback(); return 1; },
    URL: fakeUrl,
    window: {},
  });
  return {
    controls,
    downloads: () => downloads,
    exportButton,
    form,
    status,
    setRadio(name, value) {
      for (const control of controls.filter((candidate) => candidate.name === name)) control.checked = control.value === value;
    },
  };
}

test("locks all eight formal WAVs while rendering four deterministic sketches", { timeout: 180_000 }, async () => {
  await mkdir(join(repositoryRoot, "outputs"), { recursive: true });
  const temporary = await mkdtemp(join(repositoryRoot, "outputs", ".autumn-sketch-test-"));
  const first = join(temporary, "first");
  const second = join(temporary, "second");
  try {
    assert.equal(Object.keys(OFFICIAL_WAV_SHA256).length, 8);
    for (const [name, expected] of Object.entries(OFFICIAL_WAV_SHA256)) {
      assert.equal(await sha256(join(repositoryRoot, "godot", "assets", "music", name)), expected, `${name} changed`);
    }

    render(first);
    render(second);
    assert.deepEqual(await readFile(join(first, "manifest.json")), await readFile(join(second, "manifest.json")));
    const manifest = JSON.parse(await readFile(join(first, "manifest.json"), "utf8"));
    assert.equal(manifest.schema_version, "nameless-autumn-direction-sketches/v1");
    assert.equal(manifest.disposition, "direction-only; not game replacement assets");
    assert.equal(manifest.tracks.length, 4);
    assert.equal(new Set(manifest.tracks.map((track) => track.wav_sha256)).size, 4, "all four directions must be genuinely different renders");

    for (const track of manifest.tracks) {
      assert.equal(track.meter, "4/4");
      assert.equal(track.phrase, "4+4 bars");
      assert.equal(track.bars, 8);
      assert.notEqual(track.bpm, 84);
      assert.notEqual(track.bpm, 126);
      assert.equal(track.pitch_motion, "stepped only; no portamento");
      assert.equal(track.legacy_material, "none");
      assert.ok(track.duration_seconds >= 15 && track.duration_seconds <= 20);
      assert.ok(Math.abs(track.metrics.integrated_lufs - track.target_lufs) <= 0.12);
      assert.ok(track.metrics.cubic_peak_estimate_dbtp <= -1);
      assert.ok(track.metrics.longest_dropout_ms >= 250);
      assert.ok(track.metrics.mono_compatibility_loss_db <= 0.8);
      assert.ok(track.metrics.loop_seam_dbfs <= -80);
      assert.equal(await sha256(join(first, `${track.key}.wav`)), track.wav_sha256);
      assert.deepEqual(await readFile(join(first, `${track.key}.wav`)), await readFile(join(second, `${track.key}.wav`)));
    }
    for (const role of ["explore", "boss"]) {
      const tracks = manifest.tracks.filter((track) => track.role === role);
      assert.equal(tracks.length, 2);
      assert.ok(Math.abs(tracks[0].metrics.integrated_lufs - tracks[1].metrics.integrated_lufs) <= 0.3);
      const correlation = sampledMonoCorrelation(
        await readFile(join(first, `${tracks[0].key}.wav`)),
        await readFile(join(first, `${tracks[1].key}.wav`)),
      );
      assert.ok(Math.abs(correlation) < 0.2, `${role} directions are too waveform-similar: ${correlation}`);
    }

    const canary = join(temporary, "canary.wav");
    await writeFile(canary, "do not overwrite\n");
    await rm(join(first, "explore_seed_funk.wav"));
    await symlink(canary, join(first, "explore_seed_funk.wav"));
    render(first);
    assert.equal(await readFile(canary, "utf8"), "do not overwrite\n");
    assert.equal((await lstat(join(first, "explore_seed_funk.wav"))).isSymbolicLink(), false);

    const unowned = join(temporary, "unowned");
    await mkdir(unowned);
    await writeFile(join(unowned, "keep.txt"), "unowned\n");
    assert.notEqual(renderResult(unowned).status, 0);
    assert.equal(await readFile(join(unowned, "keep.txt"), "utf8"), "unowned\n");

    const outputLink = join(temporary, "output-link");
    await symlink(first, outputLink);
    assert.notEqual(renderResult(outputLink).status, 0);
    assert.equal((await lstat(outputLink)).isSymbolicLink(), true);

    const outside = join(tmpdir(), `nameless-unsafe-output-${process.pid}`);
    assert.notEqual(renderResult(outside).status, 0);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
});

test("builds a mandatory, anonymous direction choice with an explicit neither option", { timeout: 120_000 }, async () => {
  const temporary = await mkdtemp(join(tmpdir(), "nameless-autumn-listener-test-"));
  await mkdir(join(repositoryRoot, "outputs"), { recursive: true });
  const renderTemporary = await mkdtemp(join(repositoryRoot, "outputs", ".autumn-listener-source-test-"));
  const source = join(renderTemporary, "source");
  const output = join(temporary, "listener-package");
  const predictableOldStage = `${output}.staged-${process.pid}`;
  try {
    render(source);
    await mkdir(predictableOldStage);
    await writeFile(join(predictableOldStage, "keep.txt"), "must survive\n");
    const result = await generateAutumnDirectionPackage(output, source);
    assert.equal(result.output, output);
    assert.equal(await readFile(join(predictableOldStage, "keep.txt"), "utf8"), "must survive\n");
    assert.deepEqual(BLIND_SKETCHES.map(({ id, role }) => [id, role]), [
      ["K", "explore"], ["Q", "explore"], ["T", "boss"], ["Z", "boss"],
    ]);

    const html = await readFile(join(output, "listener", "index.html"), "utf8");
    const sourceManifest = JSON.parse(await readFile(join(source, "manifest.json"), "utf8"));
    const answerKey = JSON.parse(await readFile(join(output, "reviewer", "answer-key.json"), "utf8"));
    const publicManifest = JSON.parse(await readFile(join(output, "listener", "manifest.json"), "utf8"));
    assert.equal(answerKey.tracks.length, 4);
    assert.equal(publicManifest.tracks.length, 4);
    assert.match(html, /name="explore_direction"/);
    assert.match(html, /name="boss_direction"/);
    assert.equal((html.match(/value="neither"/g) || []).length, 2);
    assert.equal((html.match(/required type="radio"/g) || []).length, 2);
    assert.equal(answerKey.source_manifest_sha256, await sha256(join(source, "manifest.json")));
    assert.deepEqual(answerKey.source_renderer, sourceManifest.renderer);
    assert.equal(answerKey.package_identity_sha256, publicManifest.package_identity_sha256);
    assert.match(html, new RegExp(`data-package-sha256="${publicManifest.package_identity_sha256}"`));
    for (const hidden of ["seed_funk", "amber_circuit", "postpunk_dub", "stoptime_industrial", "electro-funk", "post-punk", "industrial rock"]) {
      for (const path of await allFiles(join(output, "listener"))) {
        if (path.endsWith(".wav")) continue;
        assert.equal((await readFile(path, "utf8")).includes(hidden), false, `listener leaks hidden direction in ${path}: ${hidden}`);
      }
    }
    for (const track of answerKey.tracks) {
      const sourceTrack = sourceManifest.tracks.find((candidate) => candidate.key === track.source);
      const publicTrack = publicManifest.tracks.find((candidate) => candidate.id === track.id);
      assert.ok(sourceTrack);
      assert.ok(publicTrack);
      const sourceDiskSha = await sha256(join(source, `${track.source}.wav`));
      const listenerDiskSha = await sha256(join(output, "listener", "tracks", `${track.id}.wav`));
      assert.equal(sourceTrack.wav_sha256, sourceDiskSha, "source manifest ↔ source disk");
      assert.equal(sourceDiskSha, listenerDiskSha, "source disk ↔ listener disk");
      assert.equal(listenerDiskSha, publicTrack.sha256, "listener disk ↔ public manifest");
      assert.equal(publicTrack.sha256, track.source_sha256, "public manifest ↔ answer key");
      assert.ok(track.ffmpeg_ebur128.true_peak_dbtp <= -1);
      assert.ok(Math.abs(track.ffmpeg_ebur128.integrated_lufs - (track.role === "explore" ? -17.3 : -18.7)) <= 0.3);
    }
    assert.notEqual(await readFile(join(output, "reviewer", "answer-key.json"), "utf8"), await readFile(join(output, "listener", "manifest.json"), "utf8"));

    const firstListenerHash = await sha256(join(output, "listener", "index.html"));
    await generateAutumnDirectionPackage(output, source);
    assert.equal(await sha256(join(output, "listener", "index.html")), firstListenerHash, "owned output must be safely repeatable");

    const unowned = join(temporary, "unowned");
    await mkdir(unowned);
    await writeFile(join(unowned, "keep.txt"), "unowned\n");
    await assert.rejects(generateAutumnDirectionPackage(unowned, source), /unowned output/);
    assert.equal(await readFile(join(unowned, "keep.txt"), "utf8"), "unowned\n");

    const outputLink = join(temporary, "owned-output-link");
    await symlink(output, outputLink);
    await assert.rejects(generateAutumnDirectionPackage(outputLink, source), /symlink/);
    assert.equal((await lstat(outputLink)).isSymbolicLink(), true);

    const markerTarget = join(temporary, "marker-target");
    await writeFile(markerTarget, "nameless-autumn-direction-sketches:v1\n");
    const markerLinkOutput = join(temporary, "marker-link-output");
    await mkdir(markerLinkOutput);
    await symlink(markerTarget, join(markerLinkOutput, ".nameless-autumn-direction-sketches"));
    await assert.rejects(generateAutumnDirectionPackage(markerLinkOutput, source), /unowned output/);
    assert.equal((await lstat(join(markerLinkOutput, ".nameless-autumn-direction-sketches"))).isSymbolicLink(), true);

    const repositoryAncestor = resolve(repositoryRoot, "..");
    await assert.rejects(generateAutumnDirectionPackage(repositoryAncestor, source), /ancestors/);
    const ancestorLink = join(temporary, "repository-ancestor-link");
    await symlink(repositoryAncestor, ancestorLink);
    await assert.rejects(generateAutumnDirectionPackage(ancestorLink, source), /ancestors/);

    const originalManifest = await readFile(join(source, "manifest.json"));
    const unknownManifest = JSON.parse(originalManifest.toString("utf8"));
    unknownManifest.renderer.commit = "0".repeat(40);
    await writeFile(join(source, "manifest.json"), JSON.stringify(unknownManifest, null, 2) + "\n");
    await assert.rejects(generateAutumnDirectionPackage(join(temporary, "unknown-source"), source), /renderer identity/);
    await writeFile(join(source, "manifest.json"), originalManifest);

    const loudnessTamper = JSON.parse(originalManifest.toString("utf8"));
    loudnessTamper.tracks[0].metrics.integrated_lufs = loudnessTamper.tracks[0].target_lufs + 0.4;
    await writeFile(join(source, "manifest.json"), JSON.stringify(loudnessTamper, null, 2) + "\n");
    await assert.rejects(generateAutumnDirectionPackage(join(temporary, "loudness-tamper"), source), /±0\.3 LU target/);
    await writeFile(join(source, "manifest.json"), originalManifest);
  } finally {
    await rm(temporary, { recursive: true, force: true });
    await rm(renderTemporary, { recursive: true, force: true });
  }
});

test("requires both role choices without forcing a false preference", () => {
  assert.match(validateDirectionAnswers({}), /探索组/);
  assert.match(validateDirectionAnswers({ explore_direction: "neither" }), /Boss/);
  assert.match(validateDirectionAnswers({ explore_direction: "neither", boss_direction: "Z" }), /探索组选择/);
  assert.match(validateDirectionAnswers({ explore_direction: "neither", explore_note: "   ", boss_direction: "Z" }), /探索组选择/);
  assert.match(validateDirectionAnswers({ explore_direction: "K", boss_direction: "neither", boss_note: "\t" }), /Boss 组选择/);
  assert.equal(validateDirectionAnswers({
    explore_direction: "neither",
    explore_note: "没劲",
    boss_direction: "neither",
    boss_note: "不像秋天",
  }), "");
  assert.equal(validateDirectionAnswers({ explore_direction: "both", boss_direction: "Z" }), "");
});

test("real listener JavaScript blocks empty exports, conditions neither notes, and rejects stale cache identity", () => {
  const stale = exerciseListener({
    package_identity: { schema: "nameless-autumn-direction-choice/v1", package_sha256: "a".repeat(64) },
    responses: { explore_direction: "K", boss_direction: "T" },
    listening: {},
  });
  assert.equal(stale.controls.filter((control) => control.type === "radio").some((control) => control.checked), false);
  stale.exportButton.dispatch("click");
  assert.equal(stale.downloads(), 0);
  assert.match(stale.status.textContent, /请选择探索组/);

  const conditional = exerciseListener();
  conditional.setRadio("explore_direction", "neither");
  conditional.setRadio("boss_direction", "Z");
  conditional.form.dispatch("input");
  assert.equal(conditional.controls.explore_note.required, true);
  assert.equal(conditional.controls.boss_note.required, false);
  conditional.controls.explore_note.value = "   ";
  conditional.exportButton.dispatch("click");
  assert.equal(conditional.downloads(), 0);
  assert.match(conditional.status.textContent, /最不对的感觉/);
  conditional.controls.explore_note.value = "没劲";
  conditional.exportButton.dispatch("click");
  assert.equal(conditional.downloads(), 1);
});

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { generateCommercialAudio } from "../scripts/generate_commercial_audio.mjs";

const repositoryPath = fileURLToPath(new URL("../", import.meta.url));
const checkedAudioPath = join(repositoryPath, "godot/assets/audio/commercial");
const sourcePath = join(repositoryPath, "scripts/commercial_audio_sources.json");
const creditsPath = join(repositoryPath, "godot/data/credits_and_licenses.json");

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function parsePcm16Wave(bytes) {
  assert.equal(bytes.toString("ascii", 0, 4), "RIFF");
  assert.equal(bytes.toString("ascii", 8, 12), "WAVE");
  assert.equal(bytes.toString("ascii", 12, 16), "fmt ");
  assert.equal(bytes.readUInt32LE(16), 16, "only canonical PCM fmt chunks are accepted");
  assert.equal(bytes.readUInt16LE(20), 1, "audio must be integer PCM");
  const channels = bytes.readUInt16LE(22);
  const sampleRate = bytes.readUInt32LE(24);
  const bits = bytes.readUInt16LE(34);
  assert.equal(bytes.toString("ascii", 36, 40), "data");
  const dataBytes = bytes.readUInt32LE(40);
  assert.equal(bytes.length, 44 + dataBytes, "WAV may not contain nondeterministic metadata chunks");
  const blockAlign = channels * bits / 8;
  const frames = dataBytes / blockAlign;
  const left = new Int16Array(frames);
  const right = new Int16Array(frames);
  let peak = 0;
  let leftSum = 0;
  let rightSum = 0;
  let stereoDifferenceEnergy = 0;
  const sampledValues = new Set();
  for (let frame = 0; frame < frames; frame += 1) {
    const leftSample = bytes.readInt16LE(44 + frame * blockAlign);
    const rightSample = bytes.readInt16LE(46 + frame * blockAlign);
    left[frame] = leftSample;
    right[frame] = rightSample;
    peak = Math.max(peak, Math.abs(leftSample), Math.abs(rightSample));
    leftSum += leftSample;
    rightSum += rightSample;
    stereoDifferenceEnergy += (leftSample - rightSample) ** 2;
    if (frame % 17 === 0) sampledValues.add(`${leftSample}:${rightSample}`);
  }
  return {
    channels,
    sampleRate,
    bits,
    frames,
    left,
    right,
    peak: peak / 32767,
    leftDc: leftSum / frames / 32767,
    rightDc: rightSum / frames / 32767,
    stereoDifferenceRms: Math.sqrt(stereoDifferenceEnergy / frames) / 32767,
    distinctSamplePairs: sampledValues.size,
  };
}

test("commercial SFX and ambience regenerate byte-for-byte from checked-in sources", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "see-you-hive-commercial-audio-"));
  try {
    const firstPath = join(temporaryRoot, "first");
    const secondPath = join(temporaryRoot, "second");
    const first = await generateCommercialAudio({ outputDirectory: firstPath });
    const second = await generateCommercialAudio({ outputDirectory: secondPath });
    assert.deepEqual(first.manifest, second.manifest);

    const checkedManifestBytes = await readFile(join(checkedAudioPath, "manifest.json"));
    assert.deepEqual(await readFile(join(firstPath, "manifest.json")), checkedManifestBytes);
    assert.deepEqual(await readFile(join(secondPath, "manifest.json")), checkedManifestBytes);
    const manifest = JSON.parse(checkedManifestBytes);
    assert.equal(manifest.schema_version, 1);
    assert.match(manifest.candidate_status, /requires Alan approval and device mix confirmation/u);
    assert.match(manifest.candidate_status, /not a recording or final master/u);
    assert.equal(manifest.assets.length, 16);
    assert.equal(manifest.assets.filter(({ kind }) => kind === "sfx").length, 14);
    assert.equal(manifest.assets.filter(({ kind }) => kind === "ambience").length, 2);

    const expectedFiles = manifest.assets.map(({ file }) => file).sort();
    const checkedFiles = (await readdir(checkedAudioPath)).filter((name) => name.endsWith(".wav")).sort();
    assert.deepEqual(checkedFiles, expectedFiles, "checked-in commercial WAV closure must be exact");
    for (const asset of manifest.assets) {
      const checkedBytes = await readFile(join(checkedAudioPath, asset.file));
      assert.deepEqual(await readFile(join(firstPath, asset.file)), checkedBytes, `${asset.file} is stale relative to the generator`);
      assert.deepEqual(await readFile(join(secondPath, asset.file)), checkedBytes, `${asset.file} changed between deterministic renders`);
      assert.equal(sha256(checkedBytes), asset.sha256, `${asset.file} hash does not match the runtime manifest`);
    }
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("commercial audio WAVs satisfy the fixed stereo PCM and loop safety contract", async () => {
  const sources = JSON.parse(await readFile(sourcePath, "utf8"));
  const manifest = JSON.parse(await readFile(join(checkedAudioPath, "manifest.json"), "utf8"));
  const manifestById = new Map(manifest.assets.map((asset) => [asset.id, asset]));
  const requiredIds = [
    "nectar_collect", "pollination_bloom", "observe_rustle", "evade_dart", "honey_loss",
    "repair_tap", "seed_place", "seed_shell_rustle", "warmth_link", "carry_log", "handoff",
    "complete", "hive_room_loop", "field_day_loop",
  ];
  for (const requiredId of requiredIds) assert.ok(manifestById.has(requiredId), `missing required commercial sound: ${requiredId}`);

  for (const spec of sources.assets) {
    assert.ok(spec.design_layers.length >= 3, `${spec.id} must be layered rather than a simple tone`);
    const parsed = parsePcm16Wave(await readFile(join(checkedAudioPath, spec.file)));
    assert.equal(parsed.channels, sources.channels, `${spec.file} channel count`);
    assert.equal(parsed.sampleRate, sources.sample_rate, `${spec.file} sample rate`);
    assert.equal(parsed.bits, sources.pcm_bits, `${spec.file} PCM depth`);
    assert.equal(parsed.frames, spec.frames, `${spec.file} frame count`);
    const targetPeak = 10 ** (spec.target_peak_dbfs / 20);
    assert.ok(Math.abs(parsed.peak - targetPeak) <= 2 / 32767, `${spec.file} peak target drifted`);
    assert.ok(Math.abs(parsed.leftDc) < 0.0015 && Math.abs(parsed.rightDc) < 0.0015, `${spec.file} has excessive DC`);
    assert.ok(parsed.stereoDifferenceRms > 0.001, `${spec.file} collapsed to a mono/simple notification`);
    assert.ok(parsed.distinctSamplePairs > 500, `${spec.file} lacks sufficient layered sample variation`);
    if (spec.kind === "sfx") {
      assert.ok(Math.abs(parsed.left[0]) <= 1 && Math.abs(parsed.right[0]) <= 1, `${spec.file} does not fade in from zero`);
      assert.ok(Math.abs(parsed.left.at(-1)) <= 1 && Math.abs(parsed.right.at(-1)) <= 1, `${spec.file} does not fade out to zero`);
    } else {
      for (const channel of [parsed.left, parsed.right]) {
        assert.ok(Math.abs(channel.at(-1) - channel[0]) <= 1, `${spec.file} loop value seam is discontinuous`);
        const outgoingSlope = channel.at(-1) - channel.at(-2);
        const incomingSlope = channel[1] - channel[0];
        assert.ok(Math.abs(outgoingSlope - incomingSlope) <= 5, `${spec.file} loop slope seam is discontinuous`);
      }
    }
  }
});

test("credits record the candidate status and exact generated audio provenance", async () => {
  const manifestBytes = await readFile(join(checkedAudioPath, "manifest.json"));
  const manifest = JSON.parse(manifestBytes);
  const credits = JSON.parse(await readFile(creditsPath, "utf8"));
  const provenance = credits.asset_provenance?.find(({ asset_set }) => asset_set === "commercial_sfx_and_ambience_v1");
  assert.ok(provenance, "credits are missing commercial audio provenance");
  assert.equal(provenance.generator_path, manifest.generator);
  assert.equal(provenance.generator_sha256, manifest.generator_sha256);
  assert.equal(provenance.parameters_path, manifest.source_parameters);
  assert.equal(provenance.parameters_sha256, manifest.source_parameters_sha256);
  assert.equal(provenance.runtime_manifest_path, "res://assets/audio/commercial/manifest.json");
  assert.equal(provenance.runtime_manifest_sha256, sha256(manifestBytes));
  assert.deepEqual(provenance.third_party_sources, []);
  assert.equal(provenance.approval_status, "candidate_requires_alan_and_device_mix_confirmation");
  assert.equal(provenance.approved_by, null);
  assert.equal(provenance.approved_at, null);
  assert.match(provenance.creation_method, /不是录音/u);
  assert.match(provenance.creation_method, /不是终稿/u);
  assert.deepEqual(
    provenance.files.map(({ path, sha256: digest }) => [path, digest]),
    manifest.assets.map(({ file, sha256: digest }) => [`res://assets/audio/commercial/${file}`, digest]),
  );
});

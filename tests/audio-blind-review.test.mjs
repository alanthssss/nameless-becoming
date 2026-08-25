import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { runInNewContext } from "node:vm";

import {
  BLIND_TRACKS,
  CANONICAL_PAIRS,
  generateAudioBlindReview,
  validateAudioExportAnswers,
} from "../scripts/prepare_audio_blind_review.mjs";

const repositoryRoot = new URL("../", import.meta.url);
const repositoryPath = fileURLToPath(repositoryRoot);

async function sha256(path) {
  return createHash("sha256").update(await readFile(path)).digest("hex");
}

function exerciseExclusivePlayback(listenerJavaScript) {
  class FakeTarget {
    constructor() {
      this.listeners = new Map();
    }

    addEventListener(name, callback) {
      const callbacks = this.listeners.get(name) || [];
      callbacks.push(callback);
      this.listeners.set(name, callbacks);
    }

    dispatch(name) {
      for (const callback of this.listeners.get(name) || []) callback();
    }
  }

  class FakeAudio extends FakeTarget {
    constructor() {
      super();
      this.currentTime = 0;
      this.pauseCalls = 0;
      this.paused = true;
    }

    play() {
      this.paused = false;
      this.dispatch("play");
    }

    pause() {
      this.pauseCalls += 1;
      this.paused = true;
      this.dispatch("pause");
    }
  }

  const ids = ["A", "B", "C", "D", "E", "F", "G", "H"];
  const audios = Object.fromEntries(ids.map((id) => [id, new FakeAudio()]));
  const stats = Object.fromEntries(ids.map((id) => [id, { textContent: "" }]));
  const form = Object.assign(new FakeTarget(), { elements: [], reset() {} });
  const buttons = {
    "#save-button": new FakeTarget(),
    "#export-button": new FakeTarget(),
    "#reset-button": new FakeTarget(),
  };
  const document = {
    body: {
      dataset: {
        productVersion: "0.9.5-rc.2",
        generatorCommit: "f57ea02c",
        generatorFullCommit: "f".repeat(40),
        generatorDirty: "false",
        trackManifestSha256: "a".repeat(64),
      },
    },
    querySelector(selector) {
      if (selector === "#review-form") return form;
      if (selector === "#save-status") return { textContent: "" };
      if (buttons[selector]) return buttons[selector];
      const audioId = selector.match(/^\[data-audio="([A-H])"\]$/)?.[1];
      if (audioId) return audios[audioId];
      const statsId = selector.match(/^\[data-stats="([A-H])"\]$/)?.[1];
      if (statsId) return stats[statsId];
      throw new Error(`Unexpected querySelector call: ${selector}`);
    },
    querySelectorAll(selector) {
      if (selector === "audio[data-audio]") return Object.values(audios);
      if (selector === '[name="overall_replay_top3"]') return [];
      throw new Error(`Unexpected querySelectorAll call: ${selector}`);
    },
  };
  const localStorage = {
    getItem() { return null; },
    removeItem() {},
    setItem() {},
  };
  class EmptyFormData {
    entries() { return [][Symbol.iterator](); }
  }

  runInNewContext(listenerJavaScript, {
    Blob,
    document,
    FormData: EmptyFormData,
    localStorage,
    URL,
    window: { clearTimeout, confirm: () => true, setTimeout },
  });

  audios.A.play();
  assert.equal(audios.A.paused, false);
  assert.equal(audios.B.pauseCalls, 0, "already-paused tracks should not receive redundant pause calls");
  audios.B.play();
  assert.equal(audios.A.paused, true, "starting B must pause A");
  assert.equal(audios.A.pauseCalls, 1);
  assert.equal(audios.B.paused, false);
  audios.H.play();
  assert.equal(audios.B.paused, true, "starting H must pause the previously active B");
  assert.equal(audios.H.paused, false);
  assert.equal(Object.values(audios).filter((audio) => !audio.paused).length, 1);
}

test("pins all eight reviewed WAV sources and the fixed blind mapping", async () => {
  assert.deepEqual(BLIND_TRACKS.map(({ id, source }) => [id, source]), [
    ["A", "summer_explore.wav"],
    ["B", "winter_boss.wav"],
    ["C", "spring_explore.wav"],
    ["D", "autumn_boss.wav"],
    ["E", "winter_explore.wav"],
    ["F", "summer_boss.wav"],
    ["G", "autumn_explore.wav"],
    ["H", "spring_boss.wav"],
  ]);
  assert.deepEqual(CANONICAL_PAIRS, [["A", "F"], ["B", "E"], ["C", "H"], ["D", "G"]]);
  assert.equal(new Set(BLIND_TRACKS.map(({ id }) => id)).size, 8);
  assert.equal(new Set(BLIND_TRACKS.map(({ source }) => source)).size, 8);

  for (const track of BLIND_TRACKS) {
    const source = new URL(`godot/assets/music/${track.source}`, repositoryRoot);
    assert.equal(await sha256(source), track.sha256, `${track.source} changed without an explicit review-manifest update`);
  }
});

test("blocks an export whose overall section and all pair guesses are blank", () => {
  assert.match(validateAudioExportAnswers({}), /整段空白/);
  assert.match(validateAudioExportAnswers({ overall_drums_bass: "   ", pair_guess_1: "" }), /整段空白/);
  assert.equal(validateAudioExportAnswers({ overall_distinction: "大多数能区分" }), "");
  assert.equal(validateAudioExportAnswers({ pair_guess_1: "AF" }), "");
});

test("generates byte-identical anonymized audio and a separate developer answer key", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-audio-review-"));
  const output = join(temporaryRoot, "package");
  try {
    const result = await generateAudioBlindReview(output);
    assert.equal(result.output, output);
    assert.equal(await readFile(join(output, ".nameless-audio-blind-review"), "utf8"), "nameless-audio-blind-review:v1\n");

    for (const track of BLIND_TRACKS) {
      assert.equal(await sha256(join(output, "listener", "tracks", `${track.id}.wav`)), track.sha256);
    }

    const key = JSON.parse(await readFile(join(output, "reviewer", "answer-key.json"), "utf8"));
    assert.equal(key.schema_version, 1, "package identity is an additive field for existing answer-key readers");
    assert.match(key.package_identity.generator_full_commit, /^[0-9a-f]{40}$/u);
    assert.match(key.package_identity.track_manifest_sha256, /^[0-9a-f]{64}$/u);
    assert.deepEqual(key.sequence.map(({ blind_id, source }) => [blind_id, source]),
      BLIND_TRACKS.map(({ id, source }) => [id, `godot/assets/music/${source}`]));
    assert.deepEqual(key.canonical_pairs, CANONICAL_PAIRS);
    assert.match(await readFile(join(output, "reviewer", "README.md"), "utf8"), /正确的共享动机配对/);

    await generateAudioBlindReview(output);
    assert.equal(await sha256(join(output, "listener", "tracks", "A.wav")), BLIND_TRACKS[0].sha256);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("refuses protected paths and existing directories not owned by the generator", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-audio-review-safety-"));
  const unrelatedDirectory = join(temporaryRoot, "existing-project");
  const guardFile = join(unrelatedDirectory, "keep.txt");
  await mkdir(unrelatedDirectory);
  await writeFile(guardFile, "do not delete\n", "utf8");
  try {
    await assert.rejects(generateAudioBlindReview(repositoryPath), /protected output path/);
    await assert.rejects(generateAudioBlindReview(dirname(repositoryPath)), /protected output path/);
    await assert.rejects(generateAudioBlindReview(join(repositoryPath, "godot/assets/music")), /protected output path/);
    await assert.rejects(generateAudioBlindReview(join(repositoryPath, "godot/assets/music/review")), /music source directory/);
    await assert.rejects(generateAudioBlindReview(unrelatedDirectory), /without \.nameless-audio-blind-review/);
    assert.equal(await readFile(guardFile, "utf8"), "do not delete\n");
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("keeps source names, roles, seasons, hashes, and canonical pairs out of listener assets", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-audio-review-ui-"));
  const output = join(temporaryRoot, "package");
  try {
    await generateAudioBlindReview(output);
    const listenerAssets = await Promise.all([
      readFile(join(output, "listener", "index.html"), "utf8"),
      readFile(join(output, "listener", "styles.css"), "utf8"),
      readFile(join(output, "listener", "review.js"), "utf8"),
    ]);
    const listenerText = listenerAssets.join("\n");
    const listenerJavaScript = listenerAssets[2];

    assert.doesNotMatch(listenerText, /spring|summer|autumn|winter|explore|boss|春|夏|秋|冬/i);
    for (const { source, sha256: sourceSha256 } of BLIND_TRACKS) {
      assert.doesNotMatch(listenerText, new RegExp(source.replace(".", "\\."), "i"));
      assert.doesNotMatch(listenerText, new RegExp(sourceSha256, "i"));
    }
    for (const [first, second] of CANONICAL_PAIRS) {
      assert.doesNotMatch(listenerText, new RegExp(`${first}\\s*[-–—/]\\s*${second}`, "i"));
    }

    assert.match(listenerText, /track_A_mood/);
    assert.match(listenerText, /track_H_fatigue_at/);
    assert.match(listenerText, /overall_drums_bass/);
    assert.match(listenerText, /overall_folk/);
    assert.match(listenerText, /pair_guess_4/);
    assert.match(listenerText, /track_manifest_sha256/);
    assert.match(listenerText, /整段空白无法区分/);
    assert.match(listenerText, /导出 JSON/);
    assert.match(listenerText, /localStorage/);
    assert.match(listenerJavaScript, /function pauseOtherTracks/);
    assert.match(listenerJavaScript, /candidate !== activeAudio && !candidate\.paused/);
    exerciseExclusivePlayback(listenerJavaScript);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

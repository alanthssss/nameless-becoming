#!/usr/bin/env node
/** Build a two-role, four-track anonymous autumn direction listener.
 *
 * This package asks only which direction deserves another iteration. It is not
 * a replacement-readiness review. The listener never receives internal style
 * labels, source filenames, or the separate reviewer answer key.
 */

import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import {
  copyFile,
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  realpath,
  rename,
  rm,
  writeFile,
} from "node:fs/promises";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";


const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const DEFAULT_SOURCE = join(repositoryRoot, "outputs", "autumn-direction-sketches");
const SENTINEL = "nameless-autumn-direction-sketches:v1\n";
const LISTENER_SCHEMA = "nameless-autumn-direction-listener/v1";
const CHOICE_SCHEMA = "nameless-autumn-direction-choice/v1";

export const OFFICIAL_WAV_SHA256 = Object.freeze({
  "autumn_boss.wav": "d9ff59d8de8fb35c9200251dc7ce18eb7740dd71d17cb5f44004eb51c92c6d84",
  "autumn_explore.wav": "e22b01786dfb50041aa76f3fb43ea769ce5239bd9f2c7f7e9bafb74bb3dd1d66",
  "spring_boss.wav": "df1b22d280ba3e3d18627d48bea1ad02cb1f2164007176180e6d39b1f438b3ed",
  "spring_explore.wav": "b443b5efe895bb5365c2b66d135def4656a6b2a409bbd3757c4784ce5bea4f6c",
  "summer_boss.wav": "7fcdbc2d35242f8981ce11d48844443621fd1a3ad00104d44fe721c1bf7e634e",
  "summer_explore.wav": "9ea49bc76c610dc0fcad3c74d3a308662637d48558a68cf2d7f216c1d239f353",
  "winter_boss.wav": "a11aaca193b51483d572e9411854970940e7d12e43b86001f6226e3cc915eeaa",
  "winter_explore.wav": "26f5e344a6f83fb8beba8574b2db687c8b7015927113c3d21af750e294902910",
});

export const BLIND_SKETCHES = Object.freeze([
  Object.freeze({ id: "K", role: "explore", source: "explore_amber_circuit" }),
  Object.freeze({ id: "Q", role: "explore", source: "explore_seed_funk" }),
  Object.freeze({ id: "T", role: "boss", source: "boss_stoptime_industrial" }),
  Object.freeze({ id: "Z", role: "boss", source: "boss_postpunk_dub" }),
]);

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

async function fileSha256(path) {
  return sha256(await readFile(path));
}

function git(...args) {
  return execFileSync("git", args, { cwd: repositoryRoot, encoding: "utf8" }).trim();
}

async function currentRendererIdentity() {
  return {
    commit: git("rev-parse", "HEAD"),
    dirty: git("status", "--porcelain").length > 0,
    script_sha256: await fileSha256(join(repositoryRoot, "scripts", "generate_autumn_direction_sketches.py")),
  };
}

function isWithin(parent, child) {
  const path = relative(parent, child);
  return path === "" || (!path.startsWith(`..${sep}`) && path !== ".." && !isAbsolute(path));
}

async function canonicalParent(path) {
  let candidate = resolve(path);
  const suffix = [];
  while (true) {
    try {
      const canonical = await realpath(candidate);
      return resolve(canonical, ...suffix.reverse());
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      const parent = dirname(candidate);
      if (parent === candidate) throw new Error(`Cannot resolve an existing parent for ${path}`);
      suffix.push(candidate.slice(parent.length + (parent.endsWith(sep) ? 0 : 1)));
      candidate = parent;
    }
  }
}

async function assertSafeOutput(output) {
  const canonicalRepository = await realpath(repositoryRoot);
  const canonicalOutput = await canonicalParent(output);
  if (isWithin(canonicalRepository, canonicalOutput) || isWithin(canonicalOutput, canonicalRepository)) {
    throw new Error("Listener package must be outside the repository and must not be one of its ancestors.");
  }
  if (canonicalOutput === resolve(canonicalOutput, sep)) {
    throw new Error("Refusing to use a filesystem root as output.");
  }
}

async function ownedOutputIdentity(output) {
  const info = await lstat(output);
  if (info.isSymbolicLink() || !info.isDirectory()) throw new Error(`Output is a symlink or not a directory: ${output}`);
  const markerPath = join(output, ".nameless-autumn-direction-sketches");
  const markerInfo = await lstat(markerPath).catch(() => null);
  if (!markerInfo || markerInfo.isSymbolicLink() || !markerInfo.isFile()) {
    throw new Error(`Refusing to replace unowned output: ${output}`);
  }
  const marker = await readFile(markerPath, "utf8");
  if (marker !== SENTINEL) throw new Error(`Refusing to replace unowned output: ${output}`);
  return { device: info.dev, inode: info.ino, markerDevice: markerInfo.dev, markerInode: markerInfo.ino };
}

async function replaceOnlyOwnedOutput(output, staged) {
  let initial;
  try {
    initial = await ownedOutputIdentity(output);
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  if (!initial) {
    await rename(staged, output);
    return;
  }

  const current = await ownedOutputIdentity(output);
  if (JSON.stringify(current) !== JSON.stringify(initial)) throw new Error(`Output changed during replacement: ${output}`);
  const backup = await mkdtemp(join(dirname(output), ".nameless-autumn-direction-backup-"));
  await rm(backup, { recursive: true });
  await rename(output, backup);
  try {
    await rename(staged, output);
  } catch (error) {
    await rename(backup, output);
    throw error;
  }
  await rm(backup, { recursive: true });
}

function assertManifestTrack(track) {
  if (track.meter !== "4/4" || track.phrase !== "4+4 bars" || track.bars !== 8) {
    throw new Error(`${track.key}: not the approved 4/4, 4+4 direction-sketch form`);
  }
  if (!(track.duration_seconds >= 15 && track.duration_seconds <= 20)) {
    throw new Error(`${track.key}: duration outside 15–20 seconds`);
  }
  if (Math.abs(track.metrics.integrated_lufs - track.target_lufs) > 0.3) {
    throw new Error(`${track.key}: deterministic loudness outside ±0.3 LU target`);
  }
  if (track.metrics.cubic_peak_estimate_dbtp > -1) throw new Error(`${track.key}: deterministic peak estimate above -1 dBTP`);
  if (track.metrics.longest_dropout_ms < 250) throw new Error(`${track.key}: no real arrangement dropout`);
  if (track.metrics.mono_compatibility_loss_db > 0.8) throw new Error(`${track.key}: mono compatibility loss too high`);
  if (track.pitch_motion !== "stepped only; no portamento" || track.legacy_material !== "none") {
    throw new Error(`${track.key}: rejected legacy motion/material returned`);
  }
}

export function validateDirectionAnswers(answers = {}) {
  if (!["K", "Q", "both", "neither"].includes(answers.explore_direction)) {
    return "请选择探索组方向；可以明确选择“都不要”。";
  }
  if (!["T", "Z", "both", "neither"].includes(answers.boss_direction)) {
    return "请选择 Boss 组方向；可以明确选择“都不要”。";
  }
  if (answers.explore_direction === "neither" && !String(answers.explore_note || "").trim()) {
    return "探索组选择“都不要”时，请写最不对的感觉；不用专业术语。";
  }
  if (answers.boss_direction === "neither" && !String(answers.boss_note || "").trim()) {
    return "Boss 组选择“都不要”时，请写最不对的感觉；不用专业术语。";
  }
  return "";
}

function ffmpegMetrics(path) {
  const result = spawnSync("ffmpeg", [
    "-hide_banner", "-nostats", "-i", path,
    "-filter_complex", "ebur128=peak=true", "-f", "null", "-",
  ], { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  if (result.error) throw new Error(`ffmpeg is required for standards-grade loudness analysis: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`ffmpeg failed for ${path}: ${result.stderr}`);
  const output = `${result.stdout}\n${result.stderr}`;
  const loudness = [...output.matchAll(/^\s*I:\s*(-?\d+(?:\.\d+)?)\s+LUFS$/gm)].at(-1);
  const peak = [...output.matchAll(/^\s*Peak:\s*(-?\d+(?:\.\d+)?)\s+dBFS$/gm)].at(-1);
  if (!loudness || !peak) throw new Error(`Could not parse ffmpeg EBU R128 summary for ${path}`);
  return { integrated_lufs: Number(loudness[1]), true_peak_dbtp: Number(peak[1]) };
}

const css = `
:root { color-scheme: dark; font-family: Inter, "PingFang SC", system-ui, sans-serif; background: #101713; color: #f5edd7; }
* { box-sizing: border-box; }
body { margin: 0; min-width: 320px; background: radial-gradient(circle at 15% 0%, #604f253d, transparent 35rem), #101713; }
button, textarea, input { font: inherit; }
.shell { width: min(880px, calc(100% - 1.5rem)); margin: auto; padding: 2.5rem 0 7rem; }
.eyebrow { color: #e6bd59; font-size: .78rem; font-weight: 800; letter-spacing: .16em; }
h1 { max-width: 18ch; font-size: clamp(2rem, 7vw, 4.2rem); line-height: 1.03; }
.lede, .muted { color: #b8c4ba; line-height: 1.7; }
.protocol, .group { margin: 1rem 0; padding: clamp(1rem, 3vw, 1.6rem); border: 1px solid #43574a; border-radius: 1rem; background: #17231dcc; }
.tracks { display: grid; grid-template-columns: 1fr 1fr; gap: .8rem; }
.track { padding: 1rem; border: 1px solid #4d6153; border-radius: .8rem; background: #111a16; }
.letter { color: #e6bd59; font-size: 2.2rem; font-weight: 800; }
audio { width: 100%; margin: .7rem 0; accent-color: #e6bd59; }
.stats { color: #87998d; font-size: .76rem; }
fieldset { margin: 1.2rem 0 0; padding: 0; border: 0; }
legend { margin-bottom: .7rem; font-weight: 800; }
.choices { display: flex; flex-wrap: wrap; gap: .65rem 1rem; }
.choices label { display: flex; align-items: center; gap: .35rem; }
input[type=radio] { accent-color: #e6bd59; }
textarea { width: 100%; min-height: 4.5rem; margin-top: .6rem; padding: .7rem; border: 1px solid #506557; border-radius: .6rem; background: #101914; color: inherit; }
.actions { position: fixed; right: 1rem; bottom: 1rem; left: 1rem; display: flex; justify-content: center; align-items: center; gap: .7rem; width: fit-content; max-width: calc(100% - 2rem); margin: auto; padding: .65rem; border: 1px solid #53685a; border-radius: .9rem; background: #0d1511ee; }
button { padding: .7rem 1rem; border: 1px solid #e6bd59; border-radius: .6rem; background: #d5aa42; color: #172017; font-weight: 800; cursor: pointer; }
#status { min-width: 8rem; color: #9eafa3; font-size: .8rem; }
@media (max-width: 640px) { .tracks { grid-template-columns: 1fr; } .shell { padding-top: 1rem; } }
`;

export const LISTENER_JAVASCRIPT = `
const form = document.querySelector("#direction-form");
const status = document.querySelector("#status");
const ids = ["K", "Q", "T", "Z"];
const listening = Object.fromEntries(ids.map((id) => [id, { plays: 0, seconds: 0 }]));
const identity = { schema: document.body.dataset.schema, package_sha256: document.body.dataset.packageSha256 };
const storageKey = "nameless-autumn-direction-" + identity.package_sha256;
${validateDirectionAnswers.toString()}

function answers() { return Object.fromEntries(new FormData(form).entries()); }
function snapshot() {
  return {
    schema_version: "${CHOICE_SCHEMA}",
    package_identity: identity,
    responses: answers(),
    listening: Object.fromEntries(Object.entries(listening).map(([id, value]) => [id, { plays: value.plays, seconds: Math.round(value.seconds) }])),
  };
}
function syncConditionalRequirements() {
  const current = answers();
  form.elements.explore_note.required = current.explore_direction === "neither";
  form.elements.boss_note.required = current.boss_direction === "neither";
}
function setStatus(message) { status.textContent = message; }
function save() { localStorage.setItem(storageKey, JSON.stringify(snapshot())); setStatus("已保存在本机"); }
function restore() {
  let saved;
  try { saved = JSON.parse(localStorage.getItem(storageKey) || "null"); } catch { return; }
  if (!saved || saved.package_identity?.schema !== identity.schema
    || saved.package_identity?.package_sha256 !== identity.package_sha256) return;
  for (const control of form.elements) {
    if (!control.name) continue;
    const value = saved.responses?.[control.name];
    if (control.type === "radio") control.checked = control.value === value;
    else if (typeof value === "string") control.value = value;
  }
  for (const id of ids) Object.assign(listening[id], saved.listening?.[id] || {});
  refreshStats();
  setStatus("已恢复本机记录");
}
function refreshStats() {
  for (const id of ids) document.querySelector('[data-stats="' + id + '"]').textContent =
    "播放 " + listening[id].plays + " 次 · 累计 " + Math.round(listening[id].seconds) + " 秒";
}
for (const id of ids) {
  const audio = document.querySelector('[data-audio="' + id + '"]');
  let previous = 0;
  audio.addEventListener("play", () => {
    for (const other of document.querySelectorAll("audio")) if (other !== audio && !other.paused) other.pause();
    listening[id].plays += 1; previous = audio.currentTime; refreshStats();
  });
  audio.addEventListener("timeupdate", () => {
    if (!audio.paused && audio.currentTime >= previous) listening[id].seconds += audio.currentTime - previous;
    previous = audio.currentTime;
  });
}
form.addEventListener("input", () => {
  syncConditionalRequirements();
  clearTimeout(window.autumnSaveTimer);
  window.autumnSaveTimer = setTimeout(save, 250);
});
document.querySelector("#export").addEventListener("click", () => {
  syncConditionalRequirements();
  const problem = validateDirectionAnswers(answers());
  if (problem) { setStatus(problem); form.reportValidity(); return; }
  const result = { ...snapshot(), exported_at: new Date().toISOString() };
  const blob = new Blob([JSON.stringify(result, null, 2) + "\\n"], { type: "application/json" });
  const link = document.createElement("a"); link.href = URL.createObjectURL(blob);
  link.download = "autumn-direction-choice-2026-08-25.json"; link.click(); URL.revokeObjectURL(link.href);
  setStatus("已导出，请发回 JSON"); save();
});
restore(); syncConditionalRequirements(); refreshStats();
`;

function listenerHtml(packageSha) {
  const trackCard = (id) => `
    <article class="track">
      <div class="letter">${id}</div>
      <audio controls preload="metadata" data-audio="${id}" src="tracks/${id}.wav"></audio>
      <div class="stats" data-stats="${id}">播放 0 次 · 累计 0 秒</div>
    </article>`;
  return `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>秋季音乐方向选择</title><style>${css}</style></head>
<body data-schema="${CHOICE_SCHEMA}" data-package-sha256="${packageSha}">
<main class="shell"><p class="eyebrow">DIRECTION SKETCHES · BLIND</p><h1>只选值得继续发展的方向</h1>
<p class="lede">四条都是 15–20 秒草图，不是成品，也不与上一轮候选比较。每组可多听几遍；如果都不对，请直接选“都不要”。</p>
<section class="protocol"><strong>试听顺序</strong><p class="muted">先把系统音量固定。组内来回切换，关注节奏是否有抓力、留白是否自然、主钩在小音箱上是否仍清楚。页面不会显示风格名或版本。</p></section>
<form id="direction-form">
  <section class="group"><h2>探索方向组</h2><div class="tracks">${trackCard("K")}${trackCard("Q")}</div>
    <fieldset><legend>更值得继续发展的是：</legend><div class="choices">
      <label><input required type="radio" name="explore_direction" value="K">K</label>
      <label><input type="radio" name="explore_direction" value="Q">Q</label>
      <label><input type="radio" name="explore_direction" value="both">两个都可继续</label>
      <label><input type="radio" name="explore_direction" value="neither">都不要</label>
    </div></fieldset><label>可选；若选“都不要”则必填<textarea name="explore_note" placeholder="写最不对的感觉即可（如没劲／廉价／太吵／阴沉／不像秋天），不用专业术语"></textarea></label>
  </section>
  <section class="group"><h2>Boss 方向组</h2><div class="tracks">${trackCard("T")}${trackCard("Z")}</div>
    <fieldset><legend>更值得继续发展的是：</legend><div class="choices">
      <label><input required type="radio" name="boss_direction" value="T">T</label>
      <label><input type="radio" name="boss_direction" value="Z">Z</label>
      <label><input type="radio" name="boss_direction" value="both">两个都可继续</label>
      <label><input type="radio" name="boss_direction" value="neither">都不要</label>
    </div></fieldset><label>可选；若选“都不要”则必填<textarea name="boss_note" placeholder="写最不对的感觉即可（如没劲／廉价／太吵／阴沉／不像秋天），不用专业术语"></textarea></label>
  </section>
</form></main><div class="actions"><button id="export" type="button">导出 JSON</button><span id="status" aria-live="polite"></span></div>
<script>${LISTENER_JAVASCRIPT}</script></body></html>`;
}

export async function generateAutumnDirectionPackage(outputPath, sourcePath = DEFAULT_SOURCE) {
  const output = resolve(outputPath);
  const source = resolve(sourcePath);
  await assertSafeOutput(output);

  const manifestBytes = await readFile(join(source, "manifest.json"));
  const manifest = JSON.parse(manifestBytes);
  if (manifest.schema_version !== "nameless-autumn-direction-sketches/v1") throw new Error("Unexpected sketch manifest schema");
  const expectedRenderer = await currentRendererIdentity();
  if (JSON.stringify(manifest.renderer) !== JSON.stringify(expectedRenderer)) throw new Error("Sketch renderer identity differs from the current checkout");
  if (JSON.stringify(manifest.official_wav_scope_fence) !== JSON.stringify(OFFICIAL_WAV_SHA256)) throw new Error("Official WAV fence differs from package builder");
  for (const [name, expected] of Object.entries(OFFICIAL_WAV_SHA256)) {
    if (await fileSha256(join(repositoryRoot, "godot", "assets", "music", name)) !== expected) throw new Error(`${name}: shipping WAV changed`);
  }
  const tracksByKey = new Map(manifest.tracks.map((track) => [track.key, track]));
  if (tracksByKey.size !== 4) throw new Error("Expected exactly four direction sketches");
  for (const track of tracksByKey.values()) {
    assertManifestTrack(track);
    if (await fileSha256(join(source, `${track.key}.wav`)) !== track.wav_sha256) throw new Error(`${track.key}: source hash mismatch`);
  }
  for (const role of ["explore", "boss"]) {
    const roleTracks = [...tracksByKey.values()].filter((track) => track.role === role);
    if (roleTracks.length !== 2) throw new Error(`${role}: expected two sketches`);
    if (Math.abs(roleTracks[0].metrics.integrated_lufs - roleTracks[1].metrics.integrated_lufs) > 0.3) throw new Error(`${role}: loudness mismatch exceeds ±0.3 LU`);
  }

  const parent = dirname(output);
  await mkdir(parent, { recursive: true });
  const staged = await mkdtemp(join(parent, ".nameless-autumn-direction-staged-"));
  let transferred = false;
  try {
  await mkdir(join(staged, "listener", "tracks"), { recursive: true });
  await mkdir(join(staged, "reviewer"), { recursive: true });
  await writeFile(join(staged, ".nameless-autumn-direction-sketches"), SENTINEL);

  const sourceManifestSha = sha256(manifestBytes);
  const publicTracks = [];
  const answerTracks = [];
  for (const blind of BLIND_SKETCHES) {
    const track = tracksByKey.get(blind.source);
    if (!track || track.role !== blind.role) throw new Error(`${blind.id}: invalid hidden mapping`);
    await copyFile(join(source, `${blind.source}.wav`), join(staged, "listener", "tracks", `${blind.id}.wav`));
    publicTracks.push({ id: blind.id, role: blind.role, sha256: track.wav_sha256, duration_seconds: track.duration_seconds });
    const measured = ffmpegMetrics(join(source, `${blind.source}.wav`));
    if (Math.abs(measured.integrated_lufs - track.target_lufs) > 0.3) throw new Error(`${blind.source}: ffmpeg loudness outside ±0.3 LU target`);
    if (measured.true_peak_dbtp > -1) throw new Error(`${blind.source}: ffmpeg true peak above -1 dBTP`);
    answerTracks.push({
      ...blind,
      internal_direction: track.internal_direction,
      source_sha256: track.wav_sha256,
      deterministic_metrics: track.metrics,
      ffmpeg_ebur128: measured,
    });
  }
  for (const role of ["explore", "boss"]) {
    const roleTracks = answerTracks.filter((track) => track.role === role);
    if (Math.abs(roleTracks[0].ffmpeg_ebur128.integrated_lufs - roleTracks[1].ffmpeg_ebur128.integrated_lufs) > 0.3) {
      throw new Error(`${role}: ffmpeg role match exceeds ±0.3 LU`);
    }
  }
  const packageDefinition = {
    schema_version: LISTENER_SCHEMA,
    choice_schema: CHOICE_SCHEMA,
    source_manifest_sha256: sourceManifestSha,
    interface_sha256: sha256(`${css}\0${LISTENER_JAVASCRIPT}\0${listenerHtml.toString()}`),
    tracks: publicTracks,
  };
  const packageSha = sha256(JSON.stringify(packageDefinition));
  await writeFile(join(staged, "listener", "index.html"), listenerHtml(packageSha));
  await writeFile(join(staged, "listener", "manifest.json"), JSON.stringify({
    ...packageDefinition,
    package_identity_sha256: packageSha,
  }, null, 2) + "\n");
  await writeFile(join(staged, "reviewer", "answer-key.json"), JSON.stringify({
    schema_version: "nameless-autumn-direction-answer-key/v1",
    disposition: "Keep outside listener; directions are hypotheses, not accepted replacements.",
    source_manifest_sha256: sourceManifestSha,
    package_identity_sha256: packageSha,
    source_renderer: manifest.renderer,
    generator: { commit: git("rev-parse", "HEAD"), dirty: git("status", "--porcelain").length > 0 },
    tracks: answerTracks,
  }, null, 2) + "\n");
  await writeFile(join(staged, "README.txt"), "Open listener/index.html. Do not open reviewer/answer-key.json before exporting the choice JSON.\n");
  await replaceOnlyOwnedOutput(output, staged);
  transferred = true;
  return {
    output,
    listener: join(output, "listener", "index.html"),
    answerKey: join(output, "reviewer", "answer-key.json"),
    sourceManifestSha,
    packageSha,
  };
  } finally {
    if (!transferred) await rm(staged, { recursive: true, force: true });
  }
}

function usage() {
  console.error("Usage: node scripts/prepare_autumn_direction_sketches.mjs --output /absolute/outside/repo/path [--source PATH]");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const outputIndex = args.indexOf("--output");
  const sourceIndex = args.indexOf("--source");
  if (outputIndex < 0 || !args[outputIndex + 1]) { usage(); process.exitCode = 2; }
  else generateAutumnDirectionPackage(args[outputIndex + 1], sourceIndex >= 0 ? args[sourceIndex + 1] : DEFAULT_SOURCE)
    .then((result) => console.log(JSON.stringify(result, null, 2)))
    .catch((error) => { console.error(error.stack || error); process.exitCode = 1; });
}

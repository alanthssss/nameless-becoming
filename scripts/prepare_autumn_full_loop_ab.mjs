#!/usr/bin/env node
/** Build a loudness-matched, answer-isolated final A/B for the two autumn loops. */

import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import {
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
const musicRoot = join(repositoryRoot, "godot", "assets", "music");
const SENTINEL_NAME = ".nameless-autumn-full-loop-ab";
const SENTINEL = "nameless-autumn-full-loop-ab:v1\n";
const LISTENER_SCHEMA = "nameless-autumn-full-loop-listener/v1";
const RESULT_SCHEMA = "nameless-autumn-full-loop-ab/v1";

export const BASELINE_COMMIT = "69baa742fadaba567ae0ec53eeb56ebf6ab35bd2";
export const SOURCE_HASHES = Object.freeze({
  baseline: Object.freeze({
    autumn_explore: "e22b01786dfb50041aa76f3fb43ea769ce5239bd9f2c7f7e9bafb74bb3dd1d66",
    autumn_boss: "d9ff59d8de8fb35c9200251dc7ce18eb7740dd71d17cb5f44004eb51c92c6d84",
  }),
  candidate: Object.freeze({
    autumn_explore: "de25c797c9dcb49eabee9adc61630dba21493a985ec2dc79ddb115f2d8f4b23a",
    autumn_boss: "b571d75a05be755422214ddf7fd851fa31148c3a7feae7fa896d558340d95701",
  }),
});

export const BLIND_TRACKS = Object.freeze([
  Object.freeze({ id: "C", role: "explore", version: "baseline", target_lufs: -18.0 }),
  Object.freeze({ id: "Y", role: "explore", version: "candidate", target_lufs: -18.0 }),
  Object.freeze({ id: "M", role: "boss", version: "candidate", target_lufs: -19.0 }),
  Object.freeze({ id: "R", role: "boss", version: "baseline", target_lufs: -19.0 }),
]);

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function git(...args) {
  return execFileSync("git", args, { cwd: repositoryRoot, encoding: "utf8" }).trim();
}

function sourcePath(role) {
  return `godot/assets/music/autumn_${role}.wav`;
}

function sourceBytes(track) {
  if (track.version === "baseline") {
    return execFileSync("git", ["show", `${BASELINE_COMMIT}:${sourcePath(track.role)}`], {
      cwd: repositoryRoot,
      maxBuffer: 16 * 1024 * 1024,
    });
  }
  return readFile(join(musicRoot, `autumn_${track.role}.wav`));
}

function wavInfo(bytes) {
  if (bytes.toString("ascii", 0, 4) !== "RIFF" || bytes.toString("ascii", 8, 12) !== "WAVE") {
    throw new Error("Expected a RIFF/WAVE source");
  }
  let offset = 12;
  let format;
  let dataSize;
  while (offset + 8 <= bytes.length) {
    const id = bytes.toString("ascii", offset, offset + 4);
    const size = bytes.readUInt32LE(offset + 4);
    const start = offset + 8;
    if (id === "fmt ") {
      format = {
        encoding: bytes.readUInt16LE(start),
        channels: bytes.readUInt16LE(start + 2),
        sample_rate: bytes.readUInt32LE(start + 4),
        byte_rate: bytes.readUInt32LE(start + 8),
        bits_per_sample: bytes.readUInt16LE(start + 14),
      };
    } else if (id === "data") {
      dataSize = size;
    }
    offset = start + size + (size % 2);
  }
  if (!format || dataSize === undefined) throw new Error("Incomplete WAV header");
  return { ...format, duration_seconds: dataSize / format.byte_rate };
}

function ffmpegMetrics(path) {
  const result = spawnSync("ffmpeg", [
    "-hide_banner", "-nostats", "-i", path,
    "-filter_complex", "ebur128=peak=true", "-f", "null", "-",
  ], { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  if (result.error) throw new Error(`ffmpeg is required: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`ffmpeg failed for ${path}: ${result.stderr}`);
  const output = `${result.stdout}\n${result.stderr}`;
  const loudness = [...output.matchAll(/^\s*I:\s*(-?\d+(?:\.\d+)?)\s+LUFS$/gm)].at(-1);
  const peak = [...output.matchAll(/^\s*Peak:\s*(-?\d+(?:\.\d+)?)\s+dBFS$/gm)].at(-1);
  if (!loudness || !peak) throw new Error(`Could not parse EBU R128 summary for ${path}`);
  return { integrated_lufs: Number(loudness[1]), true_peak_dbtp: Number(peak[1]) };
}

function renderMatched(input, output, gainDb) {
  const result = spawnSync("ffmpeg", [
    "-y", "-hide_banner", "-loglevel", "error", "-i", input,
    "-af", `volume=${gainDb.toFixed(3)}dB`,
    "-c:a", "pcm_s16le", "-ar", "44100", "-ac", "2", output,
  ], { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  if (result.error) throw new Error(`ffmpeg is required: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`ffmpeg normalization failed: ${result.stderr}`);
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
      return resolve(await realpath(candidate), ...suffix.reverse());
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      const parent = dirname(candidate);
      if (parent === candidate) throw new Error(`Cannot resolve parent for ${path}`);
      suffix.push(candidate.slice(parent.length + (parent.endsWith(sep) ? 0 : 1)));
      candidate = parent;
    }
  }
}

async function assertSafeOutput(output) {
  const canonicalRepository = await realpath(repositoryRoot);
  const canonicalOutput = await canonicalParent(output);
  if (isWithin(canonicalRepository, canonicalOutput) || isWithin(canonicalOutput, canonicalRepository)) {
    throw new Error("A/B package must be outside the repository and not one of its ancestors.");
  }
  if (canonicalOutput === resolve(canonicalOutput, sep)) throw new Error("Refusing filesystem root output.");
}

async function assertOwnedOutput(output) {
  const info = await lstat(output);
  if (info.isSymbolicLink() || !info.isDirectory()) throw new Error(`Unsafe output: ${output}`);
  const marker = join(output, SENTINEL_NAME);
  const markerInfo = await lstat(marker).catch(() => null);
  if (!markerInfo || markerInfo.isSymbolicLink() || !markerInfo.isFile()
    || await readFile(marker, "utf8") !== SENTINEL) {
    throw new Error(`Refusing to replace unowned output: ${output}`);
  }
}

async function replaceOwnedOutput(output, staged) {
  try {
    await assertOwnedOutput(output);
  } catch (error) {
    if (error?.code === "ENOENT") {
      await rename(staged, output);
      return;
    }
    throw error;
  }
  const backup = await mkdtemp(join(dirname(output), ".nameless-autumn-full-loop-backup-"));
  await rm(backup, { recursive: true });
  await rename(output, backup);
  try {
    await rename(staged, output);
  } catch (error) {
    await rename(backup, output);
    throw error;
  }
  await rm(backup, { recursive: true, force: true });
}

export function validateFinalAnswers(answers = {}) {
  if (!["C", "Y", "tie", "neither"].includes(answers.explore_choice)) {
    return "请选择采集/探索组的结果。";
  }
  if (!["M", "R", "tie", "neither"].includes(answers.boss_choice)) {
    return "请选择遭遇/Boss 组的结果。";
  }
  if (["tie", "neither"].includes(answers.explore_choice)
    && !String(answers.explore_note || "").trim()) {
    return "采集/探索组选择“一样好”或“都不接受”时，请写明原因。";
  }
  if (["tie", "neither"].includes(answers.boss_choice)
    && !String(answers.boss_note || "").trim()) {
    return "遭遇/Boss 组选择“一样好”或“都不接受”时，请写明原因。";
  }
  return "";
}

const css = `
:root{color-scheme:dark;font-family:Inter,"PingFang SC",system-ui,sans-serif;background:#0e1512;color:#f5ecd7}*{box-sizing:border-box}
body{margin:0;min-width:320px;background:radial-gradient(circle at 12% 0%,#6b55263d,transparent 36rem),#0e1512}
button,textarea,input{font:inherit}.shell{width:min(900px,calc(100% - 1.5rem));margin:auto;padding:2.2rem 0 7rem}
.eyebrow{color:#e6bd59;font-size:.78rem;font-weight:800;letter-spacing:.16em}h1{max-width:18ch;font-size:clamp(2rem,7vw,4rem);line-height:1.04}
.lede,.muted{color:#b8c4ba;line-height:1.7}.protocol,.group{margin:1rem 0;padding:clamp(1rem,3vw,1.6rem);border:1px solid #43574a;border-radius:1rem;background:#17231dcc}
.tracks{display:grid;grid-template-columns:1fr 1fr;gap:.8rem}.track{padding:1rem;border:1px solid #4d6153;border-radius:.8rem;background:#111a16}
.letter{color:#e6bd59;font-size:2.2rem;font-weight:800}audio{width:100%;margin:.7rem 0;accent-color:#e6bd59}.stats{color:#87998d;font-size:.76rem}
fieldset{margin:1.2rem 0 0;padding:0;border:0}legend{margin-bottom:.7rem;font-weight:800}.choices{display:flex;flex-wrap:wrap;gap:.65rem 1rem}.choices label{display:flex;align-items:center;gap:.35rem}
input[type=radio]{accent-color:#e6bd59}textarea{width:100%;min-height:4.5rem;margin-top:.6rem;padding:.7rem;border:1px solid #506557;border-radius:.6rem;background:#101914;color:inherit}
.actions{position:fixed;right:1rem;bottom:1rem;left:1rem;display:flex;justify-content:center;align-items:center;gap:.7rem;width:fit-content;max-width:calc(100% - 2rem);margin:auto;padding:.65rem;border:1px solid #53685a;border-radius:.9rem;background:#0d1511ee}
button{padding:.7rem 1rem;border:1px solid #e6bd59;border-radius:.6rem;background:#d5aa42;color:#172017;font-weight:800;cursor:pointer}#status{min-width:8rem;color:#9eafa3;font-size:.8rem}
@media(max-width:640px){.tracks{grid-template-columns:1fr}.shell{padding-top:1rem}}
`;

export const LISTENER_JAVASCRIPT = `
const form=document.querySelector("#ab-form");const status=document.querySelector("#status");const ids=["C","Y","M","R"];
const listening=Object.fromEntries(ids.map(id=>[id,{plays:0,seconds:0}]));const identity={schema:document.body.dataset.schema,package_sha256:document.body.dataset.packageSha256};
const storageKey="nameless-autumn-full-loop-"+identity.package_sha256;${validateFinalAnswers.toString()}
function answers(){return Object.fromEntries(new FormData(form).entries())}function snapshot(){return{schema_version:"${RESULT_SCHEMA}",package_identity:identity,responses:answers(),listening:Object.fromEntries(Object.entries(listening).map(([id,value])=>[id,{plays:value.plays,seconds:Math.round(value.seconds)}]))}}
function setStatus(message){status.textContent=message}function save(){localStorage.setItem(storageKey,JSON.stringify(snapshot()));setStatus("已保存在本机")}
function refresh(){for(const id of ids)document.querySelector('[data-stats="'+id+'"]').textContent="播放 "+listening[id].plays+" 次 · 累计 "+Math.round(listening[id].seconds)+" 秒"}
function sync(){const current=answers();form.elements.explore_note.required=["tie","neither"].includes(current.explore_choice);form.elements.boss_note.required=["tie","neither"].includes(current.boss_choice)}
function restore(){let saved;try{saved=JSON.parse(localStorage.getItem(storageKey)||"null")}catch{return}if(!saved||saved.package_identity?.schema!==identity.schema||saved.package_identity?.package_sha256!==identity.package_sha256)return;for(const control of form.elements){if(!control.name)continue;const value=saved.responses?.[control.name];if(control.type==="radio")control.checked=control.value===value;else if(typeof value==="string")control.value=value}for(const id of ids)Object.assign(listening[id],saved.listening?.[id]||{});refresh();setStatus("已恢复本机记录")}
for(const id of ids){const audio=document.querySelector('[data-audio="'+id+'"]');let previous=0;audio.addEventListener("play",()=>{for(const other of document.querySelectorAll("audio"))if(other!==audio&&!other.paused)other.pause();listening[id].plays+=1;previous=audio.currentTime;refresh()});audio.addEventListener("timeupdate",()=>{if(!audio.paused&&audio.currentTime>=previous)listening[id].seconds+=audio.currentTime-previous;previous=audio.currentTime})}
form.addEventListener("input",()=>{sync();clearTimeout(window.autumnSaveTimer);window.autumnSaveTimer=setTimeout(save,250)});
document.querySelector("#export").addEventListener("click",()=>{sync();const problem=validateFinalAnswers(answers());if(problem){setStatus(problem);form.reportValidity();return}const result={...snapshot(),exported_at:new Date().toISOString()};const blob=new Blob([JSON.stringify(result,null,2)+"\\n"],{type:"application/json"});const link=document.createElement("a");link.href=URL.createObjectURL(blob);link.download="autumn-full-loop-ab-2026-08-25.json";link.click();URL.revokeObjectURL(link.href);setStatus("已导出，请发回 JSON");save()});restore();sync();refresh();
`;

function listenerHtml(packageSha) {
  const card = (id) => `<article class="track"><div class="letter">${id}</div><audio controls loop preload="metadata" data-audio="${id}" src="tracks/${id}.wav"></audio><div class="stats" data-stats="${id}">播放 0 次 · 累计 0 秒</div></article>`;
  const choices = (name, left, right) => `<fieldset><legend>你更愿意把哪一个留在游戏里？</legend><div class="choices"><label><input required type="radio" name="${name}" value="${left}">${left}</label><label><input type="radio" name="${name}" value="${right}">${right}</label><label><input type="radio" name="${name}" value="tie">一样好</label><label><input type="radio" name="${name}" value="neither">都不接受</label></div></fieldset>`;
  return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>秋季音乐完整循环 A/B</title><style>${css}</style></head>
<body data-schema="${RESULT_SCHEMA}" data-package-sha256="${packageSha}"><main class="shell"><p class="eyebrow">FULL LOOP · BLIND A/B</p><h1>判断哪一版值得留在游戏里</h1><p class="lede">四条都是完整循环，组内响度已经匹配。页面不显示制作顺序；不要猜哪条更新，只判断长期玩的时候你愿意听哪条。</p>
<section class="protocol"><strong>建议方法</strong><p class="muted">系统音量固定。每条至少听到一次段落停顿，再在组内来回切换。重点听：节奏是否抓人但不乱、低音是否有弹性、留白是否自然、循环后会不会烦。</p></section><form id="ab-form">
<section class="group"><h2>采集 / 探索组</h2><div class="tracks">${card("C")}${card("Y")}</div>${choices("explore_choice", "C", "Y")}<label>可选；选“一样好”或“都不接受”时必填<textarea name="explore_note" placeholder="说具体感受即可，不用音乐术语"></textarea></label></section>
<section class="group"><h2>遭遇 / Boss 组</h2><div class="tracks">${card("M")}${card("R")}</div>${choices("boss_choice", "M", "R")}<label>可选；选“一样好”或“都不接受”时必填<textarea name="boss_note" placeholder="哪一段有力量、哪一段乱、哪里听久了不舒服？"></textarea></label></section>
</form></main><div class="actions"><button id="export" type="button">导出 JSON</button><span id="status" aria-live="polite"></span></div><script>${LISTENER_JAVASCRIPT}</script></body></html>`;
}

export async function generateAutumnFullLoopAb(outputPath) {
  const output = resolve(outputPath);
  await assertSafeOutput(output);
  const parent = dirname(output);
  await mkdir(parent, { recursive: true });
  const staged = await mkdtemp(join(parent, ".nameless-autumn-full-loop-stage-"));
  const sources = await mkdtemp(join(parent, ".nameless-autumn-full-loop-source-"));
  let transferred = false;
  try {
    await mkdir(join(staged, "listener", "tracks"), { recursive: true });
    await mkdir(join(staged, "reviewer"), { recursive: true });
    await writeFile(join(staged, SENTINEL_NAME), SENTINEL);
    const publicTracks = [];
    const answerTracks = [];
    for (const track of BLIND_TRACKS) {
      const key = `autumn_${track.role}`;
      const bytes = await sourceBytes(track);
      const sourceHash = sha256(bytes);
      if (sourceHash !== SOURCE_HASHES[track.version][key]) {
        throw new Error(`${track.version} ${key} source hash mismatch: ${sourceHash}`);
      }
      const info = wavInfo(bytes);
      if (info.encoding !== 1 || info.channels !== 2 || info.sample_rate !== 44100 || info.bits_per_sample !== 16) {
        throw new Error(`${track.id}: source is not 44.1 kHz stereo PCM16`);
      }
      const input = join(sources, `${track.id}-source.wav`);
      const audition = join(staged, "listener", "tracks", `${track.id}.wav`);
      await writeFile(input, bytes);
      const sourceMetrics = ffmpegMetrics(input);
      const gainDb = track.target_lufs - sourceMetrics.integrated_lufs;
      renderMatched(input, audition, gainDb);
      const auditionBytes = await readFile(audition);
      const auditionMetrics = ffmpegMetrics(audition);
      if (Math.abs(auditionMetrics.integrated_lufs - track.target_lufs) > 0.15) {
        throw new Error(`${track.id}: loudness target missed`);
      }
      if (auditionMetrics.true_peak_dbtp > -1.0) throw new Error(`${track.id}: true peak exceeds -1 dBTP`);
      publicTracks.push({
        id: track.id,
        role: track.role,
        sha256: sha256(auditionBytes),
        duration_seconds: Number(wavInfo(auditionBytes).duration_seconds.toFixed(6)),
        integrated_lufs: auditionMetrics.integrated_lufs,
        true_peak_dbtp: auditionMetrics.true_peak_dbtp,
      });
      answerTracks.push({
        ...track,
        source_commit: track.version === "baseline" ? BASELINE_COMMIT : git("rev-parse", "HEAD"),
        source_path: sourcePath(track.role),
        source_sha256: sourceHash,
        source_metrics: sourceMetrics,
        audition_gain_db: Number(gainDb.toFixed(3)),
        audition_sha256: sha256(auditionBytes),
        audition_metrics: auditionMetrics,
      });
    }
    for (const role of ["explore", "boss"]) {
      const pair = publicTracks.filter((track) => track.role === role);
      if (pair.length !== 2 || Math.abs(pair[0].integrated_lufs - pair[1].integrated_lufs) > 0.3) {
        throw new Error(`${role}: A/B loudness mismatch exceeds 0.3 LU`);
      }
    }
    const definition = {
      schema_version: LISTENER_SCHEMA,
      result_schema: RESULT_SCHEMA,
      interface_sha256: sha256(`${css}\0${LISTENER_JAVASCRIPT}\0${listenerHtml.toString()}`),
      tracks: publicTracks,
    };
    const packageSha = sha256(JSON.stringify(definition));
    await writeFile(join(staged, "listener", "index.html"), listenerHtml(packageSha));
    await writeFile(join(staged, "listener", "manifest.json"), JSON.stringify({
      ...definition,
      package_identity_sha256: packageSha,
    }, null, 2) + "\n");
    await writeFile(join(staged, "reviewer", "answer-key.json"), JSON.stringify({
      schema_version: "nameless-autumn-full-loop-answer-key/v1",
      disposition: "Keep outside listener. This branch remains unmerged until the exported A/B is interpreted.",
      package_identity_sha256: packageSha,
      baseline_commit: BASELINE_COMMIT,
      candidate: {
        commit: git("rev-parse", "HEAD"),
        dirty: git("status", "--porcelain").length > 0,
        generator_sha256: sha256(await readFile(join(repositoryRoot, "scripts", "generate_music_variations.py"))),
      },
      tracks: answerTracks,
    }, null, 2) + "\n");
    await writeFile(join(staged, "reviewer", "README.md"), "# 协调说明\n\n只把 `listener/` 用于作答。导出 JSON 前不要查看 `answer-key.json`。正式音频分支尚未获准合并。\n");
    await writeFile(join(staged, "README.txt"), "Open listener/index.html. Send back the exported JSON before reading reviewer/answer-key.json.\n");
    await replaceOwnedOutput(output, staged);
    transferred = true;
    return {
      output,
      listener: join(output, "listener", "index.html"),
      answerKey: join(output, "reviewer", "answer-key.json"),
      packageSha,
    };
  } finally {
    await rm(sources, { recursive: true, force: true });
    if (!transferred) await rm(staged, { recursive: true, force: true });
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const index = process.argv.indexOf("--output");
  if (index < 0 || !process.argv[index + 1]) {
    console.error("Usage: node scripts/prepare_autumn_full_loop_ab.mjs --output /absolute/outside/repo/path");
    process.exitCode = 2;
  } else {
    generateAutumnFullLoopAb(process.argv[index + 1])
      .then((result) => console.log(JSON.stringify(result, null, 2)))
      .catch((error) => { console.error(error.stack || error); process.exitCode = 1; });
  }
}

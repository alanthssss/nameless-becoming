import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFile, lstat, mkdir, readFile, realpath, rename, rm, writeFile } from "node:fs/promises";
import { basename, dirname, isAbsolute, parse, relative, resolve } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);
const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const musicRoot = resolve(repositoryRoot, "godot/assets/music");
const defaultOutput = resolve(repositoryRoot, "outputs/music-blind-review");
const outputSentinelName = ".nameless-audio-blind-review";
const outputSentinel = "nameless-audio-blind-review:v1\n";

export const BLIND_TRACKS = Object.freeze([
  Object.freeze({ id: "A", source: "summer_explore.wav", sha256: "9ea49bc76c610dc0fcad3c74d3a308662637d48558a68cf2d7f216c1d239f353" }),
  Object.freeze({ id: "B", source: "winter_incident.wav", sha256: "a11aaca193b51483d572e9411854970940e7d12e43b86001f6226e3cc915eeaa" }),
  Object.freeze({ id: "C", source: "spring_explore.wav", sha256: "b443b5efe895bb5365c2b66d135def4656a6b2a409bbd3757c4784ce5bea4f6c" }),
  Object.freeze({ id: "D", source: "autumn_incident.wav", sha256: "b571d75a05be755422214ddf7fd851fa31148c3a7feae7fa896d558340d95701" }),
  Object.freeze({ id: "E", source: "winter_explore.wav", sha256: "26f5e344a6f83fb8beba8574b2db687c8b7015927113c3d21af750e294902910" }),
  Object.freeze({ id: "F", source: "summer_incident.wav", sha256: "7fcdbc2d35242f8981ce11d48844443621fd1a3ad00104d44fe721c1bf7e634e" }),
  Object.freeze({ id: "G", source: "autumn_explore.wav", sha256: "de25c797c9dcb49eabee9adc61630dba21493a985ec2dc79ddb115f2d8f4b23a" }),
  Object.freeze({ id: "H", source: "spring_incident.wav", sha256: "df1b22d280ba3e3d18627d48bea1ad02cb1f2164007176180e6d39b1f438b3ed" }),
]);

export const CANONICAL_PAIRS = Object.freeze([
  Object.freeze(["A", "F"]),
  Object.freeze(["B", "E"]),
  Object.freeze(["C", "H"]),
  Object.freeze(["D", "G"]),
]);

export function validateAudioExportAnswers(answers = {}) {
  const overallFields = [
    "overall_favorite",
    "overall_replay_top3",
    "pairing_confidence",
    "overall_distinction",
    "overall_drums_bass",
    "overall_folk",
    "overall_fatigue",
  ];
  const pairFields = ["pair_guess_1", "pair_guess_2", "pair_guess_3", "pair_guess_4"];
  const hasValue = (value) => Array.isArray(value)
    ? value.some((item) => String(item).trim().length > 0)
    : String(value || "").trim().length > 0;
  if (![...overallFields, ...pairFields].some((field) => hasValue(answers[field]))) {
    return "请先填写至少一项整体感受或配对判断；整段空白无法区分‘没有意见’和‘漏填’。";
  }
  return "";
}

const listenerCss = `
:root {
  color-scheme: dark;
  font-family: Inter, "PingFang SC", "Microsoft YaHei", system-ui, sans-serif;
  background: #0f1714;
  color: #f5edd6;
  font-synthesis: none;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  min-width: 320px;
  background:
    radial-gradient(circle at 16% 0%, rgba(224, 174, 62, 0.16), transparent 30rem),
    linear-gradient(160deg, #13231d 0%, #0d1512 60%, #111a16 100%);
}

button, input, select, textarea { font: inherit; }

button, select, input, textarea {
  border: 1px solid #53695b;
  border-radius: 0.65rem;
  background: #17251f;
  color: #f5edd6;
}

fieldset { margin: 0; padding: 0; border: 0; }

button { cursor: pointer; padding: 0.75rem 1rem; }
button:hover, button:focus-visible { border-color: #e5b94e; outline: 2px solid rgba(229, 185, 78, 0.25); }
input, select, textarea { width: 100%; padding: 0.65rem 0.75rem; }
textarea { min-height: 5.8rem; resize: vertical; }
input[type="checkbox"], input[type="radio"] { width: auto; accent-color: #e5b94e; }

.shell { width: min(1180px, calc(100% - 2rem)); margin: 0 auto; padding: 2.5rem 0 7rem; }
.hero { display: grid; gap: 0.8rem; padding: 1.5rem 0 2rem; }
.eyebrow { margin: 0; color: #e5b94e; font-size: 0.78rem; font-weight: 800; letter-spacing: 0.18em; }
h1, h2, h3, p { margin-top: 0; }
h1 { max-width: 18ch; margin-bottom: 0; font-size: clamp(2rem, 6vw, 4.4rem); line-height: 1.02; }
.lede { max-width: 66ch; margin-bottom: 0; color: #c8d1c9; line-height: 1.8; }
.protocol, .overall, .track-card { border: 1px solid #405448; background: rgba(22, 37, 31, 0.92); box-shadow: 0 18px 50px rgba(0, 0, 0, 0.22); }
.protocol, .overall { border-radius: 1.1rem; padding: clamp(1rem, 3vw, 1.8rem); }
.protocol ol { margin: 0; padding-left: 1.25rem; color: #d9ded8; line-height: 1.8; }
.meta-grid, .overall-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }
.field { display: grid; align-content: start; gap: 0.42rem; color: #e8e4d6; }
.field small { color: #9eb0a4; line-height: 1.5; }
.full { grid-column: 1 / -1; }
.section-title { margin: 3rem 0 1rem; }
.section-title p { margin-bottom: 0; color: #9eb0a4; }
.track-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }
.track-card { border-radius: 1.1rem; padding: clamp(1rem, 3vw, 1.4rem); }
.track-heading { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; }
.track-letter { margin-bottom: 0.8rem; color: #e5b94e; font-size: 2.3rem; line-height: 1; }
.listening-stats { color: #9eb0a4; font-size: 0.78rem; }
audio { width: 100%; margin-bottom: 1rem; accent-color: #e5b94e; }
.track-fields { display: grid; gap: 0.85rem; }
.tag-list, .choice-list { display: flex; flex-wrap: wrap; gap: 0.55rem 0.9rem; }
.tag-list label, .choice-list label { display: inline-flex; align-items: center; gap: 0.35rem; color: #cad4cc; }
.pair-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 0.75rem; }
.sticky-actions {
  position: fixed;
  z-index: 10;
  right: 1rem;
  bottom: 1rem;
  left: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.6rem;
  width: fit-content;
  max-width: calc(100% - 2rem);
  margin: auto;
  padding: 0.7rem;
  border: 1px solid #52675a;
  border-radius: 1rem;
  background: rgba(11, 19, 15, 0.94);
  backdrop-filter: blur(12px);
}
.primary { border-color: #e5b94e; background: #d6a932; color: #172017; font-weight: 800; }
.danger { color: #e8b9a9; }
.save-status { min-width: 7rem; color: #9eb0a4; font-size: 0.78rem; text-align: center; }
.notice { margin-top: 1rem; color: #9eb0a4; font-size: 0.85rem; line-height: 1.6; }

@media (max-width: 760px) {
  .shell { width: min(100% - 1rem, 42rem); padding-top: 1rem; }
  .track-grid, .meta-grid, .overall-grid { grid-template-columns: 1fr; }
  .pair-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .full { grid-column: auto; }
  .sticky-actions { overflow-x: auto; justify-content: flex-start; }
  .sticky-actions button { flex: 0 0 auto; }
}
`;

const listenerJs = `
const trackIds = ["A", "B", "C", "D", "E", "F", "G", "H"];
const form = document.querySelector("#review-form");
const saveStatus = document.querySelector("#save-status");
const listening = Object.fromEntries(trackIds.map((id) => [id, { plays: 0, seconds: 0 }]));
const packageIdentity = {
  product_version: document.body.dataset.productVersion,
  generator_commit: document.body.dataset.generatorCommit,
  generator_full_commit: document.body.dataset.generatorFullCommit,
  generator_dirty: document.body.dataset.generatorDirty === "true",
  track_manifest_sha256: document.body.dataset.trackManifestSha256,
};
const storageKey = "nameless-music-blind-review-v1-" + [
  packageIdentity.product_version,
  packageIdentity.generator_full_commit,
  packageIdentity.generator_dirty ? "dirty" : "clean",
  packageIdentity.track_manifest_sha256,
].map(encodeURIComponent).join("-");
${validateAudioExportAnswers.toString()}

function samePackageIdentity(left, right) {
  if (!left || !right) return false;
  return left.product_version === right.product_version
    && left.generator_commit === right.generator_commit
    && left.generator_full_commit === right.generator_full_commit
    && Boolean(left.generator_dirty) === Boolean(right.generator_dirty)
    && left.track_manifest_sha256 === right.track_manifest_sha256;
}

function formAnswers() {
  const answers = {};
  for (const [key, value] of new FormData(form).entries()) {
    if (Object.hasOwn(answers, key)) {
      answers[key] = Array.isArray(answers[key]) ? [...answers[key], value] : [answers[key], value];
    } else {
      answers[key] = value;
    }
  }
  return answers;
}

function snapshot() {
  const roundedListening = Object.fromEntries(
    Object.entries(listening).map(([id, value]) => [id, { plays: value.plays, seconds: Math.round(value.seconds) }]),
  );
  return { schema_version: 1, package_identity: packageIdentity, answers: formAnswers(), listening: roundedListening };
}

function setStatus(message) {
  saveStatus.textContent = message;
}

function save() {
  try {
    localStorage.setItem(storageKey, JSON.stringify(snapshot()));
    setStatus("已保存在本机");
  } catch {
    setStatus("请直接导出结果");
  }
}

function restore() {
  let saved;
  try {
    saved = JSON.parse(localStorage.getItem(storageKey) || "null");
  } catch {
    return;
  }
  if (!saved || ![1, 2].includes(saved.schema_version) || !samePackageIdentity(saved.package_identity, packageIdentity)) return;
  for (const control of form.elements) {
    if (!control.name) continue;
    const value = saved.answers?.[control.name];
    if (control.type === "checkbox" || control.type === "radio") {
      const values = Array.isArray(value) ? value : [value];
      control.checked = values.includes(control.value);
    } else if (typeof value === "string") {
      control.value = value;
    }
  }
  for (const id of trackIds) {
    const metrics = saved.listening?.[id];
    if (metrics) {
      listening[id].plays = Number(metrics.plays) || 0;
      listening[id].seconds = Number(metrics.seconds) || 0;
    }
  }
  refreshListeningStats();
  setStatus("已恢复本机记录");
}

function refreshListeningStats() {
  for (const id of trackIds) {
    const value = listening[id];
    document.querySelector('[data-stats="' + id + '"]').textContent =
      "播放 " + value.plays + " 次 · 累计 " + Math.round(value.seconds) + " 秒";
  }
}

function pauseOtherTracks(activeAudio) {
  for (const candidate of document.querySelectorAll("audio[data-audio]")) {
    if (candidate !== activeAudio && !candidate.paused) candidate.pause();
  }
}

function attachListeningCounters() {
  for (const id of trackIds) {
    const audio = document.querySelector('[data-audio="' + id + '"]');
    let lastTime = null;
    audio.addEventListener("play", () => {
      pauseOtherTracks(audio);
      listening[id].plays += 1;
      lastTime = audio.currentTime;
      refreshListeningStats();
      save();
    });
    audio.addEventListener("timeupdate", () => {
      if (lastTime !== null) {
        const delta = audio.currentTime - lastTime;
        if (delta > 0 && delta < 2) listening[id].seconds += delta;
      }
      lastTime = audio.currentTime;
      refreshListeningStats();
    });
    for (const eventName of ["pause", "ended", "seeking"]) {
      audio.addEventListener(eventName, () => {
        lastTime = null;
        save();
      });
    }
  }
}

function enforceTopThree() {
  const boxes = [...document.querySelectorAll('[name="overall_replay_top3"]')];
  const checked = boxes.filter((box) => box.checked);
  for (const box of boxes) box.disabled = checked.length >= 3 && !box.checked;
}

function exportResults() {
  const answers = formAnswers();
  const validationMessage = validateAudioExportAnswers(answers);
  if (validationMessage) {
    setStatus(validationMessage);
    document.querySelector("#overall-title").scrollIntoView({ behavior: "smooth", block: "center" });
    return;
  }
  save();
  const payload = { ...snapshot(), exported_at: new Date().toISOString() };
  const blob = new Blob([JSON.stringify(payload, null, 2) + "\\n"], { type: "application/json" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = "music-blind-review-" + new Date().toISOString().slice(0, 10) + ".json";
  link.click();
  URL.revokeObjectURL(link.href);
  setStatus("结果已导出");
}

form.addEventListener("input", () => {
  enforceTopThree();
  setStatus("有未导出的修改");
  window.clearTimeout(form.saveTimer);
  form.saveTimer = window.setTimeout(save, 400);
});
document.querySelector("#save-button").addEventListener("click", save);
document.querySelector("#export-button").addEventListener("click", exportResults);
document.querySelector("#reset-button").addEventListener("click", () => {
  if (!window.confirm("清空本页填写内容和本机记录？已导出的 JSON 不受影响。")) return;
  window.clearTimeout(form.saveTimer);
  form.reset();
  for (const id of trackIds) listening[id] = { plays: 0, seconds: 0 };
  try { localStorage.removeItem(storageKey); } catch { /* Export remains available. */ }
  enforceTopThree();
  refreshListeningStats();
  setStatus("已清空");
});

attachListeningCounters();
restore();
enforceTopThree();
`;

function trackCard(id) {
  const tagChoices = ["电子", "Funk", "摇滚", "朋克", "民乐", "氛围", "说不清但有特点"];
  return `
    <article class="track-card" aria-labelledby="track-${id}">
      <div class="track-heading">
        <h3 class="track-letter" id="track-${id}">${id}</h3>
        <span class="listening-stats" data-stats="${id}">播放 0 次 · 累计 0 秒</span>
      </div>
      <audio controls loop preload="metadata" data-audio="${id}" src="tracks/${id}.wav">
        浏览器不支持音频播放，请换用较新的浏览器。
      </audio>
      <div class="track-fields">
        <label class="field">第一反应：情绪和画面
          <textarea name="track_${id}_mood" placeholder="不用专业术语，写你身体和脑中最直接的反应。"></textarea>
        </label>
        <label class="field">节奏感
          <select name="track_${id}_rhythm">
            <option value="">请选择</option>
            <option>舒缓</option><option>中速</option><option>有推进感</option><option>急促</option><option>忽快忽慢</option><option>难判断</option>
          </select>
        </label>
        <fieldset class="field">
          <legend>你实际听到的特点（可多选）</legend>
          <div class="tag-list">
            ${tagChoices.map((tag) => `<label><input type="checkbox" name="track_${id}_tags" value="${tag}"> ${tag}</label>`).join("")}
          </div>
        </fieldset>
        <label class="field">鼓点与低音
          <select name="track_${id}_groove">
            <option value="">请选择</option><option>支撑得刚好</option><option>还可以更明确</option><option>太满或太抢</option><option>松散、不稳</option><option>没有特别注意</option>
          </select>
        </label>
        <label class="field">民乐式点缀
          <select name="track_${id}_folk_accent">
            <option value="">请选择</option><option>没听出来</option><option>恰到好处</option><option>可以再多一点</option><option>有点画蛇添足</option><option>不确定是什么声音</option>
          </select>
        </label>
        <label class="field">开始疲劳、不舒服或刺耳的位置
          <input name="track_${id}_fatigue_at" inputmode="numeric" placeholder="例如 00:18；没有可写“无”">
          <small>可循环两到三遍再判断，并写明是哪个声音造成的。</small>
        </label>
        <label class="field">补充意见
          <textarea name="track_${id}_notes" placeholder="最喜欢的瞬间、想删掉的声音、是否适合长时间游玩……"></textarea>
        </label>
      </div>
    </article>`;
}

function listenerHtml(packageIdentity) {
  const options = BLIND_TRACKS.map(({ id }) => `<option>${id}</option>`).join("");
  const replayChoices = BLIND_TRACKS.map(({ id }) => `<label><input type="checkbox" name="overall_replay_top3" value="${id}"> ${id}</label>`).join("");
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self' blob:; media-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'">
  <title>八首音乐盲听记录</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body data-product-version="${packageIdentity.product_version}" data-generator-commit="${packageIdentity.generator_commit}" data-generator-full-commit="${packageIdentity.generator_full_commit}" data-generator-dirty="${packageIdentity.generator_dirty ? "true" : "false"}" data-track-manifest-sha256="${packageIdentity.track_manifest_sha256}">
  <main class="shell">
    <header class="hero">
      <p class="eyebrow">LOCAL BLIND LISTENING · A—H</p>
      <h1>先听身体反应，再找专业词。</h1>
      <p class="lede">本页只给音轨编号，不提供名称或用途。请尽量用同一副耳机或音箱、相近音量完成；答案会自动暂存在当前浏览器，也可随时导出 JSON。</p>
    </header>

    <section class="protocol" aria-labelledby="protocol-title">
      <h2 id="protocol-title">建议听法</h2>
      <ol>
        <li>第一轮依次听 A—H，每首至少完整听一遍，只记第一反应。</li>
        <li>第二轮将每首循环两到三遍，记录鼓点、低音、点缀与疲劳位置。</li>
        <li>最后再猜四组共享核心动机的配对，并选出愿意主动再听的三首。</li>
      </ol>
      <p class="notice">没有标准审美答案。配对有内部参照，但“好不好听、是否耐听、是否画蛇添足”只以你的真实反馈为准。</p>
      <div class="meta-grid">
        <label class="field">试听者代号
          <input name="listener_id" form="review-form" placeholder="例如 Alan-01；不要写敏感信息">
        </label>
        <label class="field">播放设备与环境
          <input name="listening_setup" form="review-form" placeholder="例如 MacBook 扬声器 / 有线耳机 / 安静房间">
        </label>
      </div>
    </section>

    <form id="review-form">
      <div class="section-title">
        <h2>逐首记录</h2>
        <p>播放次数与累计秒数只是帮助回忆，不代表完成质量。</p>
      </div>
      <div class="track-grid">${BLIND_TRACKS.map(({ id }) => trackCard(id)).join("")}</div>

      <section class="overall" aria-labelledby="overall-title">
        <h2 id="overall-title">听完八首以后</h2>
        <div class="overall-grid">
          <label class="field">最喜欢的一首
            <select name="overall_favorite"><option value="">请选择</option>${options}</select>
          </label>
          <fieldset class="field">
            <legend>愿意主动再听（最多三首）</legend>
            <div class="choice-list">${replayChoices}</div>
          </fieldset>
          <fieldset class="field full">
            <legend>你认为共享同一核心动机的四组配对</legend>
            <div class="pair-grid">
              ${[1, 2, 3, 4].map((index) => `<label>第 ${index} 组<input name="pair_guess_${index}" maxlength="3" placeholder="两个字母"></label>`).join("")}
            </div>
          </fieldset>
          <label class="field">配对把握
            <select name="pairing_confidence"><option value="">请选择</option><option>1 — 完全在猜</option><option>2</option><option>3 — 有些线索</option><option>4</option><option>5 — 非常明确</option></select>
          </label>
          <label class="field">八首之间的区分度
            <select name="overall_distinction"><option value="">请选择</option><option>都很容易区分</option><option>大多数能区分</option><option>有几首像同一首</option><option>整体像同一条伴奏</option></select>
          </label>
          <label class="field full">鼓点和 Bass 的整体建议
            <textarea name="overall_drums_bass" placeholder="哪些需要再加强、哪些已经足够、哪些反而太满？"></textarea>
          </label>
          <label class="field full">民乐式点缀的整体建议
            <textarea name="overall_folk" placeholder="哪些是加分，哪些像堆砌？如果完全没注意到，也请直接写。"></textarea>
          </label>
          <label class="field full">连续听完后的疲劳与总评
            <textarea name="overall_fatigue" placeholder="第几首或第几轮开始累？最想保留和最想调整的分别是什么？"></textarea>
          </label>
        </div>
      </section>
    </form>
  </main>

  <div class="sticky-actions" aria-label="记录操作">
    <button id="save-button" type="button">保存到本机</button>
    <button id="export-button" class="primary" type="button">导出 JSON</button>
    <button id="reset-button" class="danger" type="button">清空</button>
    <span id="save-status" class="save-status" aria-live="polite">尚未保存</span>
  </div>
  <script src="review.js"></script>
</body>
</html>
`;
}

async function sha256(path) {
  const payload = await readFile(path);
  return createHash("sha256").update(payload).digest("hex");
}

function answerKey(packageIdentity) {
  return {
    schema_version: 1,
    package_identity: packageIdentity,
    warning: "Developer-only answer key. Keep this directory separate from the listener UI until feedback is exported.",
    sequence: BLIND_TRACKS.map(({ id, source, sha256: sourceSha256 }) => ({
      blind_id: id,
      source: `godot/assets/music/${source}`,
      source_sha256: sourceSha256,
    })),
    canonical_pairs: CANONICAL_PAIRS.map(([first, second]) => [first, second]),
    listener_entry: "../listener/index.html",
  };
}

function reviewerReadme(packageIdentity) {
  const rows = BLIND_TRACKS.map(({ id, source, sha256: sourceSha256 }) => `| ${id} | \`${source}\` | \`${sourceSha256}\` |`).join("\n");
  const pairs = CANONICAL_PAIRS.map((pair) => pair.join("–")).join("、");
  return `# 开发者答案（勿在盲听前展示）

听众入口只有 \`../listener/index.html\`。本目录不被听众页面链接或加载。

证据包来源：\`${packageIdentity.product_version} · ${packageIdentity.generator_commit}${packageIdentity.generator_dirty ? " +dirty" : ""}\`；匿名音轨清单指纹：\`${packageIdentity.track_manifest_sha256}\`。

| 盲听编号 | 原始文件 | SHA-256 |
| --- | --- | --- |
${rows}

正确的共享动机配对：${pairs}。

听众导出的 JSON 只包含 A—H、填写结果和本地播放统计，不包含本答案。判断时请分开记录：配对命中是识别度证据；喜欢、耐循环、情绪和点缀是否多余是人工审美反馈，二者不能互相替代。
`;
}

function isWithin(parent, candidate) {
  const path = relative(parent, candidate);
  return path === "" || (!path.startsWith("..") && !isAbsolute(path));
}

function validateResolvedOutput(output) {
  if (output === parse(output).root) throw new Error("Refusing to replace a filesystem root.");
  if (isWithin(output, repositoryRoot)) throw new Error(`Refusing protected output path ${output}; it is the repository or one of its ancestors.`);
  if (isWithin(repositoryRoot, output) && !isWithin(resolve(repositoryRoot, "outputs"), output)) {
    throw new Error("Output inside the repository must stay under outputs/.");
  }
}

async function validateOutputTarget(outputDirectory) {
  const output = resolve(outputDirectory);
  validateResolvedOutput(output);
  let existingAncestor = output;
  const missingSegments = [];
  while (true) {
    try {
      await lstat(existingAncestor);
      break;
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      const parent = dirname(existingAncestor);
      if (parent === existingAncestor) throw new Error(`Unable to resolve output target: ${output}.`);
      missingSegments.unshift(basename(existingAncestor));
      existingAncestor = parent;
    }
  }
  validateResolvedOutput(resolve(await realpath(existingAncestor), ...missingSegments));
  return output;
}

async function assertReplaceableOutput(output) {
  let status;
  try {
    status = await lstat(output);
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
  if (!status.isDirectory()) {
    throw new Error(`Refusing to replace non-directory output: ${output}.`);
  }
  let sentinel;
  try {
    sentinel = await readFile(resolve(output, outputSentinelName), "utf8");
  } catch (error) {
    if (error?.code === "ENOENT") {
      throw new Error(`Refusing to replace existing directory without ${outputSentinelName}: ${output}.`);
    }
    throw error;
  }
  if (sentinel !== outputSentinel) {
    throw new Error(`Refusing to replace existing directory with an invalid ${outputSentinelName}: ${output}.`);
  }
  return true;
}

export async function generateAudioBlindReview(outputDirectory = defaultOutput) {
  const output = await validateOutputTarget(outputDirectory);
  const packageJson = JSON.parse(await readFile(resolve(repositoryRoot, "package.json"), "utf8"));
  const [{ stdout: commitOutput }, { stdout: statusOutput }] = await Promise.all([
    execFileAsync("git", ["rev-parse", "HEAD"], { cwd: repositoryRoot }),
    execFileAsync("git", ["status", "--porcelain=v1", "--untracked-files=normal"], { cwd: repositoryRoot }),
  ]);
  const fullCommit = commitOutput.trim();
  if (!/^[0-9a-f]{40}$/u.test(fullCommit)) throw new Error(`Unexpected git commit: ${fullCommit}`);
  const packageIdentity = {
    product_version: String(packageJson.version),
    generator_commit: fullCommit.slice(0, 8),
    generator_full_commit: fullCommit,
    generator_dirty: statusOutput.trim().length > 0,
    track_manifest_sha256: createHash("sha256").update(JSON.stringify(BLIND_TRACKS.map(({ id, sha256: trackSha256 }) => [id, trackSha256]))).digest("hex"),
  };
  const stage = `${output}.stage-${process.pid}-${Date.now()}`;
  const listenerDirectory = resolve(stage, "listener");
  const trackDirectory = resolve(listenerDirectory, "tracks");
  const reviewerDirectory = resolve(stage, "reviewer");
  const replaceExisting = await assertReplaceableOutput(output);
  await mkdir(dirname(output), { recursive: true });
  await mkdir(stage);

  try {
    await mkdir(trackDirectory, { recursive: true });
    await mkdir(reviewerDirectory, { recursive: true });
    for (const track of BLIND_TRACKS) {
      const source = resolve(musicRoot, track.source);
      const sourceHash = await sha256(source);
      if (sourceHash !== track.sha256) {
        throw new Error(`${track.source} has SHA-256 ${sourceHash}; expected ${track.sha256}. Update the reviewed manifest deliberately before continuing.`);
      }
      const destination = resolve(trackDirectory, `${track.id}.wav`);
      await copyFile(source, destination);
      const destinationHash = await sha256(destination);
      if (destinationHash !== sourceHash) throw new Error(`Byte-preserving copy failed for blind track ${track.id}.`);
    }

    await Promise.all([
      writeFile(resolve(listenerDirectory, "index.html"), listenerHtml(packageIdentity), "utf8"),
      writeFile(resolve(listenerDirectory, "styles.css"), listenerCss, "utf8"),
      writeFile(resolve(listenerDirectory, "review.js"), listenerJs, "utf8"),
      writeFile(resolve(reviewerDirectory, "answer-key.json"), `${JSON.stringify(answerKey(packageIdentity), null, 2)}\n`, "utf8"),
      writeFile(resolve(reviewerDirectory, "README.md"), reviewerReadme(packageIdentity), "utf8"),
      writeFile(resolve(stage, outputSentinelName), outputSentinel, "utf8"),
    ]);

    if (replaceExisting) {
      await assertReplaceableOutput(output);
      await rm(output, { recursive: true, force: true });
    }
    await rename(stage, output);
  } catch (error) {
    await rm(stage, { recursive: true, force: true });
    throw error;
  }

  return {
    output,
    listener: resolve(output, "listener/index.html"),
    answerKey: resolve(output, "reviewer/answer-key.json"),
  };
}

async function main() {
  const outputFlag = process.argv.indexOf("--output");
  const requestedOutput = outputFlag >= 0 ? process.argv[outputFlag + 1] : process.env.NAMELESS_AUDIO_REVIEW_OUTPUT;
  if (outputFlag >= 0 && !requestedOutput) throw new Error("--output requires a directory path.");
  const result = await generateAudioBlindReview(requestedOutput || defaultOutput);
  const outputLabel = relative(repositoryRoot, result.output) || result.output;
  console.log(`Prepared byte-identical A-H blind listening package at ${outputLabel}.`);
  console.log(`Listener: ${result.listener}`);
  console.log(`Developer answer key (keep separate): ${result.answerKey}`);
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : "";
if (invokedPath === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
